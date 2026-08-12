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

    final content = <pw.Widget>[];

    _buildTreeContent(
      node: root,
      content: content,
      font: font,
      level: 0,
    );

    if (content.isEmpty) {
      content.add(
        pw.Text(
          'محتوایی برای Export وجود ندارد.',
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(
            font: font,
            fontSize: 14,
          ),
        ),
      );
    }

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: font,
        ),
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return content;
        },
      ),
    );

    final bytes = Uint8List.fromList(
      await document.save(),
    );

    final safeName = _sanitizeFileName(
      root['name']?.toString() ?? 'Pass-Managers',
    );

    final fileName = '$safeName.pdf';

    final result = await _channel.invokeMethod<String>(
      'savePdf',
      <String, dynamic>{
        'fileName': fileName,
        'bytes': bytes,
      },
    );

    return result;
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
            top: level == 0 ? 0 : 12,
            bottom: 7,
          ),
          child: pw.Text(
            level == 0
                ? 'پوشه: $name'
                : 'پوشه: $name',
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
        height: 10,
      ),
    );

    content.add(
      pw.Padding(
        padding: pw.EdgeInsets.only(
          right: indent,
          bottom: 8,
        ),
        child: pw.Text(
          'جدول: $name',
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
            bottom: 10,
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

    /*
     * ستون‌ها را بر اساس position جمع می‌کنیم.
     * چون fields هر رکورد ممکن است متفاوت باشد،
     * از تمام رکوردها ستون‌های موجود را جمع می‌کنیم.
     */
    final fieldPositions =
        <String, int>{};

    for (final rawRow in rows) {
      if (rawRow is! Map) {
        continue;
      }

      final row =
          Map<String, dynamic>.from(rawRow);

      final fields =
          row['fields'];

      if (fields is! List) {
        continue;
      }

      for (final rawField in fields) {
        if (rawField is! Map) {
          continue;
        }

        final field =
            Map<String, dynamic>.from(
          rawField,
        );

        final fieldName =
            field['name']?.toString() ?? '';

        if (fieldName.isEmpty) {
          continue;
        }

        final position =
            field['position'] is int
                ? field['position'] as int
                : 999999;

        final oldPosition =
            fieldPositions[fieldName];

        if (oldPosition == null ||
            position < oldPosition) {
          fieldPositions[fieldName] =
              position;
        }
      }
    }

    final sortedNames =
        fieldPositions.keys.toList()
          ..sort(
            (a, b) {
              final positionCompare =
                  fieldPositions[a]!
                      .compareTo(
                    fieldPositions[b]!,
                  );

              if (positionCompare != 0) {
                return positionCompare;
              }

              return a.compareTo(b);
            },
          );

    columns.addAll(
      sortedNames,
    );

    if (columns.isEmpty) {
      content.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(
            right: indent + 10,
            bottom: 10,
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

    for (final rawRow in rows) {
      if (rawRow is! Map) {
        continue;
      }

      final row =
          Map<String, dynamic>.from(rawRow);

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

        final lowerName =
            columnName.toLowerCase();

        final isPassword =
            lowerName.contains('password') ||
            lowerName.contains('pass') ||
            columnName.contains('رمز') ||
            columnName.contains('پسورد') ||
            columnName.contains('گذرواژه');

        if (isPassword &&
            value.isNotEmpty) {
          value = '••••••••';
        }

        rowValues.add(value);
      }

      tableData.add(
        rowValues,
      );
    }

    content.add(
      pw.Padding(
        padding: pw.EdgeInsets.only(
          right: indent,
          bottom: 16,
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
          cellPadding:
              const pw.EdgeInsets.all(4),
        ),
      ),
    );
  }

  String _sanitizeFileName(
    String name,
  ) {
    final sanitized =
        name.replaceAll(
      RegExp(r'[<>:"/\\|?*]'),
      '_',
    ).trim();

    if (sanitized.isEmpty) {
      return 'Pass-Managers';
    }

    return sanitized;
  }
}
