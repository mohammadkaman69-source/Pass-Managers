import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../export/tree_export_model.dart';

class PdfExportService {
  static const MethodChannel _channel =
      MethodChannel('pass_managers/file_saver');

  static const String _fontAsset = 'assets/fonts/BNazanin.ttf';

  Future<String?> exportTree({
    // Kept for API compatibility with existing callers. PDF generation no
    // longer depends on BuildContext, Navigator, Overlay, or Flutter rendering.
    BuildContext? context,
    required Map<String, dynamic> root,
  }) async {
    final title = _documentTitle(root);
    final document = await _buildDocument(root, title);
    final pdfBytes = await document.save();
    final fileName = '${_sanitizeFileName(title)}.pdf';

    if (Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod<String>(
          'savePdf',
          <String, dynamic>{
            'fileName': fileName,
            'bytes': pdfBytes,
          },
        );

        if (result != null && result.trim().isNotEmpty) {
          try {
            await _channel.invokeMethod<bool>(
              'openPdf',
              <String, dynamic>{'uri': result},
            );
          } catch (_) {}
        }

        return result;
      } finally {
        pdfBytes.fillRange(0, pdfBytes.length, 0);
      }
    }

    try {
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'ذخیره PDF Pass Managers',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        bytes: pdfBytes,
      );

      return savedPath?.toString();
    } finally {
      pdfBytes.fillRange(0, pdfBytes.length, 0);
    }
  }

  Future<pw.Document> _buildDocument(
    Map<String, dynamic> root,
    String title,
  ) async {
    final fontData = await rootBundle.load(_fontAsset);
    final persianFont = pw.Font.ttf(fontData.buffer.asByteData());
    final latinFallback = pw.Font.helvetica();
    final latinBoldFallback = pw.Font.helveticaBold();

    final document = pw.Document();
    final exportDocument = _toExportDocument(root);
    final content = _buildContent(
      exportDocument,
      persianFont,
      latinFallback,
      latinBoldFallback,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 30, 30, 34),
        maxPages: 500,
        textDirection: pw.TextDirection.rtl,
        header: (_) => pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: _text(
            title.isEmpty ? 'Pass Managers' : title,
            persianFont,
            latinFallback,
            fontSize: 20,
            bold: true,
            direction: pw.TextDirection.rtl,
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.only(top: 7),
          child: _text(
            'صفحه ${context.pageNumber} از ${context.pagesCount}',
            persianFont,
            latinFallback,
            fontSize: 9,
            direction: pw.TextDirection.rtl,
          ),
        ),
        build: (_) => content,
      ),
    );

    return document;
  }

  TreeExportDocument _toExportDocument(Map<String, dynamic> root) {
    final rawChildren = root['children'];

    final children = rawChildren is List
        ? rawChildren
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];

    return TreeExportDocument.fromRepositoryData(children);
  }

  List<pw.Widget> _buildContent(
    TreeExportDocument document,
    pw.Font persianFont,
    pw.Font latinFallback,
    pw.Font latinBoldFallback,
  ) {
    final widgets = <pw.Widget>[];

    for (final node in document.roots) {
      _appendNode(
        widgets,
        node,
        persianFont,
        latinFallback,
        latinBoldFallback,
      );
    }

    if (widgets.isEmpty) {
      widgets.add(
        pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.only(top: 12),
          child: _text(
            'محتوایی برای Export وجود ندارد.',
            persianFont,
            latinFallback,
            fontSize: 12,
            direction: pw.TextDirection.rtl,
          ),
        ),
      );
    }

    return widgets;
  }

  void _appendNode(
    List<pw.Widget> widgets,
    TreeExportNode node,
    pw.Font persianFont,
    pw.Font latinFallback,
    pw.Font latinBoldFallback,
  ) {
    if (node.isFolder) {
      widgets.add(
        pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(top: 8, bottom: 6),
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFECECEC),
          ),
          child: _text(
            'پوشه: ${node.name}',
            persianFont,
            latinFallback,
            fontSize: 14,
            bold: true,
            direction: pw.TextDirection.rtl,
          ),
        ),
      );

      for (final child in node.children) {
        _appendNode(
          widgets,
          child,
          persianFont,
          latinFallback,
          latinBoldFallback,
        );
      }
      return;
    }

    if (node.isTable) {
      _appendTable(
        widgets,
        node,
        persianFont,
        latinFallback,
        latinBoldFallback,
      );
    }
  }

  void _appendTable(
    List<pw.Widget> widgets,
    TreeExportNode table,
    pw.Font persianFont,
    pw.Font latinFallback,
    pw.Font latinBoldFallback,
  ) {
    widgets.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8, bottom: 5),
        child: _text(
          'جدول: ${table.name}',
          persianFont,
          latinFallback,
          fontSize: 13,
          bold: true,
          direction: pw.TextDirection.rtl,
        ),
      ),
    );

    final columns = [...table.columns]
      ..sort((a, b) => a.position.compareTo(b.position));

    if (columns.isEmpty) {
      widgets.add(
        _text(
          'این جدول فیلدی ندارد.',
          persianFont,
          latinFallback,
          fontSize: 10,
          direction: pw.TextDirection.rtl,
        ),
      );
      return;
    }

    if (table.rows.isEmpty) {
      widgets.add(
        _text(
          'این جدول رکوردی ندارد.',
          persianFont,
          latinFallback,
          fontSize: 10,
          direction: pw.TextDirection.rtl,
        ),
      );
      return;
    }

    final data = <List<String>>[
      <String>['#', ...columns.map((column) => column.name)],
      for (var rowIndex = 0; rowIndex < table.rows.length; rowIndex++)
        <String>[
          '${rowIndex + 1}',
          ...columns.map(
            (column) => table.rows[rowIndex].values[column.name] ?? '—',
          ),
        ],
    ];

    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(30),
      for (var index = 1; index <= columns.length; index++)
        index: const pw.FlexColumnWidth(1),
    };

    widgets.add(
      pw.TableHelper.fromTextArray(
        data: data,
        headerCount: 1,
        columnWidths: columnWidths,
        tableWidth: pw.TableWidth.max,
        cellPadding: const pw.EdgeInsets.symmetric(
          horizontal: 5,
          vertical: 5,
        ),
        cellAlignment: pw.Alignment.centerRight,
        headerAlignment: pw.Alignment.centerRight,
        headerDirection: pw.TextDirection.rtl,
        tableDirection: pw.TextDirection.rtl,
        headerDecoration: const pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFE0E0E0),
        ),
        border: pw.TableBorder.all(
          color: const PdfColor.fromInt(0xFF777777),
          width: 0.5,
        ),
        headerStyle: pw.TextStyle(
          font: persianFont,
          fontFallback: <pw.Font>[latinFallback, latinBoldFallback],
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
        ),
        cellStyle: pw.TextStyle(
          font: persianFont,
          fontFallback: <pw.Font>[latinFallback],
          fontSize: 8.5,
        ),
        cellBuilder: (index, data, rowNum) {
          final value = data?.toString() ?? '';
          final direction = _directionFor(value);
          final isHeader = rowNum == 0;

          return pw.Directionality(
            textDirection: direction,
            child: pw.Text(
              value,
              textAlign: direction == pw.TextDirection.rtl
                  ? pw.TextAlign.right
                  : pw.TextAlign.left,
              softWrap: true,
              style: pw.TextStyle(
                font: persianFont,
                fontFallback: <pw.Font>[
                  latinFallback,
                  if (isHeader) latinBoldFallback,
                ],
                fontSize: isHeader ? 9 : 8.5,
                fontWeight: isHeader
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );

    widgets.add(const pw.SizedBox(height: 7));
  }

  pw.Widget _text(
    String value,
    pw.Font persianFont,
    pw.Font latinFallback, {
    required double fontSize,
    bool bold = false,
    required pw.TextDirection direction,
  }) {
    return pw.Directionality(
      textDirection: direction,
      child: pw.Text(
        value,
        textAlign: direction == pw.TextDirection.rtl
            ? pw.TextAlign.right
            : pw.TextAlign.left,
        softWrap: true,
        style: pw.TextStyle(
          font: persianFont,
          fontFallback: <pw.Font>[latinFallback],
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.TextDirection _directionFor(String value) {
    return RegExp(r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]')
            .hasMatch(value)
        ? pw.TextDirection.rtl
        : pw.TextDirection.ltr;
  }

  String _documentTitle(Map<String, dynamic> root) {
    final title = root['name']?.toString().trim() ?? '';
    return title.isEmpty ? 'Pass Managers' : title;
  }

  String _sanitizeFileName(String name) {
    final clean = name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .trim();

    return clean.isEmpty ? 'Pass-Managers' : clean;
  }
}
