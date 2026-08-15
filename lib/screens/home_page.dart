import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_record.dart';
import '../repositories/app_repository.dart';
import '../services/pdf_export_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AppRepository _repository = AppRepository();
  final PdfExportService _pdfExportService = PdfExportService();

  bool _isExporting = false;

  void _showMessage(String message) {
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
    if (_isExporting || !mounted) {
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final children = await _repository.getCompleteTree();

      if (!mounted) {
        return;
      }

      final target = <String, dynamic>{
        'id': null,
        'name': 'Pass Managers',
        'type': 'folder',
        'children': children,
      };

      final fileUri = await _pdfExportService.exportTree(
        context: context,
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
    } catch (e) {
      if (mounted) {
        _showMessage('خطا در ساخت PDF: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pass Managers'),
      ),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: _isExporting ? null : _exportPdf,
          icon: const Icon(Icons.picture_as_pdf),
          label: Text(_isExporting ? 'در حال ساخت PDF...' : 'ساخت PDF'),
        ),
      ),
    );
  }
}
