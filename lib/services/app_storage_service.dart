import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../security/app_lifecycle_manager.dart';

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

  Future<String?> saveBackupBytes(List<int> bytes, String fileName) async {
    return pickAndSaveBackup(bytes, fileName);
  }

  Future<String?> savePdfBytes(List<int> bytes, String fileName) async {
    return pickAndSavePdf(bytes, fileName);
  }

  Future<String?> pickAndSaveBackup(List<int> bytes, String fileName) async {
    final data = Uint8List.fromList(List<int>.from(bytes));
    AppLifecycleManager.beginExternalUi();
    try {
      if (Platform.isAndroid) {
        return await _saveViaAndroidPicker(
          data: data,
          fileName: fileName,
          subFolder: backupFolderName,
          method: 'pickAndSaveBackup',
        );
      }

      final initialDir = (await ensureBackupDir()).path;
      final uri = await FilePicker.saveFile(
        dialogTitle: 'ذخیره نسخه پشتیبان NexVault',
        fileName: fileName,
        bytes: data,
        type: FileType.custom,
        allowedExtensions: const ['pmb'],
        initialDirectory: initialDir,
      );
      if (uri == null) return null;
      return _uriToPath(uri);
    } finally {
      AppLifecycleManager.endExternalUi();
      data.fillRange(0, data.length, 0);
    }
  }

  Future<String?> pickAndSavePdf(List<int> bytes, String fileName) async {
    final data = Uint8List.fromList(List<int>.from(bytes));
    AppLifecycleManager.beginExternalUi();
    try {
      if (Platform.isAndroid) {
        return await _saveViaAndroidPicker(
          data: data,
          fileName: fileName,
          subFolder: pdfFolderName,
          method: 'pickAndSavePdf',
        );
      }

      final initialDir = (await ensurePdfDir()).path;
      final uri = await FilePicker.saveFile(
        dialogTitle: 'ذخیره PDF NexVault',
        fileName: fileName,
        bytes: data,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        initialDirectory: initialDir,
      );
      if (uri == null) return null;
      return _uriToPath(uri);
    } finally {
      AppLifecycleManager.endExternalUi();
      data.fillRange(0, data.length, 0);
    }
  }

  /// فایل موقت → فقط مسیر به نیتیو (جلوگیری از محدودیت اندازه Binder)
  Future<String?> _saveViaAndroidPicker({
    required Uint8List data,
    required String fileName,
    required String subFolder,
    required String method,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final temp = File(
      p.join(
        tempDir.path,
        'nv_save_${DateTime.now().millisecondsSinceEpoch}_$fileName',
      ),
    );
    await temp.writeAsBytes(data, flush: true);
    try {
      return await _channel.invokeMethod<String>(
        method,
        <String, dynamic>{
          'fileName': fileName,
          'path': temp.path,
          'subFolder': subFolder,
        },
      );
    } finally {
      try {
        if (await temp.exists()) {
          await temp.delete();
        }
      } catch (_) {}
    }
  }

  String _uriToPath(Uri uri) {
    try {
      return uri.toFilePath();
    } catch (_) {
      return uri.path;
    }
  }
}
