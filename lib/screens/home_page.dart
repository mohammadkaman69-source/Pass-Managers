import 'package:flutter/material.dart';

import '../models/tree_item.dart';
import '../repositories/tree_repository.dart';
import '../security/security_guard.dart';
import '../services/pdf_export_service.dart';
import '../services/backup_service.dart';
import '../security/biometric_service.dart';
import '../security/security_manager.dart';
import 'table_page.dart';
import 'tree_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TreeRepository _repository = TreeRepository();

  final List<TreeItem> items = [];

  final Map<TreeItem, int> _itemIds = {};

  final PdfExportService _pdfExportService = PdfExportService();
  final BackupService _backupService = BackupService();
  final BiometricService _biometricService = BiometricService();

  bool _isLoading = true;
  bool _isExporting = false;
  bool _isBackupBusy = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final rows = await _repository.getItems();

      final loadedItems = <TreeItem>[];
      final loadedIds = <TreeItem, int>{};

      for (final row in rows) {
        final id = row['id'] as int;
        final name = row['name'] as String;
        final type = row['type'] as String;

        final item = type == 'table'
            ? TreeItem.table(
                name,
                id: id,
              )
            : TreeItem.folder(
                name,
                id: id,
              );

        loadedItems.add(item);
        loadedIds[item] = id;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        items
          ..clear()
          ..addAll(loadedItems);

        _itemIds
          ..clear()
          ..addAll(loadedIds);

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _showError(
        'Failed to load data: $error',
      );
    }
  }

  void _showError(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> _exportPdf() async {
    if (_isExporting) {
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final target = <String, dynamic>{
        'id': null,
        'name': 'Pass Managers',
        'type': 'folder',
        'children': await _repository.getCompleteTree(),
      };

      final fileUri = await _pdfExportService.exportTree(
        root: target,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fileUri == null || fileUri.isEmpty
                ? 'ذخیره PDF لغو شد.'
                : 'PDF با موفقیت ذخیره شد.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'خطا در ساخت PDF:\n$error',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<String?> _askMasterPasswordForBackup({
    required String title,
  }) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Master Password',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              Navigator.pop(
                dialogContext,
                value,
              );
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('لغو'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(
                  dialogContext,
                  controller.text,
                );
              }
            },
            child: const Text('ادامه'),
          ),
        ],
      ),
    );

    controller.dispose();

    return result;
  }

  Future<void> _createBackup() async {
    if (_isBackupBusy) {
      return;
