import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../security/security_manager.dart';
import 'app_lifecycle_manager.dart';
import 'app_storage_service.dart';

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
  BackupCreationResult? _lastBackupResult;

  String? get lastRecoveryKey => _lastRecoveryKey;
  BackupCreationResult? get lastBackupResult => _lastBackupResult;

  Future<dynamic> createBackup({required String masterPassword}) async {
    _requireUnlocked();
    final password = masterPassword.trim();
    if (password.isEmpty) {
      throw const BackupFormatException('رمز اصلی نمی‌تواند خالی باشد.');
    }

    final db = await AppDatabase.instance.database;
    final snapshot = await _readSnapshot(db);
    await _decryptValuesStrict(snapshot);
    _validateSnapshot(snapshot);

    final manifest = await _manifest(snapshot);
    final payload = jsonEncode({
      'format': _payloadFormat,
      'version': _formatVersion,
      'schema_version': _schemaVersion,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'manifest': manifest,
      'data': snapshot,
    });

    final salt = _randomBytes(32);
    final dek = _randomBytes(_keyLength);
    final recovery = _randomBytes(_keyLength);
    final recoveryText = _formatRecoveryKey(recovery);

    try {
      final masterKey = await _deriveBackupKey(password, salt);
      try {
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
          'master_salt': base64Encode(salt),
          'wrapped_keys': {
            'master': await _encryptBytes(dek, SecretKey(masterKey)),
            'recovery': await _encryptBytes(dek, SecretKey(recovery)),
          },
          'payload': await _encryptString(payload, SecretKey(dek)),
        };

        final encoded = utf8.encode(jsonEncode(backup));
        final fileName = 'NexVault-Backup-${_timestamp()}.pmb';
        final saved = await AppStorageService.instance.saveBackupBytes(
          encoded,
          fileName,
        );
        if (saved == null || saved.isEmpty) {
          throw const BackupFormatException(
            'Backup ذخیره نشد؛ فایل مقصد ایجاد نشد یا عملیات لغو شد.',
          );
        }

        final result = BackupCreationResult(
          fileName: fileName,
          savedPath: saved,
          formatVersion: _formatVersion,
          schemaVersion: _schemaVersion,
          manifest: manifest,
          fileSizeBytes: encoded.length,
          recoveryKey: recoveryText,
        );
        _lastBackupResult = result;
        _lastRecoveryKey = recoveryText;
        try {
          await Clipboard.setData(ClipboardData(text: recoveryText));
        } catch (_) {}
        return true;
      } finally {
        _wipe(masterKey);
      }
    } finally {
      _wipe(salt);
      _wipe(dek);
      _wipe(recovery);
    }
  }

  Future<BackupVerificationResult> verifyBackup({required String credential}) async {
    final value = credential.trim();
    if (value.isEmpty) {
      throw const BackupFormatException('رمز اصلی یا Recovery Key را وارد کنید.');
    }
    final bytes = await _pickBackupBytes('بررسی نسخه پشتیبان NexVault');
    try {
      return await _verifyBytes(bytes, value);
    } finally {
      _wipe(bytes);
    }
  }

  Future<BackupVerificationResult> restoreBackup({
    required String masterPassword,
  }) async {
    _requireUnlocked();
    final credential = masterPassword.trim();
    if (credential.isEmpty) {
      throw const BackupFormatException('رمز اصلی یا Recovery Key را وارد کنید.');
    }

    final bytes = await _pickBackupBytes('انتخاب نسخه پشتیبان NexVault');
    try {
      final verified = await _verifyBytes(bytes, credential);
      final incoming = verified.snapshot;
      if (incoming == null) {
        throw const BackupFormatException('Snapshot قابل Restore نیست.');
      }

      final db = await AppDatabase.instance.database;
      final oldSnapshot = await _readSnapshot(db);
      await _decryptValuesStrict(oldSnapshot);
      _validateSnapshot(oldSnapshot);

      final prepared = await _prepareEncryptedSnapshot(incoming);
      try {
        await _replaceDatabase(prepared);
        await _verifyLiveAgainst(incoming);
      } catch (error) {
        try {
          final oldPrepared = await _prepareEncryptedSnapshot(oldSnapshot);
          await _replaceDatabase(oldPrepared);
          await _verifyLiveAgainst(oldSnapshot);
        } catch (rollbackError) {
          throw BackupFormatException(
            'Restore شکست خورد و بازگردانی Vault قبلی نیز ناموفق بود: $rollbackError',
          );
        }
        if (error is BackupFormatException) rethrow;
        throw BackupFormatException('Restore انجام نشد: $error');
      }

      return verified;
    } finally {
      _wipe(bytes);
    }
  }

  Future<List<int>> _pickBackupBytes(String title) async {
    AppLifecycleManager.beginExternalUi();
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: title,
        type: FileType.custom,
        allowedExtensions: const ['pmb'],
      );
      if (file == null) throw const BackupCancelledException();

      try {
        try {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) return List<int>.from(bytes);
        } catch (_) {}

        final path = file.path;
        if (path != null && path.isNotEmpty) {
          final f = File(path);
          if (await f.exists()) {
            final bytes = await f.readAsBytes();
            if (bytes.isNotEmpty) return List<int>.from(bytes);
          }
        }

        try {
          final bytes = await file.xFile.readAsBytes();
          if (bytes.isNotEmpty) return List<int>.from(bytes);
        } catch (_) {}

        throw const BackupFormatException('فایل Backup خالی است یا قابل خواندن نیست.');
      } catch (e) {
        if (e is BackupFormatException || e is BackupCancelledException) rethrow;
        throw BackupFormatException('خواندن فایل Backup ناموفق بود: $e');
      }
    } finally {
      AppLifecycleManager.endExternalUi();
    }
  }

  Future<BackupVerificationResult> _verifyBytes(
    List<int> bytes,
    String credential,
  ) async {
    final outer = _jsonMap(bytes);
    final format = outer['format']?.toString();
    final version = _int(outer['version']);

    if (format == _outerFormat && version == _formatVersion) {
      final snapshot = await _decryptV4(outer, credential);
      return BackupVerificationResult(
        formatVersion: _formatVersion,
        schemaVersion: _schemaVersion,
        snapshot: snapshot,
        manifest: await _manifest(snapshot),
      );
    }

    if (format == 'pass_managers_encrypted_backup' &&
        version != null &&
        version >= 1 &&
        version <= 3) {
      final snapshot = await _legacy(outer, version, credential);
      _validateSnapshot(snapshot);
      return BackupVerificationResult(
        formatVersion: version,
        schemaVersion: _schemaVersion,
        snapshot: snapshot,
        manifest: await _manifest(snapshot),
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
    if (_int(outer['schema_version']) != _schemaVersion) {
      throw BackupFormatException(
        'Schema نسخه پشتیبان پشتیبانی نمی‌شود: ${outer['schema_version'] ?? "؟"}.',
      );
    }

    final salt = _base64Field(outer, 'master_salt');
    final wrapped = outer['wrapped_keys'];
    final payload = outer['payload']?.toString();
    if (wrapped is! Map || payload == null || payload.isEmpty) {
      throw const BackupFormatException('ساختار رمزنگاری Backup ناقص است.');
    }

    final masterWrapped = wrapped['master']?.toString();
    final recoveryWrapped = wrapped['recovery']?.toString();
    if (masterWrapped == null ||
        recoveryWrapped == null ||
        masterWrapped.isEmpty ||
        recoveryWrapped.isEmpty) {
      throw const BackupFormatException('کلیدهای Backup ناقص هستند.');
    }

    List<int>? dek;
    try {
      try {
        final key = await _deriveBackupKey(credential, salt);
        try {
          dek = await _decryptBytes(masterWrapped, SecretKey(key));
        } finally {
          _wipe(key);
        }
      } catch (_) {
        final key = _parseRecoveryKey(credential);
        try {
          dek = await _decryptBytes(recoveryWrapped, SecretKey(key));
        } finally {
          _wipe(key);
        }
      }

      if (dek.length != _keyLength) {
        throw const BackupFormatException('کلید داده Backup معتبر نیست.');
      }

      final clear = await _decryptString(payload, SecretKey(dek));
      final inner = _jsonMap(utf8.encode(clear));
      if (inner['format'] != _payloadFormat ||
          _int(inner['version']) != _formatVersion ||
          _int(inner['schema_version']) != _schemaVersion) {
        throw const BackupFormatException('Payload نسخه پشتیبان معتبر نیست.');
      }

      final data = inner['data'];
      if (data is! Map) {
        throw const BackupFormatException('Snapshot نسخه پشتیبان ناقص است.');
      }

      final snapshot = _normalize(data);
      _validateSnapshot(snapshot);
      final manifest = inner['manifest'];
      if (manifest is! Map) {
        throw const BackupFormatException('Manifest نسخه پشتیبان وجود ندارد.');
      }
      await _verifyManifest(manifest, snapshot);
      return snapshot;
    } on BackupFormatException {
      rethrow;
    } catch (_) {
      throw const BackupFormatException(
        'رمزگشایی Backup ناموفق بود. رمز اصلی یا Recovery Key را بررسی کنید.',
      );
    } finally {
      if (dek != null) _wipe(dek);
      _wipe(salt);
    }
  }

  Future<Map<String, dynamic>> _legacy(
    Map<String, dynamic> outer,
    int version,
    String password,
  ) async {
    final cipher = outer['ciphertext']?.toString();
    final saltText = outer['salt']?.toString();
    if (cipher == null ||
        cipher.isEmpty ||
        saltText == null ||
        saltText.isEmpty) {
      throw const BackupFormatException('Backup قدیمی ناقص است.');
    }

    final salt = base64Decode(saltText);
    final key = await _securityManager.cryptoService.deriveKey(
      masterPassword: password,
      salt: salt,
    );
    try {
      final payload = await _securityManager.cryptoService.decrypt(
        encryptedText: cipher,
        key: key,
      );
      final decoded = _jsonMap(utf8.encode(payload));
      if (decoded['format'] != 'pass_managers_backup' ||
          decoded['data'] is! Map) {
        throw const BackupFormatException('Payload Backup قدیمی معتبر نیست.');
      }

      final snapshot = _normalize(decoded['data'] as Map);
      if (decoded['values_plain'] != true && version < 3) {
        await _decryptLegacyValues(snapshot);
      }
      _validateSnapshot(snapshot);
      return snapshot;
    } catch (e) {
      if (e is BackupFormatException) rethrow;
      throw const BackupFormatException(
        'Backup قدیمی قابل بازگشایی نیست یا رمز آن اشتباه است.',
      );
    } finally {
      final kb = await key.extractBytes();
      _wipe(kb);
      _wipe(salt);
    }
  }

  Future<void> _decryptLegacyValues(Map<String, dynamic> snapshot) async {
    final values = snapshot['table_values'];
    if (values is! List) {
      throw const BackupFormatException(
        'جدول Values در Backup قدیمی معتبر نیست.',
      );
    }
    for (var i = 0; i < values.length; i++) {
      final map = Map<String, dynamic>.from(values[i] as Map);
      final text = (map['value'] ?? '').toString();
      if (text.isEmpty) {
        map['value'] = '';
      } else {
        try {
          map['value'] = await _decryptWithSession(text);
        } catch (_) {
          throw BackupFormatException(
            'Value قدیمی شماره ${i + 1} قابل رمزگشایی نیست.',
          );
        }
      }
      values[i] = map;
    }
  }

  Future<Map<String, dynamic>> _readSnapshot(Database db) async => {
        'tree_items': (await db.query('tree_items', orderBy: 'id ASC'))
            .map(Map<String, dynamic>.from)
            .toList(),
        'table_rows': (await db.query('table_rows', orderBy: 'id ASC'))
            .map(Map<String, dynamic>.from)
            .toList(),
        'table_fields': (await db.query('table_fields', orderBy: 'id ASC'))
            .map(Map<String, dynamic>.from)
            .toList(),
        'table_values': (await db.query('table_values', orderBy: 'id ASC'))
            .map(Map<String, dynamic>.from)
            .toList(),
      };

  Future<void> _decryptValuesStrict(Map<String, dynamic> snapshot) async {
    final values = snapshot['table_values'];
    if (values is! List) {
      throw const BackupFormatException('جدول Values معتبر نیست.');
    }
    for (var i = 0; i < values.length; i++) {
      final map = Map<String, dynamic>.from(values[i] as Map);
      final encrypted = (map['value'] ?? '').toString();
      if (encrypted.isEmpty) {
        map['value'] = '';
      } else {
        try {
          map['value'] = await _decryptWithSession(encrypted);
        } catch (_) {
          throw BackupFormatException(
            'رمزگشایی Value شماره ${i + 1} ناموفق بود؛ Backup متوقف شد.',
          );
        }
      }
      values[i] = map;
    }
  }

  Future<String> _decryptWithSession(String text) async {
    _requireUnlocked();
    final key = _securityManager.encryptionKey;
    try {
      return await _securityManager.cryptoService.decrypt(
        encryptedText: text,
        key: SecretKey(key),
      );
    } finally {
      _wipe(key);
    }
  }

  Future<String> _encryptWithSession(String text) async {
    _requireUnlocked();
    final key = _securityManager.encryptionKey;
    try {
      return await _securityManager.cryptoService.encrypt(
        plainText: text,
        key: SecretKey(key),
      );
    } finally {
      _wipe(key);
    }
  }

  Map<String, dynamic> _normalize(Map data) {
    List<Map<String, dynamic>> list(String key) {
      final raw = data[key];
      if (raw is! List) {
        throw BackupFormatException('جدول $key در Backup وجود ندارد.');
      }
      return raw.map<Map<String, dynamic>>((item) {
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
          if (map[k] != null) {
            final n = _int(map[k]);
            if (n == null) {
              throw BackupFormatException(
                'مقدار $k در جدول $key معتبر نیست.',
              );
            }
            map[k] = n;
          }
        }
        if (map.containsKey('value')) {
          map['value'] = (map['value'] ?? '').toString();
        }
        return map;
      }).toList();
    }

    return {
      'tree_items': list('tree_items'),
      'table_rows': list('table_rows'),
      'table_fields': list('table_fields'),
      'table_values': list('table_values'),
    };
  }

  void _validateSnapshot(Map<String, dynamic> s) {
    final tree = s['tree_items'];
    final rows = s['table_rows'];
    final fields = s['table_fields'];
    final values = s['table_values'];
    if (tree is! List ||
        rows is! List ||
        fields is! List ||
        values is! List) {
      throw const BackupFormatException(
        'ساختار داخلی نسخه پشتیبان کامل نیست.',
      );
    }

    final treeIds = <int>{};
    final tableIds = <int>{};
    for (final raw in tree) {
      if (raw is! Map) {
        throw const BackupFormatException('Tree record نامعتبر است.');
      }
      final id = _int(raw['id']);
      final type = raw['type']?.toString();
      if (id == null ||
          raw['name']?.toString().isEmpty != false ||
          (type != 'folder' && type != 'table')) {
        throw const BackupFormatException(
          'داده‌های Tree در Backup معتبر نیستند.',
        );
      }
      if (!treeIds.add(id)) {
        throw const BackupFormatException('شناسه تکراری در Tree پیدا شد.');
      }
      if (type == 'table') tableIds.add(id);
    }

    for (final raw in tree) {
      final parent = raw['parent_id'] == null
          ? null
          : _int(raw['parent_id']);
      if (raw['parent_id'] != null &&
          (parent == null ||
              !treeIds.contains(parent) ||
              parent == _int(raw['id']))) {
        throw const BackupFormatException(
          'رابطه Parent در Tree معتبر نیست.',
        );
      }
    }

    final rowIds = <int>{};
    for (final raw in rows) {
      final id = _int(raw['id']);
      final tableId = _int(raw['table_item_id']);
      if (id == null ||
          tableId == null ||
          !tableIds.contains(tableId) ||
          !rowIds.add(id)) {
        throw const BackupFormatException(
          'رابطه Table و Record در Backup معتبر نیست.',
        );
      }
    }

    final fieldIds = <int>{};
    for (final raw in fields) {
      final id = _int(raw['id']);
      final rowId = _int(raw['row_id']);
      if (id == null ||
          rowId == null ||
          raw['name']?.toString().isEmpty != false ||
          !rowIds.contains(rowId) ||
          !fieldIds.add(id)) {
        throw const BackupFormatException(
          'رابطه Field و Record در Backup معتبر نیست.',
        );
      }
    }

    final valueIds = <int>{};
    for (final raw in values) {
      final id = _int(raw['id']);
      final fieldId = _int(raw['field_id']);
      if (id == null ||
          fieldId == null ||
          !fieldIds.contains(fieldId) ||
          !valueIds.add(id) ||
          !raw.containsKey('value')) {
        throw const BackupFormatException(
          'رابطه Value و Field در Backup معتبر نیست.',
        );
      }
    }
  }

  Future<Map<String, dynamic>> _manifest(Map<String, dynamic> snapshot) async {
    final canonical = _canonicalize(snapshot);
    final bytes = utf8.encode(jsonEncode(canonical));
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

  dynamic _canonicalize(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((e) => e.toString()).toList()..sort();
      final result = <String, dynamic>{};
      for (final key in keys) {
        result[key] = _canonicalize(value[key]);
      }
      return result;
    }
    if (value is List) {
      return value.map(_canonicalize).toList();
    }
    return value;
  }

  Future<void> _verifyManifest(
    Map expected,
    Map<String, dynamic> actualSnapshot,
  ) async {
    final actual = await _manifest(actualSnapshot);
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

  Future<Map<String, dynamic>> _prepareEncryptedSnapshot(
    Map<String, dynamic> plain,
  ) async {
    final out = _normalize(plain);
    _validateSnapshot(out);
    final values = out['table_values'] as List;
    for (var i = 0; i < values.length; i++) {
      final map = Map<String, dynamic>.from(values[i] as Map);
      map['value'] = await _encryptWithSession(
        (map['value'] ?? '').toString(),
      );
      values[i] = map;
    }
    return out;
  }

  Future<void> _replaceDatabase(Map<String, dynamic> encrypted) async {
    _requireUnlocked();
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('table_values');
      await txn.delete('table_fields');
      await txn.delete('table_rows');
      await txn.delete('tree_items');

      for (final raw in encrypted['tree_items'] as List) {
        await txn.insert(
          'tree_items',
          _pick(raw as Map, [
            'id',
            'parent_id',
            'name',
            'type',
            'created_at',
            'updated_at',
          ]),
        );
      }
      for (final raw in encrypted['table_rows'] as List) {
        await txn.insert(
          'table_rows',
          _pick(raw as Map, [
            'id',
            'table_item_id',
            'created_at',
            'updated_at',
          ]),
        );
      }
      for (final raw in encrypted['table_fields'] as List) {
        await txn.insert(
          'table_fields',
          _pick(raw as Map, [
            'id',
            'row_id',
            'name',
            'position',
            'created_at',
            'updated_at',
          ]),
        );
      }
      for (final raw in encrypted['table_values'] as List) {
        await txn.insert(
          'table_values',
          _pick(raw as Map, ['id', 'field_id', 'value']),
        );
      }
    });
  }

  Future<void> _verifyLiveAgainst(Map<String, dynamic> expectedPlain) async {
    final db = await AppDatabase.instance.database;
    final live = await _readSnapshot(db);
    await _decryptValuesStrict(live);
    _validateSnapshot(live);

    final expected = await _manifest(expectedPlain);
    final actual = await _manifest(live);
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
          'Restore انجام شد اما بررسی نهایی با Backup مطابقت ندارد.',
        );
      }
    }
  }

  Future<String> _encryptString(String text, SecretKey key) async =>
      _box(await _aes.encrypt(utf8.encode(text), secretKey: key));

  Future<String> _decryptString(String text, SecretKey key) async =>
      utf8.decode(await _aes.decrypt(_decodeBox(text), secretKey: key));

  Future<String> _encryptBytes(List<int> data, SecretKey key) async =>
      _box(await _aes.encrypt(data, secretKey: key));

  Future<List<int>> _decryptBytes(String text, SecretKey key) async =>
      List<int>.from(await _aes.decrypt(_decodeBox(text), secretKey: key));

  String _box(SecretBox b) => base64UrlEncode(
        utf8.encode(
          jsonEncode({
            'nonce': base64Encode(b.nonce),
            'cipherText': base64Encode(b.cipherText),
            'mac': base64Encode(b.mac.bytes),
          }),
        ),
      );

  SecretBox _decodeBox(String text) {
    try {
      final m = jsonDecode(utf8.decode(base64Url.decode(text))) as Map;
      return SecretBox(
        base64Decode(m['cipherText'] as String),
        nonce: base64Decode(m['nonce'] as String),
        mac: Mac(base64Decode(m['mac'] as String)),
      );
    } catch (_) {
      throw const BackupFormatException('بخش رمزنگاری Backup خراب است.');
    }
  }

  Future<List<int>> _deriveBackupKey(String password, List<int> salt) async {
    final key = await Argon2id(
      memory: _argonMemory,
      parallelism: _argonParallelism,
      iterations: _argonIterations,
      hashLength: _keyLength,
    ).deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return List<int>.from(await key.extractBytes());
  }

  Map<String, dynamic> _jsonMap(List<int> bytes) {
    try {
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map) throw const FormatException();
      return Map<String, dynamic>.from(value);
    } catch (_) {
      throw const BackupFormatException('فایل یا Payload Backup خراب یا نامعتبر است.');
    }
  }

  List<int> _base64Field(Map<String, dynamic> map, String key) {
    try {
      final bytes = base64Decode(map[key]?.toString() ?? '');
      if (bytes.length != 32) throw const FormatException();
      return bytes;
    } catch (_) {
      throw BackupFormatException('فیلد $key در Backup معتبر نیست.');
    }
  }

  String _formatRecoveryKey(List<int> bytes) {
    final s = base64UrlEncode(bytes).replaceAll('=', '');
    final groups = <String>[];
    for (var i = 0; i < s.length; i += 8) {
      groups.add(s.substring(i, min(i + 8, s.length)));
    }
    return groups.join('-');
  }

  List<int> _parseRecoveryKey(String value) {
    try {
      final compact = value.replaceAll('-', '').trim();
      if (compact.length != 43) throw const FormatException();
      final padded = compact.padRight(
        compact.length + ((4 - compact.length % 4) % 4),
        '=',
      );
      final bytes = base64Url.decode(padded);
      if (bytes.length != 32) throw const FormatException();
      return List<int>.from(bytes);
    } catch (_) {
      throw const BackupFormatException('Recovery Key معتبر نیست.');
    }
  }

  Map<String, Object?> _pick(Map map, List<String> keys) => {
        for (final k in keys)
          if (map.containsKey(k)) k: map[k],
      };

  int? _int(dynamic v) =>
      v is int ? v : v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');

  List<int> _randomBytes(int n) =>
      List<int>.generate(n, (_) => _random.nextInt(256));

  String _timestamp() {
    final n = DateTime.now().toUtc();
    String t(int x) => x.toString().padLeft(2, '0');
    return '${n.year}${t(n.month)}${t(n.day)}-${t(n.hour)}${t(n.minute)}${t(n.second)}';
  }

  void _wipe(List<int> b) => b.fillRange(0, b.length, 0);

  void _requireUnlocked() {
    if (!_securityManager.isUnlocked) {
      throw const BackupFormatException(
        'جلسه امنیتی برنامه باز نیست. ابتدا وارد Vault شوید.',
      );
    }
  }
}

class BackupCreationResult {
  const BackupCreationResult({
    required this.fileName,
    required this.savedPath,
    required this.formatVersion,
    required this.schemaVersion,
    required this.manifest,
    required this.fileSizeBytes,
    required this.recoveryKey,
  });

  final String fileName;
  final String savedPath;
  final int formatVersion;
  final int schemaVersion;
  final Map<String, dynamic> manifest;
  final int fileSizeBytes;
  final String recoveryKey;

  int get treeItemCount => (manifest['tree_items'] as num?)?.toInt() ?? 0;
  int get rowCount => (manifest['table_rows'] as num?)?.toInt() ?? 0;
  int get fieldCount => (manifest['table_fields'] as num?)?.toInt() ?? 0;
  int get valueCount => (manifest['table_values'] as num?)?.toInt() ?? 0;
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

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BackupCancelledException implements Exception {
  const BackupCancelledException();
}
