import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../security/app_lifecycle_manager.dart';

/// ذخیره با دیالوگ سیستم (نام و مسیر قابل تغییر).
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

    if (Platform.isAndroid) {
      for (final candidate in <String>[
        '/storage/emulated/0/$appFolderName',
        '/storage/emulated/0/Download/$appFolderName',
      ]) {
        final root = Directory(candidate);
        try {
          if (!await root.exists()) {
            await root.create(recursive: true);
          }
          if (await root.exists()) {
            _root = root;
            return root;
          }
        } catch (_) {
          continue;
        }
      }
      throw StateError('پوشهٔ عمومی NexVault در دسترس نیست.');
    }

    final docs = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(docs.path, appFolderName));
    await root.create(recursive: true);
    _root = root;
    return root;
  }

  Future<String> _defaultInitialDir() async {
    try {
      return (await ensureRoot()).path;
    } catch (_) {
      if (Platform.isAndroid) return '/storage/emulated/0/Download';
      final docs = await getApplicationDocumentsDirectory();
      return docs.path;
    }
  }

  Future<String?> saveBackupBytes(List<int> bytes, String fileName) async {
    return pickAndSaveBackup(bytes, fileName);
  }

  Future<String?> savePdfBytes(List<int> bytes, String fileName) async {
    return pickAndSavePdf(bytes, fileName);
  }

  /// اندروید: دیالوگ File Explorer سیستم (تغییر نام و مسیر).
  /// دسکتاپ: FilePicker.saveFile
  Future<String?> pickAndSaveBackup(List<int> bytes, String fileName) async {
    final data = Uint8List.fromList(List<int>.from(bytes));
    AppLifecycleManager.beginExternalUi();
    try {
      if (Platform.isAndroid) {
        return await _saveViaAndroidSystemDialog(
          data: data,
          fileName: fileName,
          method: 'pickAndSaveBackup',
        );
      }

      final initialDir = await _defaultInitialDir();
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
        return await _saveViaAndroidSystemDialog(
          data: data,
          fileName: fileName,
          method: 'pickAndSavePdf',
        );
      }

      final initialDir = await _defaultInitialDir();
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

  /// فایل موقت → نیتیو → دیالوگ CREATE_DOCUMENT سیستم
  Future<String?> _saveViaAndroidSystemDialog({
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
      final saved = await _channel.invokeMethod<String>(
        method,
        <String, dynamic>{
          'fileName': fileName,
          'path': temp.path,
        },
      );
      return saved;
    } on PlatformException catch (e) {
      if (e.code == 'SAVE_FAILED') rethrow;
      return null;
    } finally {
      try {
        if (await temp.exists()) await temp.delete();
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
