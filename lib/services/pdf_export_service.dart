import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfExportService {
  Future<Uint8List> buildTreePdf({
    required Map<String, dynamic> root,
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

    return document.save();
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
            textDirection:
                pw.TextDirection.rtl,
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
          if (child is Map) {
            _buildTreeContent(
              node: Map<String, dynamic>.from(
                child,
              ),
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
      if (row is! Map) {
        continue;
      }

      final fields =
          row['fields'];

      if (fields is List) {
        for (final field in fields) {
          if (field is Map) {
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
      if (row is! Map) {
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
            value =
                rawValue.toString();
          }
        }

        final isPassword =
            columnName
                .toLowerCase()
                .contains(
                  'password',
                );

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
            pw.TableHelper
