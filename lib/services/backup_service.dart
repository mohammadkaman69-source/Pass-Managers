import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../repositories/tree_repository.dart';
import '../security/security_manager.dart';
import 'app_storage_service.dart';

class BackupService {
  BackupService({
    TreeRepository? repository,
    SecurityManager? securityManager,
  })  : _repository = repository ?? TreeRepository(),
        _securityManager = securityManager ?? SecurityManager();

  static const int _formatVersion = 3;

  final TreeRepository _repository;
  final SecurityManager _securityManager;

  Future<bool> createBackup({
    required String masterPassword,
    BuildContext? context,
  }) async {
    if (!_securityManager.isUnlocked) {
      throw const BackupFormatException(
        'برای ساخت نسخه پشتیبان باید وارد حساب شده باشید.',
      );
    }

    final db = await AppDatabase.instance.database;
    final snapshot = await _readDatabaseSnapshot(db);
    await _decryptValuesInSnapshot(snapshot);
    _validateSnapshot(snapshot, strict: false);

    final payload = jsonEncode({
      'format': 'pass_managers_backup',
      'version': _formatVersion,
      'created_at': DateTime.now().toIso8601String(),
      'values_plain': true,
      'data': snapshot,
    });

    final salt = _securityManager.cryptoService.generateSalt();
    final key = await _securityManager.cryptoService.deriveKey(
      masterPassword: masterPassword,
      salt: salt,
    );

    try {
      final encrypted = await _securityManager.cryptoService.encrypt(
        plainText: payload,
        key: key,
      );

      final backupText = jsonEncode({
        'format': 'pass_managers_encrypted_backup',
        'version': _formatVersion,
        'salt': base64Encode(salt),
        'ciphertext': encrypted,
      });

      final bytes = Uint8List.fromList(utf8.encode(backupText));
      final fileName = 'NexVault-Backup-${_timestamp()}.pmb';

      final String? savedPath;
      if (context != null && context.mounted) {
        savedPath = await AppStorageService.instance.saveBackupWithDialog(
          context: context,
          bytes: bytes,
          fileName: fileName,
        );
      } else {
        savedPath = await AppStorageService.instance.saveBackupBytes(
          bytes,
          fileName,
        );
      }
      return savedPath != null && savedPath.isNotEmpty;
    } finally {
      final keyBytes = List<int>.from(await key.extractBytes());
      keyBytes.fillRange(0, keyBytes.length, 0);
      salt.fillRange(0, salt.length, 0);
    }
  }

  Future<void> restoreBackup({required String masterPassword}) async {
    final sourceFile = await FilePicker.pickFile(
      dialogTitle: 'انتخاب نسخه پشتیبان NexVault',
      type: FileType.custom,
      allowedExtensions: const ['pmb'],
    );

    if (sourceFile == null) {
      throw const BackupCancelledException();
    }

    final source = await sourceFile.readAsBytes();
    if (source.isEmpty) {
      throw const BackupFormatException('فایل پشتیبان قابل خواندن نیست.');
    }

    final bytes = Uint8List.fromList(source);
    try {
      Map outer;
      try {
        final decoded = jsonDecode(utf8.decode(bytes));
        if (decoded is! Map) {
          throw const BackupFormatException('فرمت نسخه پشتیبان معتبر نیست.');
        }
        outer = decoded;
      } catch (_) {
        throw const BackupFormatException(
          'فایل نسخه پشتیبان خراب یا نامعتبر است.',
        );
      }

      if (outer['format'] != 'pass_managers_encrypted_backup') {
        throw const BackupFormatException('فرمت نسخه پشتیبان معتبر نیست.');
      }

      final version = _asInt(outer['version']) ?? 0;
      if (version < 1 || version > 3) {
        throw BackupFormatException(
          'نسخه پشتیبان پشتیبانی نمی‌شود: $version',
        );
      }

      final ciphertext = outer['ciphertext']?.toString();
      if (ciphertext == null || ciphertext.isEmpty) {
        throw const BackupFormatException('داده رمزنگاری‌شده پیدا نشد.');
      }

      final saltValue = outer['salt']?.toString();
      if (saltValue == null || saltValue.isEmpty) {
        throw const BackupFormatException('نسخه پشتیبان فاقد salt است.');
      }

      final salt = Uint8List.fromList(base64Decode(saltValue));
      final key = await _securityManager.cryptoService.deriveKey(
        masterPassword: masterPassword,
        salt: salt,
      );

      try {
        String payload;
        try {
          payload = await _securityManager.cryptoService.decrypt(
            encryptedText: ciphertext,
            key: key,
          );
        } catch (_) {
          throw const BackupFormatException(
            'رمز نسخه پشتیبان اشتباه است یا فایل قابل بازگشایی نیست.',
          );
        }

        final decoded = jsonDecode(payload);
        if (decoded is! Map ||
            decoded['format'] != 'pass_managers_backup') {
          throw const BackupFormatException(
            'محتوای نسخه پشتیبان معتبر نیست.',
          );
        }

        final data = decoded['data'];
        final valuesPlain = decoded['values_plain'] == true || version >= 3;

        if (data is Map) {
          final snapshot = _normalizeSnapshot(data);
          _validateSnapshot(snapshot, strict: false);
          if (valuesPlain) {
            await _encryptValuesInSnapshot(snapshot);
          } else {
            await _tryReencryptLegacyValues(snapshot);
          }
          await _restoreDatabaseSnapshot(snapshot);
        } else if (data is List) {
          final roots = <Map<String, dynamic>>[];
          for (final item in data) {
            if (item is Map) {
              roots.add(Map<String, dynamic>.from(item));
            }
          }
          await _repository.replaceFromBackup(roots);
        } else {
          throw const BackupFormatException(
            'ساختار داده نسخه پشتیبان خراب است.',
          );
        }
      } finally {
        final keyBytes = List<int>.from(await key.extractBytes());
        keyBytes.fillRange(0, keyBytes.length, 0);
        salt.fillRange(0, salt.length, 0);
      }
    } on BackupFormatException {
      rethrow;
    } on FormatException {
      throw const BackupFormatException(
        'فایل نسخه پشتیبان خراب یا نامعتبر است.',
      );
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  Future<Map<String, dynamic>> _readDatabaseSnapshot(Database db) async {
    return {
      'tree_items': await db.query('tree_items', orderBy: 'id ASC'),
      'table_rows': await db.query('table_rows', orderBy: 'id ASC'),
      'table_fields': await db.query('table_fields', orderBy: 'id ASC'),
      'table_values': await db.query('table_values', orderBy: 'id ASC'),
    };
  }

  Future<void> _decryptValuesInSnapshot(Map<String, dynamic> snapshot) async {
    final values = snapshot['table_values'];
    if (values is! List) return;

    for (final raw in values) {
      if (raw is! Map) continue;
      final encrypted = (raw['value'] ?? '').toString();
      if (encrypted.isEmpty) {
        raw['value'] = '';
        continue;
      }
      try {
        raw['value'] = await _decryptWithSession(encrypted);
      } catch (_) {
        raw['value'] = encrypted;
      }
    }
  }

  Future<void> _encryptValuesInSnapshot(Map<String, dynamic> snapshot) async {
    final values = snapshot['table_values'];
    if (values is! List) return;

    for (final raw in values) {
      if (raw is! Map) continue;
      final plain = (raw['value'] ?? '').toString();
      raw['value'] = await _encryptWithSession(plain);
    }
  }

  Future<void> _tryReencryptLegacyValues(
    Map<String, dynamic> snapshot,
  ) async {
    final values = snapshot['table_values'];
    if (values is! List) return;

    for (final raw in values) {
      if (raw is! Map) continue;
      final stored = (raw['value'] ?? '').toString();
      if (stored.isEmpty) continue;

      try {
        final plain = await _decryptWithSession(stored);
        raw['value'] = await _encryptWithSession(plain);
      } catch (_) {
        raw['value'] = stored;
      }
    }
  }

  Future<String> _encryptWithSession(String plain) async {
    if (!_securityManager.isUnlocked) {
      throw const BackupFormatException(
        'جلسه امنیتی قفل است؛ دوباره وارد شوید.',
      );
    }
    final keyBytes = _securityManager.encryptionKey;
    try {
      return await _securityManager.cryptoService.encrypt(
        plainText: plain,
        key: SecretKey(keyBytes),
      );
    } finally {
      keyBytes.fillRange(0, keyBytes.length, 0);
    }
  }

  Future<String> _decryptWithSession(String encrypted) async {
    if (!_securityManager.isUnlocked) {
      throw const BackupFormatException(
        'جلسه امنیتی قفل است؛ دوباره وارد شوید.',
      );
    }
    final keyBytes = _securityManager.encryptionKey;
    try {
      return await _securityManager.cryptoService.decrypt(
        encryptedText: encrypted,
        key: SecretKey(keyBytes),
      );
    } finally {
      keyBytes.fillRange(0, keyBytes.length, 0);
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> _normalizeSnapshot(Map data) {
    List<Map<String, dynamic>> listFor(String key) {
      final value = data[key];
      if (value is! List) {
        return <Map<String, dynamic>>[];
      }

      return value.whereType<Map>().map((item) {
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
      }).toList();
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

    final ids = <int>{};
    for (final raw in List.from(treeItems)) {
      if (raw is! Map ||
          _asInt(raw['id']) == null ||
          raw['name'] == null ||
          raw['type'] == null) {
        if (strict) {
          throw const BackupFormatException(
            'داده‌های Tree در Backup معتبر نیستند.',
          );
        }
        treeItems.remove(raw);
        continue;
      }
      final id = _asInt(raw['id'])!;
      if (!ids.add(id)) {
        if (strict) {
          throw const BackupFormatException(
            'شناسه تکراری در Tree پیدا شد.',
          );
        }
        treeItems.remove(raw);
        continue;
      }
      final type = raw['type'].toString();
      if (type != 'folder' && type != 'table') {
        if (strict) {
          throw const BackupFormatException(
            'نوع آیتم Tree معتبر نیست.',
          );
        }
        treeItems.remove(raw);
      }
    }

    final tableIds = treeItems
        .whereType<Map>()
        .where((item) => item['type'] == 'table')
        .map((item) => _asInt(item['id']))
        .whereType<int>()
        .toSet();

    for (final raw in List.from(rows)) {
      final rowId = raw is Map ? _asInt(raw['id']) : null;
      final tableItemId = raw is Map ? _asInt(raw['table_item_id']) : null;
      if (rowId == null ||
          tableItemId == null ||
          !tableIds.contains(tableItemId)) {
        if (strict) {
          throw const BackupFormatException(
            'رابطه Table و Record در Backup معتبر نیست.',
          );
        }
        rows.remove(raw);
      }
    }

    final rowIds = rows
        .whereType<Map>()
        .map((row) => _asInt(row['id']))
        .whereType<int>()
        .toSet();

    final fieldIds = <int>{};
    for (final raw in List.from(fields)) {
      final fieldId = raw is Map ? _asInt(raw['id']) : null;
      final rowId = raw is Map ? _asInt(raw['row_id']) : null;
      if (fieldId == null ||
          rowId == null ||
          !rowIds.contains(rowId) ||
          !fieldIds.add(fieldId)) {
        if (strict) {
          throw const BackupFormatException(
            'رابطه Field و Record در Backup معتبر نیست.',
          );
        }
        fields.remove(raw);
      }
    }

    for (final raw in List.from(values)) {
      if (raw is! Map) {
        values.remove(raw);
        continue;
      }
      final fieldId = _asInt(raw['field_id']);
      if (fieldId == null || !fieldIds.contains(fieldId)) {
        if (strict) {
          throw const BackupFormatException(
            'رابطه Value و Field در Backup معتبر نیست.',
          );
        }
        values.remove(raw);
      }
    }
  }

  Future<void> _restoreDatabaseSnapshot(
    Map<String, dynamic> snapshot,
  ) async {
    final db = await AppDatabase.instance.database;

    await db.transaction((txn) async {
      await txn.delete('table_values');
      await txn.delete('table_fields');
      await txn.delete('table_rows');
      await txn.delete('tree_items');

      for (final raw in snapshot['tree_items'] as List) {
        final map = Map<String, Object?>.from(raw as Map);
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
          conflictAlgorithm: ConflictAlgorithm.abort,
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
          conflictAlgorithm: ConflictAlgorithm.abort,
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
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }

      for (final raw in snapshot['table_values'] as List) {
        final map = Map<String, Object?>.from(raw as Map);
        map['value'] = (map['value'] ?? '').toString();
        await txn.insert(
          'table_values',
          _pick(map, const ['id', 'field_id', 'value']),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });
  }

  Map<String, Object?> _pick(Map<String, Object?> source, List<String> keys) {
    final out = <String, Object?>{};
    for (final key in keys) {
      if (source.containsKey(key)) {
        out[key] = source[key];
      }
    }
    return out;
  }

  String _timestamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');

    return '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
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
