import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfExportService {
  Future<File> exportTree({
    required Map<String, dynamic> root,
    required BuildContext context,
  }) async {
    final document = pw.Document();

    final fontData = await rootBundle.load(
      'assets/fonts/BNazanin.ttf',
    );

    final font = pw.Font.ttf(fontData);

    final content = <pw.Widget>[];

    _buildTreeContent(
      node: root,
      content: content,
      font: font,
      level: 0,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: font,
        ),
        build: (context) {
          return content;
        },
      ),
    );

    final bytes = await document.save();

    /*
     * این قسمت باید با Android Storage Access Framework
     * انجام شود تا روی Androidهای جدید محدودیت مسیر
     * /storage/emulated/0/Download وجود نداشته باشد.
     *
     * در نسخه فعلی سرویس، فایل موقت داخل cache ساخته می‌شود
     * و بعد باید توسط فایل‌سیور/SAF به محل انتخابی کاربر منتقل شود.
     */

    final tempDirectory =
        Directory.systemTemp;

    final safeName = _sanitizeFileName(
      root['name']?.toString() ?? 'export',
    );

    final file = File(
      '${tempDirectory.path}/$safeName.pdf',
    );

    await file.writeAsBytes(
      bytes,
      flush: true,
    );

    return file;
  }

  void _buildTreeContent({
    required Map<String, dynamic> node,
    required List<pw.Widget> content,
    required pw.Font font,
    required int level,
  }) {
    final name =
        node['name']?.toString() ?? '';

    final type =
        node['type']?.toString() ?? '';

    final indent =
        level * 18.0;

    if (type == 'folder') {
      content.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(
            right: indent,
            top: level == 0 ? 0 : 10,
            bottom: 6,
          ),
          child: pw.Text(
            '📁 $name',
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(
              font: font,
              fontSize:
                  level == 0 ? 20 : 16,
              fontWeight:
                  pw.FontWeight.bold,
            ),
          ),
        ),
      );

      final children =
          node['children'];

      if (children is List) {
        for (final child in children) {
          if (child is Map<String, dynamic>) {
            _buildTreeContent(
              node: child,
              content: content,
              font: font,
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
        child: pw.Text(
          name,
          textDirection:
              pw.TextDirection.rtl,
          style: pw.TextStyle(
            font: font,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _buildTableContent({
    required Map<String, dynamic> node,
    required List<pw.Widget> content,
    required pw.Font font,
    required int level,
  }) {
    final name =
        node['name']?.toString() ?? '';

    final indent =
        level * 18.0;

    content.add(
      pw.SizedBox(
        height: 8,
      ),
    );

    content.add(
      pw.Padding(
        padding: pw.EdgeInsets.only(
          right: indent,
          bottom: 8,
        ),
        child: pw.Text(
          '📋 $name',
          textDirection:
              pw.TextDirection.rtl,
          style: pw.TextStyle(
            font: font,
            fontSize: 17,
            fontWeight:
                pw.FontWeight.bold,
          ),
        ),
      ),
    );

    final rows = node['rows'];

    if (rows is! List || rows.isEmpty) {
      content.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(
            right: indent + 10,
            bottom: 8,
          ),
          child: pw.Text(
            'این جدول رکوردی ندارد.',
            textDirection:
                pw.TextDirection.rtl,
            style: pw.TextStyle(
              font: font,
              fontSize: 10,
            ),
          ),
        ),
      );

      return;
    }

    final columns =
        <String>[];

    for (final row in rows) {
      if (row is! Map<String, dynamic>) {
        continue;
      }

      final fields =
          row['fields'];

      if (fields is List) {
        for (final field in fields) {
          if (field is Map<String, dynamic>) {
            final fieldName =
                field['name']?.toString() ?? '';

            if (fieldName.isNotEmpty &&
                !columns.contains(
                  fieldName,
                )) {
              columns.add(fieldName);
            }
          }
        }
      }
    }

    if (columns.isEmpty) {
      content.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(
            right: indent + 10,
            bottom: 8,
          ),
          child: pw.Text(
            'این جدول فیلدی ندارد.',
            textDirection:
                pw.TextDirection.rtl,
            style: pw.TextStyle(
              font: font,
              fontSize: 10,
            ),
          ),
        ),
      );

      return;
    }

    final tableData =
        <List<String>>[];

    for (final row in rows) {
      if (row is! Map<String, dynamic>) {
        continue;
      }

      final values =
          row['values'];

      final rowValues =
          <String>[];

      for (final columnName in columns) {
        var value = '';

        if (values is Map) {
          final rawValue =
              values[columnName];

          if (rawValue != null) {
            value = rawValue.toString();
          }
        }

        final isPassword =
            columnName
                .toLowerCase()
                .contains('password');

        if (isPassword &&
            value.isNotEmpty) {
          value = '••••••••';
        }

        rowValues.add(value);
      }

      tableData.add(rowValues);
    }

    content.add(
      pw.Padding(
        padding: pw.EdgeInsets.only(
          right: indent,
          bottom: 14,
        ),
        child:
            pw.TableHelper.fromTextArray(
          headers: columns,
          data: tableData,
          headerStyle:
              pw.TextStyle(
            font: font,
            fontSize: 9,
            fontWeight:
                pw.FontWeight.bold,
          ),
          cellStyle:
              pw.TextStyle(
            font: font,
            fontSize: 8,
          ),
          headerDecoration:
              const pw.BoxDecoration(
            color: PdfColors.grey300,
          ),
          cellAlignment:
              pw.Alignment.centerRight,
          headerAlignment:
              pw.Alignment.centerRight,
          border:
              pw.TableBorder.all(
            color: PdfColors.grey500,
            width: 0.5,
          ),
        ),
      ),
    );
  }

  String _sanitizeFileName(
    String name,
  ) {
    final sanitized = name
        .replaceAll(
          RegExp(r'[<>:"/\\|?*]'),
          '_',
        )
        .trim();

    if (sanitized.isEmpty) {
      return 'export';
    }

    return sanitized;
  }
}
