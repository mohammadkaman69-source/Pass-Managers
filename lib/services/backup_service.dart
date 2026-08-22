import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../security/security_manager.dart';
import 'app_storage_service.dart';

/// بک‌آپ امن NexVault v4
class BackupService {
  BackupService({SecurityManager? securityManager})
      : _securityManager = securityManager ?? SecurityManager();

  static const int _formatVersion = 4;
  static const int _schemaVersion = 2;
  static const String _outerFormat = 'nexvault_encrypted_backup';
  static const String _payloadFormat = 'nexvault_backup_payload';
  static const int _argonMemory = 32 * 1024;
  static const int _argonParallelism = 2;
  static const int _argonIterations = 3;
  static const int _keyLength = 32;

  final SecurityManager _securityManager;
  final AesGcm _aes = AesGcm.with256bits();
  final Random _random = Random.secure();
  String? _lastRecoveryKey;

  String? get lastRecoveryKey => _lastRecoveryKey;

  Future<bool> createBackup({required String masterPassword}) async {
    _requireUnlocked();
    final password = masterPassword.trim();
    if (password.isEmpty) {
      throw const BackupFormatException('رمز اصلی نمی‌تواند خالی باشد.');
    }

    final db = await AppDatabase.instance.database;
    final snapshot = await _readDatabaseSnapshot(db);
    await _decryptValuesInSnapshotStrict(snapshot);
    _validateSnapshot(snapshot, strict: false);

    final manifest = await _buildManifest(snapshot);
    final payload = jsonEncode({
      'format': _payloadFormat,
      'version': _formatVersion,
      'schema_version': _schemaVersion,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'manifest': manifest,
      'data': snapshot,
    });

    final masterSalt = _randomBytes(32);
    final dekBytes = _randomBytes(_keyLength);
    final recoveryBytes = _randomBytes(_keyLength);
    final recoveryKey = _formatRecoveryKey(recoveryBytes);

    try {
      final masterKeyBytes = await _deriveBackupKey(password, masterSalt);
      try {
        final dek = SecretKey(dekBytes);
        final masterKey = SecretKey(masterKeyBytes);
        final recoveryKeySecret = SecretKey(recoveryBytes);

        final encryptedPayload = await _encryptString(payload, dek);
        final wrappedForMaster = await _encryptBytes(dekBytes, masterKey);
        final wrappedForRecovery =
            await _encryptBytes(dekBytes, recoveryKeySecret);

        final backup = <String, dynamic>{
          'format': _outerFormat,
          'version': _formatVersion,
          'schema_version': _schemaVersion,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'crypto': {
            'cipher': 'AES-256-GCM',
            'kdf': 'Argon2id',
            'kdf_memory': _argonMemory,
            'kdf_parallelism': _argonParallelism,
            'kdf_iterations': _argonIterations,
          },
          'master_salt': base64Encode(masterSalt),
          'wrapped_keys': {
            'master': wrappedForMaster,
            'recovery': wrappedForRecovery,
          },
          'payload': encryptedPayload,
        };

        final bytes = Uint8List.fromList(utf8.encode(jsonEncode(backup)));
        final fileName = 'NexVault-Backup-${_timestamp()}.pmb';
        final savedPath = await AppStorageService.instance.saveBackupBytes(
          bytes,
          fileName,
        );
        _wipe(bytes);
        if (savedPath == null || savedPath.isEmpty) {
          throw const BackupFormatException('ذخیره Backup کامل نشد.');
        }

        _lastRecoveryKey = recoveryKey;
        try {
          await Clipboard.setData(ClipboardData(text: recoveryKey));
        } catch (_) {}
        return true;
      } finally {
        _wipe(masterKeyBytes);
      }
    } finally {
      _wipe(dekBytes);
      _wipe(recoveryBytes);
      _wipe(masterSalt);
    }
  }

  Future<BackupVerificationResult> verifyBackup({
    required String credential,
  }) async {
    final cred = credential.trim();
    if (cred.isEmpty) {
      throw const BackupFormatException(
        'رمز اصلی یا Recovery Key را وارد کنید.',
      );
    }
    final bytes = await _pickBackupBytes(
      dialogTitle: 'بررسی نسخه پشتیبان NexVault',
    );
    try {
      return await _verifyBytes(bytes, cred);
    } finally {
      _wipe(bytes);
    }
  }

  Future<BackupVerificationResult> restoreBackup({
    required String masterPassword,
  }) async {
    _requireUnlocked();
    final password = masterPassword.trim();
    if (password.isEmpty) {
      throw const BackupFormatException('رمز اصلی نمی‌تواند خالی باشد.');
    }

    final unlocked = await _securityManager.unlock(password);
    if (!unlocked) {
      throw const BackupFormatException(
        'رمز اصلی اشتباه است. همان رمزی که با آن وارد برنامه می‌شوید را وارد کنید.',
      );
    }

    final bytes = await _pickBackupBytes(
      dialogTitle: 'انتخاب نسخه پشتیبان NexVault',
    );
    try {
      final verified = await _verifyBytes(bytes, password);
      final snapshot = verified.snapshot;
      if (snapshot == null) {
        throw const BackupFormatException('Snapshot قابل Restore نیست.');
      }
      await _restoreDatabaseSnapshotAtomic(snapshot);
      return verified;
    } finally {
      _wipe(bytes);
    }
  }

  /// file_picker v12: PlatformFile has no .bytes — use readAsBytes / path / xFile
  Future<Uint8List> _pickBackupBytes({required String dialogTitle}) async {
    final sourceFile = await FilePicker.pickFile(
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: const ['pmb'],
    );
    if (sourceFile == null) {
      throw const BackupCancelledException();
    }

    try {
      try {
        final loaded = await sourceFile.readAsBytes();
        if (loaded.isNotEmpty) {
          return Uint8List.fromList(loaded);
        }
      } catch (_) {}

      final path = sourceFile.path;
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          final disk = await file.readAsBytes();
          if (disk.isNotEmpty) {
            return Uint8List.fromList(disk);
          }
        }
      }

      try {
        final xf = await sourceFile.xFile.readAsBytes();
        if (xf.isNotEmpty) {
          return Uint8List.fromList(xf);
        }
      } catch (_) {}

      throw const BackupFormatException(
        'فایل Backup خالی است یا قابل خواندن نیست. '
        'از File Manager فایل .pmb را انتخاب کنید.',
      );
    } catch (e) {
      if (e is BackupFormatException || e is BackupCancelledException) {
        rethrow;
      }
      throw BackupFormatException('خواندن فایل Backup ناموفق بود: $e');
    }
  }

  Future<BackupVerificationResult> _verifyBytes(
    Uint8List source,
    String credential,
  ) async {
    final decoded = _decodeJsonMap(source);
    final format = decoded['format']?.toString();
    final version = _asInt(decoded['version']);

    if (format == _outerFormat && version == _formatVersion) {
      final snapshot = await _decryptV4(decoded, credential);
      _validateSnapshot(snapshot, strict: false);
      final manifest = await _buildManifest(snapshot);
      return BackupVerificationResult(
        formatVersion: _formatVersion,
        schemaVersion: _schemaVersion,
        snapshot: snapshot,
        manifest: manifest,
      );
    }

    if (format == 'pass_managers_encrypted_backup' &&
        version != null &&
        version >= 1 &&
        version <= 3) {
      final snapshot =
          await _migrateLegacySnapshot(decoded, version, credential);
      _validateSnapshot(snapshot, strict: false);
      final manifest = await _buildManifest(snapshot);
      return BackupVerificationResult(
        formatVersion: version,
        schemaVersion: _schemaVersion,
        snapshot: snapshot,
        manifest: manifest,
      );
    }

    throw BackupFormatException(
      'نسخه پشتیبان پشتیبانی نمی‌شود '
      '(format: ${format ?? "?"} version: ${version ?? "؟"}).',
    );
  }

  Future<Map<String, dynamic>> _decryptV4(
    Map<String, dynamic> outer,
    String credential,
  ) async {
    final masterSalt = _decodeBase64Field(outer, 'master_salt');
    final wrappedKeys = outer['wrapped_keys'];
    if (wrappedKeys is! Map) {
      throw const BackupFormatException('کلیدهای Backup ناقص هستند.');
    }
    final wrappedMaster = wrappedKeys['master']?.toString();
    final wrappedRecovery = wrappedKeys['recovery']?.toString();
    final payload = outer['payload']?.toString();
    if (wrappedMaster == null ||
        wrappedMaster.isEmpty ||
        wrappedRecovery == null ||
        wrappedRecovery.isEmpty ||
        payload == null ||
        payload.isEmpty) {
      throw const BackupFormatException('ساختار رمزنگاری Backup ناقص است.');
    }

    Uint8List? dekBytes;
    try {
      try {
        final masterKeyBytes = await _deriveBackupKey(credential, masterSalt);
        try {
          dekBytes =
              await _decryptBytes(wrappedMaster, SecretKey(masterKeyBytes));
        } finally {
          _wipe(masterKeyBytes);
        }
      } catch (_) {
        final recovery = _parseRecoveryKey(credential);
        try {
          dekBytes =
              await _decryptBytes(wrappedRecovery, SecretKey(recovery));
        } finally {
          _wipe(recovery);
        }
      }

      if (dekBytes.length != _keyLength) {
        throw const BackupFormatException('کلید داده Backup معتبر نیست.');
      }
      final plain = await _decryptString(payload, SecretKey(dekBytes));
      final decoded =
          _decodeJsonMap(Uint8List.fromList(utf8.encode(plain)));
      if (decoded['format'] != _payloadFormat ||
          _asInt(decoded['version']) != _formatVersion) {
        throw const BackupFormatException(
          'Payload نسخه پشتیبان معتبر نیست.',
        );
      }
      final data = decoded['data'];
      if (data is! Map) {
        throw const BackupFormatException(
          'Snapshot نسخه پشتیبان ناقص است.',
        );
      }
      final snapshot = _normalizeSnapshot(data);

      final manifest = decoded['manifest'];
      if (manifest is Map) {
        try {
          await _verifyManifest(manifest, snapshot);
        } catch (_) {}
      }
      return snapshot;
    } catch (error) {
      if (error is BackupFormatException) rethrow;
      throw const BackupFormatException(
        'رمزگشایی یا اعتبارسنجی Backup ناموفق بود. '
        'رمز اصلی یا Recovery Key را بررسی کنید.',
      );
    } finally {
      if (dekBytes != null) _wipe(dekBytes);
      _wipe(masterSalt);
    }
  }

  Future<Map<String, dynamic>> _migrateLegacySnapshot(
    Map<String, dynamic> outer,
    int version,
    String masterPassword,
  ) async {
    final ciphertext = outer['ciphertext']?.toString();
    final saltValue = outer['salt']?.toString();
    if (ciphertext == null ||
        ciphertext.isEmpty ||
        saltValue == null ||
        saltValue.isEmpty) {
      throw const BackupFormatException('Backup قدیمی ناقص است.');
    }
    late Uint8List salt;
    try {
      salt = Uint8List.fromList(base64Decode(saltValue));
    } catch (_) {
      throw const BackupFormatException('Salt Backup قدیمی معتبر نیست.');
    }
    final key = await _securityManager.cryptoService.deriveKey(
      masterPassword: masterPassword,
      salt: salt,
    );
    try {
      late String payload;
      try {
        payload = await _securityManager.cryptoService.decrypt(
          encryptedText: ciphertext,
          key: key,
        );
      } catch (_) {
        throw const BackupFormatException(
          'رمز Backup اشتباه است یا Backup قدیمی قابل بازگشایی نیست.',
        );
      }
      final decoded =
          _decodeJsonMap(Uint8List.fromList(utf8.encode(payload)));
      if (decoded['format'] != 'pass_managers_backup') {
        throw const BackupFormatException(
          'Payload Backup قدیمی معتبر نیست.',
        );
      }
      final data = decoded['data'];
      if (data is! Map) {
        throw const BackupFormatException('Snapshot Backup قدیمی ناقص است.');
      }
      final snapshot = _normalizeSnapshot(data);
      final valuesPlain = decoded['values_plain'] == true || version >= 3;
      if (!valuesPlain) {
        await _tryDecryptLegacyValues(snapshot);
      }
      return snapshot;
    } finally {
      final keyBytes = await key.extractBytes();
      _wipe(keyBytes);
      _wipe(salt);
    }
  }

  Future<void> _tryDecryptLegacyValues(Map<String, dynamic> snapshot) async {
    final values = snapshot['table_values'];
    if (values is! List) return;
    for (var i = 0; i < values.length; i++) {
      final raw = values[i];
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      values[i] = map;
      final stored = (map['value'] ?? '').toString();
      if (stored.isEmpty) continue;
      try {
        map['value'] = await _decryptWithSession(stored);
      } catch (_) {
        if (_looksLikeEncryptedBlob(stored)) {
          map['value'] = '';
        }
      }
    }
  }

  bool _looksLikeEncryptedBlob(String value) {
    if (value.length < 40) return false;
    try {
      final decoded = utf8.decode(base64Decode(value));
      final map = jsonDecode(decoded);
      return map is Map &&
          map.containsKey('nonce') &&
          map.containsKey('cipherText') &&
          map.containsKey('mac');
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _readDatabaseSnapshot(Database db) async {
    List<Map<String, dynamic>> copyRows(List<Map<String, Object?>> rows) =>
        rows
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: true);
    return {
      'tree_items':
          copyRows(await db.query('tree_items', orderBy: 'id ASC')),
      'table_rows':
          copyRows(await db.query('table_rows', orderBy: 'id ASC')),
      'table_fields':
          copyRows(await db.query('table_fields', orderBy: 'id ASC')),
      'table_values':
          copyRows(await db.query('table_values', orderBy: 'id ASC')),
    };
  }

  Future<void> _decryptValuesInSnapshotStrict(
    Map<String, dynamic> snapshot,
  ) async {
    final values = snapshot['table_values'];
    if (values is! List) {
      throw const BackupFormatException('جدول Values در Backup معتبر نیست.');
    }
    for (var i = 0; i < values.length; i++) {
      final raw = values[i];
      if (raw is! Map) {
        throw BackupFormatException('Value شماره ${i + 1} معتبر نیست.');
      }
      final map = Map<String, dynamic>.from(raw);
      values[i] = map;
      final encrypted = (map['value'] ?? '').toString();
      if (encrypted.isEmpty) {
        map['value'] = '';
        continue;
      }
      try {
        map['value'] = await _decryptWithSession(encrypted);
      } catch (_) {
        throw BackupFormatException(
          'رمزگشایی Value شماره ${i + 1} ناموفق بود؛ Backup ساخته نشد. '
          'جلسه امنیتی را دوباره باز کنید.',
        );
      }
    }
  }

  Future<String> _decryptWithSession(String encrypted) async {
    _requireUnlocked();
    final keyBytes = _securityManager.encryptionKey;
    try {
      return await _securityManager.cryptoService.decrypt(
        encryptedText: encrypted,
        key: SecretKey(keyBytes),
      );
    } finally {
      _wipe(keyBytes);
    }
  }

  Future<String> _encryptWithSession(String plain) async {
    _requireUnlocked();
    final keyBytes = _securityManager.encryptionKey;
    try {
      return await _securityManager.cryptoService.encrypt(
        plainText: plain,
        key: SecretKey(keyBytes),
      );
    } finally {
      _wipe(keyBytes);
    }
  }

  Map<String, dynamic> _normalizeSnapshot(Map data) {
    List<Map<String, dynamic>> listFor(String key) {
      final value = data[key];
      if (value is! List) {
        return <Map<String, dynamic>>[];
      }
      return value.map<Map<String, dynamic>>((item) {
        if (item is! Map) {
          throw BackupFormatException('رکورد نامعتبر در جدول $key.');
        }
        final map = Map<String, dynamic>.from(item);
        for (final k in [
          'id',
          'parent_id',
          'table_item_id',
          'row_id',
          'field_id',
          'position',
          'created_at',
          'updated_at',
        ]) {
          if (map.containsKey(k) && map[k] != null) {
            final n = _asInt(map[k]);
            if (n != null) map[k] = n;
          }
        }
        if (map.containsKey('value')) {
          map['value'] = (map['value'] ?? '').toString();
        }
        return map;
      }).toList(growable: true);
    }

    return {
      'tree_items': listFor('tree_items'),
      'table_rows': listFor('table_rows'),
      'table_fields': listFor('table_fields'),
      'table_values': listFor('table_values'),
    };
  }

  void _validateSnapshot(
    Map<String, dynamic> snapshot, {
    required bool strict,
  }) {
    final treeItems = snapshot['tree_items'];
    final rows = snapshot['table_rows'];
    final fields = snapshot['table_fields'];
    final values = snapshot['table_values'];
    if (treeItems is! List ||
        rows is! List ||
        fields is! List ||
        values is! List) {
      throw const BackupFormatException(
        'ساختار داخلی نسخه پشتیبان کامل نیست.',
      );
    }

    final treeIds = <int>{};
    final tableIds = <int>{};
    for (final raw in List.from(treeItems)) {
      if (raw is! Map) {
        if (strict) {
          throw const BackupFormatException('Tree record نامعتبر است.');
        }
        treeItems.remove(raw);
        continue;
      }
      final id = _asInt(raw['id']);
      final name = raw['name'];
      final type = raw['type']?.toString();
      if (id == null ||
          name == null ||
          name.toString().isEmpty ||
          type == null ||
          (type != 'folder' && type != 'table')) {
        if (strict) {
          throw const BackupFormatException(
            'داده‌های Tree در Backup معتبر نیستند.',
          );
        }
        treeItems.remove(raw);
        continue;
      }
      if (!treeIds.add(id)) {
        if (strict) {
          throw const BackupFormatException(
            'شناسه تکراری در Tree پیدا شد.',
          );
        }
        treeItems.remove(raw);
        continue;
      }
      if (type == 'table') tableIds.add(id);
    }

    for (final raw in List.from(treeItems)) {
      if (raw is! Map) continue;
      final parent = raw['parent_id'];
      if (parent != null) {
        final parentId = _asInt(parent);
        if (parentId == null ||
            !treeIds.contains(parentId) ||
            parentId == _asInt(raw['id'])) {
          if (strict) {
            throw const BackupFormatException(
              'رابطه Parent در Tree معتبر نیست.',
            );
          }
          raw['parent_id'] = null;
        }
      }
    }

    final rowIds = <int>{};
    for (final raw in List.from(rows)) {
      if (raw is! Map) {
        rows.remove(raw);
        continue;
      }
      final id = _asInt(raw['id']);
      final tableId = _asInt(raw['table_item_id']);
      if (id == null ||
          tableId == null ||
          !tableIds.contains(tableId) ||
          !rowIds.add(id)) {
        if (strict) {
          throw const BackupFormatException(
            'رابطه Table و Record در Backup معتبر نیست.',
          );
        }
        rows.remove(raw);
      }
    }

    final fieldIds = <int>{};
    for (final raw in List.from(fields)) {
      if (raw is! Map) {
        fields.remove(raw);
        continue;
      }
      final id = _asInt(raw['id']);
      final rowId = _asInt(raw['row_id']);
      final name = raw['name'];
      if (id == null ||
          rowId == null ||
          name == null ||
          name.toString().isEmpty ||
          !rowIds.contains(rowId) ||
          !fieldIds.add(id)) {
        if (strict) {
          throw const BackupFormatException(
            'رابطه Field و Record در Backup معتبر نیست.',
          );
        }
        fields.remove(raw);
      }
    }

    final valueIds = <int>{};
    final coveredFields = <int>{};
    for (final raw in List.from(values)) {
      if (raw is! Map) {
        values.remove(raw);
        continue;
      }
      final id = _asInt(raw['id']);
      final fieldId = _asInt(raw['field_id']);
      if (id == null ||
          fieldId == null ||
          !fieldIds.contains(fieldId) ||
          !valueIds.add(id)) {
        if (strict) {
          throw const BackupFormatException(
            'رابطه Value و Field در Backup معتبر نیست.',
          );
        }
        values.remove(raw);
        continue;
      }
      coveredFields.add(fieldId);
    }

    var nextValueId = valueIds.isEmpty
        ? 1
        : (valueIds.reduce((a, b) => a > b ? a : b) + 1);
    for (final fid in fieldIds) {
      if (!coveredFields.contains(fid)) {
        values.add({
          'id': nextValueId++,
          'field_id': fid,
          'value': '',
        });
      }
    }
  }

  Future<Map<String, dynamic>> _buildManifest(
    Map<String, dynamic> snapshot,
  ) async {
    final bytes = utf8.encode(jsonEncode(snapshot));
    final hash = await Sha256().hash(bytes);
    return {
      'tree_items': (snapshot['tree_items'] as List).length,
      'table_rows': (snapshot['table_rows'] as List).length,
      'table_fields': (snapshot['table_fields'] as List).length,
      'table_values': (snapshot['table_values'] as List).length,
      'payload_sha256': base64UrlEncode(hash.bytes),
      'payload_bytes': bytes.length,
    };
  }

  Future<void> _verifyManifest(
    Map expected,
    Map<String, dynamic> snapshot,
  ) async {
    final actual = await _buildManifest(snapshot);
    for (final key in [
      'tree_items',
      'table_rows',
      'table_fields',
      'table_values',
      'payload_sha256',
      'payload_bytes',
    ]) {
      if (expected[key]?.toString() != actual[key]?.toString()) {
        throw const BackupFormatException(
          'Integrity Manifest با Snapshot مطابقت ندارد.',
        );
      }
    }
  }

  Future<void> _restoreDatabaseSnapshotAtomic(
    Map<String, dynamic> snapshot,
  ) async {
    _requireUnlocked();
    _validateSnapshot(snapshot, strict: false);

    final treeItems = List<Map<String, dynamic>>.from(
      (snapshot['tree_items'] as List).whereType<Map>().map(
            (e) => Map<String, dynamic>.from(e),
          ),
    );
    treeItems.sort((a, b) {
      final ap = _asInt(a['parent_id']);
      final bp = _asInt(b['parent_id']);
      if (ap == null && bp != null) return -1;
      if (ap != null && bp == null) return 1;
      return (_asInt(a['id']) ?? 0).compareTo(_asInt(b['id']) ?? 0);
    });

    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('table_values');
      await txn.delete('table_fields');
      await txn.delete('table_rows');
      await txn.delete('tree_items');

      for (final map in treeItems) {
        await txn.insert(
          'tree_items',
          _pick(map, const [
            'id',
            'parent_id',
            'name',
            'type',
            'created_at',
            'updated_at',
          ]),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final raw in snapshot['table_rows'] as List) {
        final map = Map<String, Object?>.from(raw as Map);
        await txn.insert(
          'table_rows',
          _pick(map, const [
            'id',
            'table_item_id',
            'created_at',
            'updated_at',
          ]),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final raw in snapshot['table_fields'] as List) {
        final map = Map<String, Object?>.from(raw as Map);
        await txn.insert(
          'table_fields',
          _pick(map, const [
            'id',
            'row_id',
            'name',
            'position',
            'created_at',
            'updated_at',
          ]),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final raw in snapshot['table_values'] as List) {
        final map = Map<String, Object?>.from(raw as Map);
        final plain = (map['value'] ?? '').toString();
        map['value'] = await _encryptWithSession(plain);
        await txn.insert(
          'table_values',
          _pick(map, const ['id', 'field_id', 'value']),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<String> _encryptString(String value, SecretKey key) async {
    final box = await _aes.encrypt(utf8.encode(value), secretKey: key);
    return _encodeSecretBox(box);
  }

  Future<String> _decryptString(String value, SecretKey key) async {
    final box = _decodeSecretBox(value);
    final clear = await _aes.decrypt(box, secretKey: key);
    return utf8.decode(clear);
  }

  Future<String> _encryptBytes(Uint8List value, SecretKey key) async {
    final box = await _aes.encrypt(value, secretKey: key);
    return _encodeSecretBox(box);
  }

  Future<Uint8List> _decryptBytes(String value, SecretKey key) async {
    final box = _decodeSecretBox(value);
    final clear = await _aes.decrypt(box, secretKey: key);
    return Uint8List.fromList(clear);
  }

  String _encodeSecretBox(SecretBox box) => base64UrlEncode(
        utf8.encode(
          jsonEncode({
            'nonce': base64Encode(box.nonce),
            'cipherText': base64Encode(box.cipherText),
            'mac': base64Encode(box.mac.bytes),
          }),
        ),
      );

  SecretBox _decodeSecretBox(String encoded) {
    try {
      final map = jsonDecode(utf8.decode(base64Url.decode(encoded))) as Map;
      return SecretBox(
        base64Decode(map['cipherText'] as String),
        nonce: base64Decode(map['nonce'] as String),
        mac: Mac(base64Decode(map['mac'] as String)),
      );
    } catch (_) {
      throw const BackupFormatException('بخش رمزنگاری Backup خراب است.');
    }
  }

  Future<Uint8List> _deriveBackupKey(String password, Uint8List salt) async {
    if (password.isEmpty) {
      throw const BackupFormatException('Credential خالی است.');
    }
    final algorithm = Argon2id(
      memory: _argonMemory,
      parallelism: _argonParallelism,
      iterations: _argonIterations,
      hashLength: _keyLength,
    );
    final key = await algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  Map<String, dynamic> _decodeJsonMap(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) throw const FormatException();
      return Map<String, dynamic>.from(decoded);
    } catch (error) {
      if (error is BackupFormatException) rethrow;
      throw const BackupFormatException(
        'فایل یا Payload Backup خراب یا نامعتبر است.',
      );
    }
  }

  Uint8List _decodeBase64Field(Map<String, dynamic> map, String key) {
    final value = map[key]?.toString();
    if (value == null || value.isEmpty) {
      throw BackupFormatException('فیلد $key در Backup وجود ندارد.');
    }
    try {
      final bytes = Uint8List.fromList(base64Decode(value));
      if (bytes.length != 32) throw const FormatException();
      return bytes;
    } catch (_) {
      throw BackupFormatException('فیلد $key در Backup معتبر نیست.');
    }
  }

  Uint8List _parseRecoveryKey(String value) {
    try {
      final compact = value.replaceAll('-', '').trim();
      final padded = compact.padRight(
        compact.length + ((4 - compact.length % 4) % 4),
        '=',
      );
      final bytes = Uint8List.fromList(base64Url.decode(padded));
      if (bytes.length != 32) throw const FormatException();
      return bytes;
    } catch (_) {
      throw const BackupFormatException(
        'Recovery Key معتبر نیست. رمز اصلی یا Recovery Key را وارد کنید.',
      );
    }
  }

  String _formatRecoveryKey(Uint8List bytes) {
    final encoded = base64UrlEncode(bytes).replaceAll('=', '');
    final groups = <String>[];
    for (var i = 0; i < encoded.length; i += 8) {
      groups.add(encoded.substring(i, min(i + 8, encoded.length)));
    }
    return groups.join('-');
  }

  Uint8List _randomBytes(int length) =>
      Uint8List.fromList(List<int>.generate(length, (_) => _random.nextInt(256)));

  Map<String, Object?> _pick(Map<String, Object?> source, List<String> keys) {
    final out = <String, Object?>{};
    for (final key in keys) {
      if (source.containsKey(key)) out[key] = source[key];
    }
    return out;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  void _requireUnlocked() {
    if (!_securityManager.isUnlocked) {
      throw const BackupFormatException(
        'جلسه امنیتی قفل است؛ دوباره وارد شوید.',
      );
    }
  }

  String _timestamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  void _wipe(List<int> bytes) => bytes.fillRange(0, bytes.length, 0);
}

class BackupVerificationResult {
  const BackupVerificationResult({
    required this.formatVersion,
    required this.schemaVersion,
    required this.snapshot,
    required this.manifest,
  });

  final int formatVersion;
  final int schemaVersion;
  final Map<String, dynamic>? snapshot;
  final Map<String, dynamic> manifest;

  int get treeItemCount => (manifest['tree_items'] as num?)?.toInt() ?? 0;
  int get rowCount => (manifest['table_rows'] as num?)?.toInt() ?? 0;
  int get fieldCount => (manifest['table_fields'] as num?)?.toInt() ?? 0;
  int get valueCount => (manifest['table_values'] as num?)?.toInt() ?? 0;
}

class BackupCancelledException implements Exception {
  const BackupCancelledException();
}

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}
