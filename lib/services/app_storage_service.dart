import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../security/app_lifecycle_manager.dart';

/// Single public NexVault storage root. Backup and PDF files are stored
/// directly in this folder; no backup/pdf subdirectories are created.
class AppStorageService {
  AppStorageService._();
  static final AppStorageService instance = AppStorageService._();

  static const String appFolderName = 'NexVault';

  static const MethodChannel _channel =
      MethodChannel('pass_managers/file_saver');

  Directory? _root;

  Future<void> ensureAllFolders() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<Map>('ensureAppFolders');
        return;
      } catch (_) {}
    }
    await ensureRoot();
  }

  Future<Directory> ensureRoot() async {
    if (_root != null && await _root!.exists()) return _root!;

    Directory? candidate;

    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/$appFolderName');
      if (await _canWrite(dir)) {
        candidate = dir;
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
          method: 'pickAndSaveBackup',
        );
      }

      final initialDir = (await ensureRoot()).path;
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
          method: 'pickAndSavePdf',
        );
      }

      final initialDir = (await ensureRoot()).path;
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

  /// Temporary file → native picker receives only its path to avoid Binder
  /// transaction-size limits. The native side always targets the single
  /// NexVault root; it does not create backup/pdf subfolders.
  Future<String?> _saveViaAndroidPicker({
    required Uint8List data,
    required String fileName,
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
