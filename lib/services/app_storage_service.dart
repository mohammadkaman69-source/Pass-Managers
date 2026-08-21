import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// مسیرهای ذخیره‌سازی عمومی برنامه روی دستگاه:
/// NexVault/backup و NexVault/pdf
class AppStorageService {
  AppStorageService._();
  static final AppStorageService instance = AppStorageService._();

  static const String appFolderName = 'NexVault';
  static const String backupFolderName = 'backup';
  static const String pdfFolderName = 'pdf';

  Directory? _root;
  Directory? _backup;
  Directory? _pdf;

  /// ریشهٔ قابل‌نوشتن را پیدا/ایجاد می‌کند.
  Future<Directory> ensureRoot() async {
    if (_root != null && await _root!.exists()) return _root!;

    Directory? candidate;

    if (Platform.isAndroid) {
      final candidates = <String>[
        '/storage/emulated/0/$appFolderName',
        '/storage/emulated/0/Documents/$appFolderName',
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

    if (candidate == null && Platform.isWindows) {
      try {
        final docs = await getApplicationDocumentsDirectory();
        candidate = Directory(p.join(docs.path, appFolderName));
        await candidate.create(recursive: true);
      } catch (_) {}
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

  /// در استارت برنامه پوشه‌ها را آماده می‌کند.
  Future<void> ensureAllFolders() async {
    await ensureBackupDir();
    await ensurePdfDir();
  }

  Future<File> saveBackupBytes(List<int> bytes, String fileName) async {
    final dir = await ensureBackupDir();
    final file = File(p.join(dir.path, fileName));
    final data = Uint8List.fromList(List<int>.from(bytes));
    try {
      await file.writeAsBytes(data, flush: true);
      return file;
    } finally {
      data.fillRange(0, data.length, 0);
    }
  }

  Future<File> savePdfBytes(List<int> bytes, String fileName) async {
    final dir = await ensurePdfDir();
    final file = File(p.join(dir.path, fileName));
    final data = Uint8List.fromList(List<int>.from(bytes));
    await file.writeAsBytes(data, flush: true);
    return file;
  }
}
