import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../repositories/tree_repository.dart';
import '../security/security_manager.dart';

class BackupService {
  BackupService({
    TreeRepository? repository,
    SecurityManager? securityManager,
  })  : _repository = repository ?? TreeRepository(),
        _securityManager = securityManager ?? SecurityManager();

  static const int _formatVersion = 2;
  static const MethodChannel _channel =
      MethodChannel('pass_managers/file_saver');

  final TreeRepository _repository;
  final SecurityManager _securityManager;

  Future<bool> createBackup({required String masterPassword}) async {
    final db = await AppDatabase.instance.database;
    final snapshot = await _readDatabaseSnapshot(db);
    _validateSnapshot(snapshot);

    final payload = jsonEncode({
      'format': 'pass_managers_backup',
      'version': _formatVersion,
      'created_at': DateTime.now().toIso8601String(),
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

      if (Platform.isAndroid) {
        final nativeBytes = Uint8List.fromList(bytes);
        final path = await _channel.invokeMethod<String>(
          'saveBackup',
          <String, dynamic>{
            'fileName': fileName,
            'bytes': nativeBytes,
          },
        );
        nativeBytes.fillRange(0, nativeBytes.length, 0);
        return path != null && path.isNotEmpty;
      }

      final pickerBytes = Uint8List.fromList(bytes);
      try {
        final path = await FilePicker.saveFile(
          dialogTitle: 'ذخیره نسخه پشتیبان NexVault',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: const ['pmb'],
          bytes: pickerBytes,
        );
        return path != null && path.toString().isNotEmpty;
      } finally {
        pickerBytes.fillRange(0, pickerBytes.length, 0);
      }
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
      final outer = jsonDecode(utf8.decode(bytes));
      if (outer is! Map ||
          outer['format'] != 'pass_managers_encrypted_backup') {
        throw const BackupFormatException('فرمت نسخه پشتیبان معتبر نیست.');
      }

      final version = outer['version'];
      if (version is! int || (version != 1 && version != 2)) {
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

        if (version == 2) {
          if (data is! Map) {
            throw const BackupFormatException(
              'ساختار نسخه پشتیبان خراب است.',
            );
          }

          final snapshot = _normalizeSnapshot(data);
          _validateSnapshot(snapshot);
          await _restoreDatabaseSnapshot(snapshot);
        } else {
          if (data is! List) {
            throw const BackupFormatException(
              'ساختار داده نسخه پشتیبان خراب است.',
            );
          }

          final roots = <Map<String, dynamic>>[];
          for (final item in data) {
            if (item is Map) {
              roots.add(Map<String, dynamic>.from(item));
            }
          }

          await _repository.replaceFromBackup(roots);
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
        throw BackupFormatException(
          'بخش $key در نسخه پشتیبان وجود ندارد.',
        );
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
        if (map.containsKey('value') && map['value'] != null) {
          map['value'] = map['value'].toString();
        } else if (map.containsKey('value') && map['value'] == null) {
          map['value'] = '';
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

  void _validateSnapshot(Map<String, dynamic> snapshot) {
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
    for (final raw in treeItems) {
      if (raw is! Map ||
          _asInt(raw['id']) == null ||
          raw['name'] == null ||
          raw['type'] == null) {
        throw const BackupFormatException(
          'داده‌های Tree در Backup معتبر نیستند.',
        );
      }
      final id = _asInt(raw['id'])!;
      if (!ids.add(id)) {
        throw const BackupFormatException(
          'شناسه تکراری در Tree پیدا شد.',
        );
      }
      final type = raw['type'].toString();
      if (type != 'folder' && type != 'table') {
        throw const BackupFormatException(
          'نوع آیتم Tree معتبر نیست.',
        );
      }
    }

    final tableIds = treeItems
        .whereType<Map>()
        .where((item) => item['type'] == 'table')
        .map((item) => _asInt(item['id']))
        .whereType<int>()
        .toSet();

    for (final raw in rows) {
      final rowId = raw is Map ? _asInt(raw['id']) : null;
      final tableItemId = raw is Map ? _asInt(raw['table_item_id']) : null;
      if (rowId == null ||
          tableItemId == null ||
          !tableIds.contains(tableItemId)) {
        throw const BackupFormatException(
          'رابطه Table و Record در Backup معتبر نیست.',
        );
      }
    }

    final rowIds = rows
        .whereType<Map>()
        .map((row) => _asInt(row['id']))
        .whereType<int>()
        .toSet();

    final fieldIds = <int>{};
    for (final raw in fields) {
      final fieldId = raw is Map ? _asInt(raw['id']) : null;
      final rowId = raw is Map ? _asInt(raw['row_id']) : null;
      if (fieldId == null ||
          rowId == null ||
          !rowIds.contains(rowId)) {
        throw const BackupFormatException(
          'رابطه Field و Record در Backup معتبر نیست.',
        );
      }
      if (!fieldIds.add(fieldId)) {
        throw const BackupFormatException(
          'شناسه تکراری برای Field پیدا شد.',
        );
      }
    }

    for (final raw in values) {
      if (raw is! Map) {
        throw const BackupFormatException(
          'رابطه Value و Field در Backup معتبر نیست.',
        );
      }
      final id = _asInt(raw['id']);
      final fieldId = _asInt(raw['field_id']);
      if (id == null ||
          fieldId == null ||
          !fieldIds.contains(fieldId)) {
        throw const BackupFormatException(
          'رابطه Value و Field در Backup معتبر نیست.',
        );
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
        await txn.insert(
          'tree_items',
          Map<String, Object?>.from(raw as Map),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }

      for (final raw in snapshot['table_rows'] as List) {
        await txn.insert(
          'table_rows',
          Map<String, Object?>.from(raw as Map),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }

      for (final raw in snapshot['table_fields'] as List) {
        await txn.insert(
          'table_fields',
          Map<String, Object?>.from(raw as Map),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }

      for (final raw in snapshot['table_values'] as List) {
        final map = Map<String, Object?>.from(raw as Map);
        map['value'] = (map['value'] ?? '').toString();
        await txn.insert(
          'table_values',
          map,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });

    final restored = await _readDatabaseSnapshot(db);
    int countOf(Map snap, String key) =>
        (snap[key] is List) ? (snap[key] as List).length : -1;

    if (countOf(restored, 'tree_items') != countOf(snapshot, 'tree_items') ||
        countOf(restored, 'table_rows') != countOf(snapshot, 'table_rows') ||
        countOf(restored, 'table_fields') != countOf(snapshot, 'table_fields') ||
        countOf(restored, 'table_values') != countOf(snapshot, 'table_values')) {
      throw const BackupFormatException(
        'بازیابی کامل انجام نشد؛ تعداد رکوردها با نسخه پشتیبان مطابقت ندارد.',
      );
    }
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
