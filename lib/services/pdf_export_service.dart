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
  static const String _lrm = '\u200E';

  Future<String?> exportTree({
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
          <String, dynamic>{'fileName': fileName, 'bytes': pdfBytes},
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
        level: 0,
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
    pw.Font latinBoldFallback, {
    required int level,
  }) {
    final indent = level * 22.0;

    if (node.isFolder) {
      widgets.add(
        pw.Container(
          width: double.infinity,
          margin: pw.EdgeInsets.only(
            top: level == 0 ? 8 : 4,
            bottom: 5,
          ),
          padding: pw.EdgeInsets.only(
            right: 8 + indent,
            left: 8,
            top: 6,
            bottom: 6,
          ),
          decoration: pw.BoxDecoration(
            color: level == 0
                ? PdfColor.fromInt(0xFFE6E6E6)
                : PdfColor.fromInt(0xFFF0F0F0),
            border: level > 0
                ? pw.Border(
                    right: pw.BorderSide(
                      color: PdfColor.fromInt(0xFFAAAAAA),
                      width: 1,
                    ),
                  )
                : null,
          ),
          child: _richText(
            node.name,
            persianFont,
            latinFallback,
            latinBoldFallback,
            fontSize: level == 0 ? 14 : 12.5,
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
          level: level + 1,
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
        level: level,
        indent: indent,
      );
    }
  }

  void _appendTable(
    List<pw.Widget> widgets,
    TreeExportNode table,
    pw.Font persianFont,
    pw.Font latinFallback,
    pw.Font latinBoldFallback, {
    required int level,
    required double indent,
  }) {
    widgets.add(
      pw.Padding(
        padding: pw.EdgeInsets.only(
          right: indent,
          top: 7,
          bottom: 5,
        ),
        child: _richText(
          table.name,
          persianFont,
          latinFallback,
          latinBoldFallback,
          fontSize: level == 0 ? 13 : 12,
          bold: true,
          paragraphDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.right,
        ),
      ),
    );

    final columns = _columnsForTable(table);
    if (columns.isEmpty) {
      widgets.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(right: indent + 22),
          child: _richText(
            'این جدول فیلدی ندارد.',
            persianFont,
            latinFallback,
            latinBoldFallback,
            fontSize: 10,
            paragraphDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
          ),
        ),
      );
      return;
    }
    if (table.rows.isEmpty) {
      widgets.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(right: indent + 22),
          child: _richText(
            'این جدول رکوردی ندارد.',
            persianFont,
            latinFallback,
            latinBoldFallback,
            fontSize: 10,
            paragraphDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
          ),
        ),
      );
      return;
    }

    // Export only real fields. The previous '#' column was a synthetic
    // row-number column, not a table field; with BNazanin it could appear as '!'.
    final data = <List<String>>[
      columns.map((column) => column.name).toList(),
      for (var rowIndex = 0; rowIndex < table.rows.length; rowIndex++)
        columns.map(
          (column) => table.rows[rowIndex].values[column.name] ?? '—',
        ).toList(),
    ];

    final columnWidths = <int, pw.TableColumnWidth>{
      for (var index = 0; index < columns.length; index++)
        index: const pw.FlexColumnWidth(1),
    };

    widgets.add(
      pw.Padding(
        padding: pw.EdgeInsets.only(right: indent),
        child: pw.TableHelper.fromTextArray(
          data: data,
          headerCount: 1,
          columnWidths: columnWidths,
          tableWidth: pw.TableWidth.max,
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          cellAlignment: pw.Alignment.centerRight,
          headerAlignment: pw.Alignment.centerRight,
          headerDirection: pw.TextDirection.rtl,
          tableDirection: pw.TextDirection.rtl,
          headerDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFE0E0E0)),
          border: pw.TableBorder.all(
            color: PdfColor.fromInt(0xFF777777),
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
            final direction = _paragraphDirectionFor(value);

            // Use the exact same bidi/LRM path for headers as for values.
            return _richText(
              value,
              persianFont,
              latinFallback,
              latinBoldFallback,
              fontSize: isHeader ? 9 : 8.5,
              bold: isHeader,
              paragraphDirection: direction,
              textAlign: direction == pw.TextDirection.rtl
                  ? pw.TextAlign.right
                  : pw.TextAlign.left,
            );
          },
        ),
      ),
    );
    widgets.add(pw.SizedBox(height: 7));
  }

  List<TreeExportColumn> _columnsForTable(TreeExportNode table) {
    final byName = <String, TreeExportColumn>{};

    for (final column in table.columns) {
      if (column.name.trim().isEmpty) continue;
      final existing = byName[column.name];
      if (existing == null || column.position < existing.position) {
        byName[column.name] = column;
      }
    }

    for (final row in table.rows) {
      for (final field in row.fields) {
        if (field.name.trim().isEmpty) continue;
        final existing = byName[field.name];
        if (existing == null || field.position < existing.position) {
          byName[field.name] = field;
        }
      }
    }

    final columns = byName.values.toList()
      ..sort((a, b) {
        final position = a.position.compareTo(b.position);
        if (position != 0) return position;
        return a.name.compareTo(b.name);
      });

    return columns;
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
          style: pw.TextStyle(font: persianFont, fontSize: fontSize),
        ),
      );
    }

    final runs = _splitDirectionalRuns(value);
    final spans = <pw.InlineSpan>[];

    for (final run in runs) {
      if (run.text.isEmpty) continue;
      final isRtl = run.direction == pw.TextDirection.rtl;
      final font = isRtl
          ? persianFont
          : (bold ? latinBoldFallback : latinFallback);
      final protectedText = isRtl
          ? run.text
          : '$_lrm${run.text}$_lrm';

      spans.add(
        pw.TextSpan(
          text: protectedText,
          style: pw.TextStyle(
            font: font,
            fontFallback:
                isRtl ? <pw.Font>[latinFallback] : <pw.Font>[persianFont],
            fontSize: fontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    return pw.RichText(
      textDirection: paragraphDirection,
      textAlign: textAlign,
      softWrap: true,
      text: pw.TextSpan(children: spans),
    );
  }

  bool _containsRtl(String value) {
    return RegExp(
      r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]',
    ).hasMatch(value);
  }

  List<_DirectionalRun> _splitDirectionalRuns(String value) {
    final runs = <_DirectionalRun>[];
    final buffer = StringBuffer();
    pw.TextDirection? currentDirection;
    var pendingNeutral = StringBuffer();

    void flush() {
      if (buffer.isEmpty || currentDirection == null) return;
      runs.add(_DirectionalRun(buffer.toString(), currentDirection));
      buffer.clear();
    }

    for (final rune in value.runes) {
      final character = String.fromCharCode(rune);
      final direction = _strongDirection(character);

      if (direction == null) {
        if (currentDirection == null) {
          pendingNeutral.write(character);
        } else {
          buffer.write(character);
        }
        continue;
      }

      if (currentDirection == null) {
        currentDirection = direction;
        if (pendingNeutral.isNotEmpty) {
          buffer.write(pendingNeutral.toString());
          pendingNeutral = StringBuffer();
        }
        buffer.write(character);
        continue;
      }

      if (direction != currentDirection) {
        flush();
        currentDirection = direction;
      }
      buffer.write(character);
    }

    if (pendingNeutral.isNotEmpty) {
      currentDirection ??= pw.TextDirection.ltr;
      buffer.write(pendingNeutral.toString());
    }
    flush();

    return runs.isEmpty
        ? <_DirectionalRun>[_DirectionalRun(value, pw.TextDirection.ltr)]
        : runs;
  }

  pw.TextDirection? _strongDirection(String character) {
    if (RegExp(r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]')
        .hasMatch(character)) {
      return pw.TextDirection.rtl;
    }
    if (RegExp(r'[A-Za-z0-9\u00C0-\u024F\u1E00-\u1EFF]')
        .hasMatch(character)) {
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

  pw.TextDirection _paragraphDirectionFor(String value) {
    return _containsRtl(value)
        ? pw.TextDirection.rtl
        : pw.TextDirection.ltr;
  }

  String _documentTitle(Map<String, dynamic> root) {
    final title = root['name']?.toString().trim() ?? '';
    return title.isEmpty ? 'Pass Managers' : title;
  }

  String _sanitizeFileName(String name) {
    final clean = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    return clean.isEmpty ? 'Pass-Managers' : clean;
  }
}

class _DirectionalRun {
  const _DirectionalRun(this.text, this.direction);
  final String text;
  final pw.TextDirection direction;
}
