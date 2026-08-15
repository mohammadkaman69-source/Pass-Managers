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
    // Kept for API compatibility with existing callers. PDF generation does
    // not depend on BuildContext, Navigator, Overlay, or Flutter rendering.
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
          child: _richText(
            title.isEmpty ? 'Pass Managers' : title,
            persianFont,
            latinFallback,
            latinBoldFallback,
            fontSize: 20,
            bold: true,
            paragraphDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.only(top: 7),
          child: _richText(
            'صفحه ${context.pageNumber} از ${context.pagesCount}',
            persianFont,
            latinFallback,
            latinBoldFallback,
            fontSize: 9,
            paragraphDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.center,
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
          child: _richText(
            'محتوایی برای Export وجود ندارد.',
            persianFont,
            latinFallback,
            latinBoldFallback,
            fontSize: 12,
            paragraphDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
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
          child: _richText(
            'پوشه: ${node.name}',
            persianFont,
            latinFallback,
            latinBoldFallback,
            fontSize: 14,
            bold: true,
            paragraphDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
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
        child: _richText(
          'جدول: ${table.name}',
          persianFont,
          latinFallback,
          latinBoldFallback,
          fontSize: 13,
          bold: true,
          paragraphDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.right,
        ),
      ),
    );

    final columns = [...table.columns]
      ..sort((a, b) => a.position.compareTo(b.position));

    if (columns.isEmpty) {
      widgets.add(
        _richText(
          'این جدول فیلدی ندارد.',
          persianFont,
          latinFallback,
          latinBoldFallback,
          fontSize: 10,
          paragraphDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.right,
        ),
      );
      return;
    }

    if (table.rows.isEmpty) {
      widgets.add(
        _richText(
          'این جدول رکوردی ندارد.',
          persianFont,
          latinFallback,
          latinBoldFallback,
          fontSize: 10,
          paragraphDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.right,
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
          final isHeader = rowNum == 0;

          return _richText(
            value,
            persianFont,
            latinFallback,
            latinBoldFallback,
            fontSize: isHeader ? 9 : 8.5,
            bold: isHeader,
            paragraphDirection: _directionFor(value),
            textAlign: _directionFor(value) == pw.TextDirection.rtl
                ? pw.TextAlign.right
                : pw.TextAlign.left,
          );
        },
      ),
    );

    widgets.add(const pw.SizedBox(height: 7));
  }

  pw.Widget _richText(
    String value,
    pw.Font persianFont,
    pw.Font latinFallback,
    pw.Font latinBoldFallback, {
    required double fontSize,
    bool bold = false,
    required pw.TextDirection paragraphDirection,
    required pw.TextAlign textAlign,
  }) {
    if (value.isEmpty) {
      return pw.RichText(
        textDirection: paragraphDirection,
        textAlign: textAlign,
        text: pw.TextSpan(
          text: '',
          style: pw.TextStyle(
            font: persianFont,
            fontSize: fontSize,
          ),
        ),
      );
    }

    final runs = _splitDirectionalRuns(value);

    final spans = <pw.InlineSpan>[];
    for (final run in runs) {
      final isRtl = run.direction == pw.TextDirection.rtl;
      final font = isRtl
          ? persianFont
          : (bold ? latinBoldFallback : latinFallback);

      spans.add(
        pw.TextSpan(
          text: run.text,
          style: pw.TextStyle(
            font: font,
            fontFallback: isRtl
                ? <pw.Font>[latinFallback]
                : <pw.Font>[persianFont],
            fontSize: fontSize,
            fontWeight: isRtl && bold
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
          ),
        ),
      );
    }

    return pw.RichText(
      textDirection: paragraphDirection,
      textAlign: textAlign,
      softWrap: true,
      text: pw.TextSpan(
        children: spans,
      ),
    );
  }

  List<_DirectionalRun> _splitDirectionalRuns(String value) {
    final runs = <_DirectionalRun>[];
    final buffer = StringBuffer();
    pw.TextDirection? currentDirection;
    String? pendingNeutral;

    void flush() {
      if (buffer.isEmpty) return;
      runs.add(
        _DirectionalRun(
          buffer.toString(),
          currentDirection ?? pw.TextDirection.ltr,
        ),
      );
      buffer.clear();
    }

    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      final direction = _strongDirection(char);

      if (direction == null) {
        if (currentDirection == null) {
          pendingNeutral = '${pendingNeutral ?? ''}$char';
        } else {
          buffer.write(char);
        }
        continue;
      }

      if (currentDirection == null) {
        currentDirection = direction;
        if (pendingNeutral != null) {
          buffer.write(pendingNeutral);
          pendingNeutral = null;
        }
        buffer.write(char);
        continue;
      }

      if (direction != currentDirection) {
        flush();
        currentDirection = direction;
      }

      buffer.write(char);
    }

    if (pendingNeutral != null) {
      if (currentDirection == null) {
        currentDirection = pw.TextDirection.ltr;
      }
      buffer.write(pendingNeutral);
    }

    flush();
    return runs;
  }

  pw.TextDirection? _strongDirection(String char) {
    if (RegExp(r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]')
        .hasMatch(char)) {
      return pw.TextDirection.rtl;
    }

    if (RegExp(r'[A-Za-z\u00C0-\u024F\u1E00-\u1EFF0-9]').hasMatch(char)) {
      return pw.TextDirection.ltr;
    }

    return null;
  }

  pw.TextDirection _directionFor(String value) {
    for (final rune in value.runes) {
      final direction = _strongDirection(String.fromCharCode(rune));
      if (direction != null) return direction;
    }
    return pw.TextDirection.ltr;
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

class _DirectionalRun {
  const _DirectionalRun(this.text, this.direction);

  final String text;
  final pw.TextDirection direction;
}
