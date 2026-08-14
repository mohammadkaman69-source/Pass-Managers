import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../repositories/tree_repository.dart';
import '../security/security_manager.dart';

class BackupService {
  BackupService({
    TreeRepository? repository,
    SecurityManager? securityManager,
  })  : _repository = repository ?? TreeRepository(),
        _securityManager = securityManager ?? SecurityManager();

  static const int _formatVersion = 1;
  static const MethodChannel _channel =
      MethodChannel('pass_managers/file_saver');

  final TreeRepository _repository;
  final SecurityManager _securityManager;

  Future<bool> createBackup({required String masterPassword}) async {
    final tree = await _repository.getCompleteTree();
    final payload = jsonEncode({
      'format': 'pass_managers_backup',
      'version': _formatVersion,
      'created_at': DateTime.now().toIso8601String(),
      'data': tree,
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
      final fileName = 'Pass-Managers-Backup-${_timestamp()}.pmb';

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
          dialogTitle: 'ذخیره نسخه پشتیبان Pass Managers',
          fileName: fileName,
          bytes: pickerBytes,
          type: FileType.custom,
          allowedExtensions: const ['pmb'],
        );
        return path != null && path.isNotEmpty;
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
    final file = await FilePicker.pickFile(
      dialogTitle: 'انتخاب نسخه پشتیبان Pass Managers',
      type: FileType.custom,
      allowedExtensions: const ['pmb'],
    );

    if (file == null) {
      throw const BackupCancelledException();
    }

    final source = await file.readAsBytes();
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

      if (outer['version'] != _formatVersion) {
        throw BackupFormatException(
          'نسخه پشتیبان پشتیبانی نمی‌شود: ${outer['version']}',
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
        final payload = await _securityManager.cryptoService.decrypt(
          encryptedText: ciphertext,
          key: key,
        );

        final decoded = jsonDecode(payload);
        if (decoded is! Map ||
            decoded['format'] != 'pass_managers_backup') {
          throw const BackupFormatException(
            'محتوای نسخه پشتیبان معتبر نیست.',
          );
        }

        final data = decoded['data'];
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
      } on SecretBoxAuthenticationError {
        throw const BackupFormatException(
          'نسخه پشتیبان با کلید امنیتی فعلی قابل بازگشایی نیست.',
        );
      } on FormatException {
        throw const BackupFormatException(
          'فایل نسخه پشتیبان خراب یا نامعتبر است.',
        );
      } finally {
        final keyBytes = List<int>.from(await key.extractBytes());
        keyBytes.fillRange(0, keyBytes.length, 0);
        salt.fillRange(0, salt.length, 0);
      }
    } finally {
      bytes.fillRange(0, bytes.length, 0);
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
