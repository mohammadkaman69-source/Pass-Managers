import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfExportService {
  static const MethodChannel _channel =
      MethodChannel('pass_managers/file_saver');

  Future<String?> exportTree({
    required Map<String, dynamic> root,
  }) async {
    final document = pw.Document();

    final fontData = await rootBundle.load(
      'assets/fonts/BNazanin.ttf',
    );
    final font = pw.Font.ttf(fontData);

    // BNazanin does not contain Latin glyphs. Helvetica is used as a
    // fallback so English names/passwords are rendered instead of blank.
    final latinFallback = pw.Font.helvetica();

    final content = <pw.Widget>[];

    _buildTreeContent(
      node: root,
      content: content,
      font: font,
      latinFallback: latinFallback,
      level: 0,
    );

    if (content.isEmpty) {
      content.add(
        _text(
          'محتوایی برای Export وجود ندارد.',
          font: font,
          latinFallback: latinFallback,
          fontSize: 14,
        ),
      );
    }

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(
          base: font,
        ),
        header: (context) {
          return pw.Align(
            alignment: pw.Alignment.centerRight,
            child: _text(
              root['name']?.toString() ?? 'Pass Managers',
              font: font,
              latinFallback: latinFallback,
              fontSize: 20,
              bold: true,
            ),
          );
        },
        footer: (context) {
          return pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: _text(
              'صفحه ${context.pageNumber} / ${context.pagesCount}',
              font: font,
              latinFallback: latinFallback,
              fontSize: 9,
            ),
          );
        },
        build: (context) => content,
      ),
    );

    final bytes = Uint8List.fromList(await document.save());
    final safeName = _sanitizeFileName(
      root['name']?.toString() ?? 'Pass-Managers',
    );
    final fileName = '$safeName.pdf';

    // Android's file_picker saveFile(bytes: ...) is not supported reliably
    // on all Android versions. Use the native ACTION_CREATE_DOCUMENT bridge.
    if (Platform.isAndroid) {
      return _channel.invokeMethod<String>(
        'savePdf',
        <String, dynamic>{
          'fileName': fileName,
          'bytes': bytes,
        },
      );
    }

    // Desktop fallback (including Windows).
    return FilePicker.platform.saveFile(
      dialogTitle: 'ذخیره PDF Pass Managers',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: bytes,
    );
  }

  void _buildTreeContent({
    required Map<String, dynamic> node,
    required List<pw.Widget> content,
    required pw.Font font,
    required pw.Font latinFallback,
    required int level,
  }) {
    final name = node['name']?.toString() ?? '';
    final type = node['type']?.toString() ?? '';
    final indent = level * 18.0;

    if (type == 'folder') {
      content.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(
            right: indent,
            top: level == 0 ? 0 : 12,
            bottom: 7,
          ),
          child: _text(
            'پوشه: $name',
            font: font,
            latinFallback: latinFallback,
            fontSize: level == 0 ? 20 : 16,
            bold: true,
          ),
        ),
      );

      final children = node['children'];
      if (children is List) {
        for (final child in children) {
          if (child is Map) {
            _buildTreeContent(
              node: Map<String, dynamic>.from(child),
              content: content,
              font: font,
              latinFallback: latinFallback,
              level: level + 1,
            );
          }
        }
      }
      return;
    }

    if (type == 'table') {
      _buildTableContent(
        node: node,
        content: content,
        font: font,
        latinFallback: latinFallback,
        level: level,
      );
      return;
    }

    content.add(
      pw.Padding(
        padding: pw.EdgeInsets.only(
          right: indent,
          top: 8,
          bottom: 4,
        ),
        child: _text(
          name,
          font: font,
          latinFallback: latinFallback,
          fontSize: 14,
        ),
      ),
    );
  }

  void _buildTableContent({
    required Map<String, dynamic> node,
    required List<pw.Widget> content,
    required pw.Font font,
    required pw.Font latinFallback,
    required int level,
  }) {
    final name = node['name']?.toString() ?? '';
    final indent = level * 18.0;

    content.add(pw.SizedBox(height: 10));
    content.add(
      pw.Padding(
        padding: pw.EdgeInsets.only(
          right: indent,
          bottom: 8,
        ),
        child: _text(
          'جدول: $name',
          font: font,
          latinFallback: latinFallback,
          fontSize: 17,
          bold: true,
        ),
      ),
    );

    final rows = node['rows'];
    if (rows is! List || rows.isEmpty) {
      content.add(
        _message(
          'این جدول رکوردی ندارد.',
          font,
          latinFallback,
          indent + 10,
        ),
      );
      return;
    }

    final fieldPositions = <String, int>{};

    for (final rawRow in rows) {
      if (rawRow is! Map) continue;
      final fields = rawRow['fields'];
      if (fields is! List) continue;

      for (final rawField in fields) {
        if (rawField is! Map) continue;
        final fieldName = rawField['name']?.toString() ?? '';
        if (fieldName.isEmpty) continue;

        final rawPosition = rawField['position'];
        final position = rawPosition is int ? rawPosition : 999999;
        final oldPosition = fieldPositions[fieldName];

        if (oldPosition == null || position < oldPosition) {
          fieldPositions[fieldName] = position;
        }
      }
    }

    if (fieldPositions.isEmpty) {
      content.add(
        _message(
          'این جدول فیلدی ندارد.',
          font,
          latinFallback,
          indent + 10,
        ),
      );
      return;
    }

    final columns = fieldPositions.keys.toList()
      ..sort((a, b) {
        final positionCompare =
            fieldPositions[a]!.compareTo(fieldPositions[b]!);
        return positionCompare != 0
            ? positionCompare
            : a.compareTo(b);
      });

    final tableData = <List<String>>[];

    for (final rawRow in rows) {
      if (rawRow is! Map) continue;

      final values = rawRow['values'];
      final rowValues = <String>[];

      for (final columnName in columns) {
        var value = '';
        if (values is Map && values[columnName] != null) {
          value = values[columnName].toString();
        }
        rowValues.add(value);
      }

      tableData.add(rowValues);
    }

    final normalStyle = pw.TextStyle(
      font: font,
      fontFallback: [latinFallback],
      fontSize: 8,
    );
    final headerStyle = pw.TextStyle(
      font: font,
      fontFallback: [latinFallback],
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
    );

    final visualColumns = columns
        .map(_protectLtrRuns)
        .toList();
    final visualTableData = tableData
        .map(
          (row) => row.map(_protectLtrRuns).toList(),
        )
        .toList();

    content.add(
      pw.Padding(
        padding: pw.EdgeInsets.only(
          right: indent,
          bottom: 16,
        ),
        child: pw.TableHelper.fromTextArray(
          headers: visualColumns,
          data: visualTableData,
          headerStyle: headerStyle,
          cellStyle: normalStyle,
          headerDecoration: const pw.BoxDecoration(
            color: PdfColors.grey300,
          ),
          cellAlignment: pw.Alignment.centerRight,
          headerAlignment: pw.Alignment.centerRight,
          border: pw.TableBorder.all(
            color: PdfColors.grey500,
            width: 0.5,
          ),
          cellPadding: const pw.EdgeInsets.all(4),
        ),
      ),
    );
  }

  pw.Widget _message(
    String message,
    pw.Font font,
    pw.Font latinFallback,
    double right,
  ) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(
        right: right,
        bottom: 10,
      ),
      child: _text(
        message,
        font: font,
        latinFallback: latinFallback,
        fontSize: 10,
      ),
    );
  }

  bool _containsRtl(String value) {
    return RegExp(r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]').hasMatch(value);
  }

  String _protectLtrRuns(String value) {
    // In an RTL paragraph the pdf package may reorder Latin runs visually.
    // LRM keeps English words and identifiers in their natural left-to-right order.
    return value.replaceAllMapped(
      RegExp(r'[A-Za-z][A-Za-z0-9 _./:@#?+\-]*'),
      (match) => '\u200E${match.group(0)}\u200E',
    );
  }

  pw.Text _text(
    String value, {
    required pw.Font font,
    required pw.Font latinFallback,
    double fontSize = 14,
    bool bold = false,
  }) {
    final rtl = _containsRtl(value);
    final displayValue = rtl ? _protectLtrRuns(value) : value;

    return pw.Text(
      displayValue,
      textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      style: pw.TextStyle(
        font: font,
        fontFallback: [latinFallback],
        fontSize: fontSize,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    );
  }

  String _sanitizeFileName(String name) {
    final sanitized = name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .trim();

    return sanitized.isEmpty ? 'Pass-Managers' : sanitized;
  }
}
