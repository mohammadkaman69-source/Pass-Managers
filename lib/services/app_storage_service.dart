import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Documents/NexVault/backup و Documents/NexVault/pdf
class AppStorageService {
  AppStorageService._();
  static final AppStorageService instance = AppStorageService._();

  static const String appFolderName = 'NexVault';
  static const String backupFolderName = 'backup';
  static const String pdfFolderName = 'pdf';

  static const MethodChannel _channel =
      MethodChannel('pass_managers/file_saver');

  Directory? _root;
  Directory? _backup;
  Directory? _pdf;

  Future<void> ensureAllFolders() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<Map>('ensureAppFolders');
        return;
      } catch (_) {}
    }
    await ensureBackupDir();
    await ensurePdfDir();
  }

  Future<Directory> ensureRoot() async {
    if (_root != null && await _root!.exists()) return _root!;

    Directory? candidate;

    if (Platform.isAndroid) {
      final candidates = <String>[
        '/storage/emulated/0/Documents/$appFolderName',
        '/storage/emulated/0/$appFolderName',
        '/storage/emulated/0/Download/$appFolderName',
      ];

      for (final path in candidates) {
        final dir = Directory(path);
        if (await _canWrite(dir)) {
          candidate = dir;
          break;
        }
      }

      if (candidate == null) {
        try {
          final ext = await getExternalStorageDirectory();
          if (ext != null) {
            final dir = Directory(p.join(ext.path, appFolderName));
            if (await _canWrite(dir)) {
              candidate = dir;
            }
          }
        } catch (_) {}
      }
    }

    if (candidate == null) {
      final docs = await getApplicationDocumentsDirectory();
      candidate = Directory(p.join(docs.path, appFolderName));
      await candidate.create(recursive: true);
    }

    if (!await candidate.exists()) {
      await candidate.create(recursive: true);
    }

    _root = candidate;
    return _root!;
  }

  Future<bool> _canWrite(Directory dir) async {
    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final probe = File(p.join(dir.path, '.write_test'));
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Directory> ensureBackupDir() async {
    if (_backup != null && await _backup!.exists()) return _backup!;
    final root = await ensureRoot();
    final dir = Directory(p.join(root.path, backupFolderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _backup = dir;
    return dir;
  }

  Future<Directory> ensurePdfDir() async {
    if (_pdf != null && await _pdf!.exists()) return _pdf!;
    final root = await ensureRoot();
    final dir = Directory(p.join(root.path, pdfFolderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _pdf = dir;
    return dir;
  }

  /// دیالوگ: مسیر پیش‌فرض NexVault یا انتخاب مسیر دیگر
  Future<String?> saveBackupWithDialog({
    required BuildContext context,
    required List<int> bytes,
    required String fileName,
  }) async {
    final choice = await _askSaveLocation(
      context: context,
      title: 'ذخیره نسخه پشتیبان',
      defaultLabel: 'پوشه پیش‌فرض NexVault/backup',
    );
    if (choice == null) return null;
    if (choice == 'default') {
      return saveBackupBytes(bytes, fileName);
    }
    return pickAndSaveBackup(bytes, fileName);
  }

  Future<String?> savePdfWithDialog({
    required BuildContext context,
    required List<int> bytes,
    required String fileName,
  }) async {
    final choice = await _askSaveLocation(
      context: context,
      title: 'ذخیره PDF',
      defaultLabel: 'پوشه پیش‌فرض NexVault/pdf',
    );
    if (choice == null) return null;
    if (choice == 'default') {
      return savePdfBytes(bytes, fileName);
    }
    return pickAndSavePdf(bytes, fileName);
  }

  Future<String?> _askSaveLocation({
    required BuildContext context,
    required String title,
    required String defaultLabel,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: const Text('مسیر ذخیره را انتخاب کنید.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'pick'),
            child: const Text('انتخاب مسیر دیگر'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, 'default'),
            child: Text(defaultLabel),
          ),
        ],
      ),
    );
  }

  Future<String?> saveBackupBytes(List<int> bytes, String fileName) async {
    final data = Uint8List.fromList(List<int>.from(bytes));
    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod<String>(
          'saveToAppFolder',
          <String, dynamic>{
            'fileName': fileName,
            'bytes': data,
            'subFolder': backupFolderName,
            'mimeType': 'application/octet-stream',
          },
        );
      }
      final file = await _writeLocal(await ensureBackupDir(), fileName, data);
      return file.path;
    } finally {
      data.fillRange(0, data.length, 0);
    }
  }

  Future<String?> savePdfBytes(List<int> bytes, String fileName) async {
    final data = Uint8List.fromList(List<int>.from(bytes));
    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod<String>(
          'saveToAppFolder',
          <String, dynamic>{
            'fileName': fileName,
            'bytes': data,
            'subFolder': pdfFolderName,
            'mimeType': 'application/pdf',
          },
        );
      }
      final file = await _writeLocal(await ensurePdfDir(), fileName, data);
      return file.path;
    } finally {
      data.fillRange(0, data.length, 0);
    }
  }

  Future<String?> pickAndSaveBackup(List<int> bytes, String fileName) async {
    final data = Uint8List.fromList(List<int>.from(bytes));
    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod<String>(
          'pickAndSaveBackup',
          <String, dynamic>{
            'fileName': fileName,
            'bytes': data,
          },
        );
      }
      final path = await FilePicker.saveFile(
        dialogTitle: 'ذخیره نسخه پشتیبان NexVault',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['pmb'],
      );
      if (path == null || path.isEmpty) return null;
      await File(path).writeAsBytes(data, flush: true);
      return path;
    } finally {
      data.fillRange(0, data.length, 0);
    }
  }

  Future<String?> pickAndSavePdf(List<int> bytes, String fileName) async {
    final data = Uint8List.fromList(List<int>.from(bytes));
    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod<String>(
          'pickAndSavePdf',
          <String, dynamic>{
            'fileName': fileName,
            'bytes': data,
          },
        );
      }
      final path = await FilePicker.saveFile(
        dialogTitle: 'ذخیره PDF NexVault',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (path == null || path.isEmpty) return null;
      await File(path).writeAsBytes(data, flush: true);
      return path;
    } finally {
      data.fillRange(0, data.length, 0);
    }
  }

  Future<File> _writeLocal(
    Directory dir,
    String fileName,
    Uint8List data,
  ) async {
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(data, flush: true);
    return file;
  }
}
