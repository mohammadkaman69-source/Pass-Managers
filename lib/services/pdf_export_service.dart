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
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(
          base: font,
        ),
        header: (context) {
          return pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              root['name']?.toString() ??
                  'Pass Managers',
              textDirection:
                  pw.TextDirection.rtl,
              style: pw.TextStyle(
                font: font,
                fontSize: 20,
                fontWeight:
                    pw.FontWeight.bold,
              ),
            ),
          );
        },
        footer: (context) {
          return pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              'صفحه ${context.pageNumber} / ${context.pagesCount}',
              textDirection:
                  pw.TextDirection.rtl,
              style: pw.TextStyle(
                font: font,
                fontSize: 9,
              ),
            ),
          );
        },
        build: (context) => content,
      ),
    );

    final bytes = await document.save();

    final safeName = _sanitizeFileName(
      root['name']?.toString() ??
          'Pass-Managers',
    );

    return _channel.invokeMethod<String>(
      'savePdf',
      <String, dynamic>{
        'fileName': '$safeName.pdf',
        'bytes': bytes,
      },
    );
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

    final indent = level * 18.0;

    if (type == 'folder') {
      content.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(
            right: indent,
            top: level == 0 ? 0 : 12,
            bottom: 7,
          ),
          child: pw.Text(
            'پوشه: $name',
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

      final children = node['children'];

      if (children is List) {
        for (final child in children) {
          if (child is Map) {
            _buildTreeContent(
              node:
                  Map<String, dynamic>.from(
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

    final indent = level * 18.0;

    content.add(
      pw.SizedBox(height: 10),
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

    if (rows is! List ||
        rows.isEmpty) {
      content.add(
        _message(
          'این جدول رکوردی ندارد.',
          font,
          indent + 10,
        ),
      );

      return;
    }

    final fieldPositions =
        <String, int>{};

    for (final rawRow in rows) {
      if (rawRow is! Map) {
        continue;
      }

      final fields = rawRow['fields'];

      if (fields is! List) {
        continue;
      }

      for (final rawField in fields) {
        if (rawField is! Map) {
          continue;
        }

        final fieldName =
            rawField['name']?.toString() ??
                '';

        if (fieldName.isEmpty) {
          continue;
        }

        final rawPosition =
            rawField['position'];

        final position =
            rawPosition is int
                ? rawPosition
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

    if (fieldPositions.isEmpty) {
      content.add(
        _message(
          'این جدول فیلدی ندارد.',
          font,
          indent + 10,
        ),
      );

      return;
    }

    final columns =
        fieldPositions.keys.toList()
          ..sort(
            (a, b) {
              final positionCompare =
                  fieldPositions[a]!
                      .compareTo(
                fieldPositions[b]!,
              );

              return positionCompare != 0
                  ? positionCompare
                  : a.compareTo(b);
            },
          );

    final tableData =
        <List<String>>[];

    for (final rawRow in rows) {
      if (rawRow is! Map) {
        continue;
      }

      final values = rawRow['values'];

      final rowValues =
          <String>[];

      for (final columnName
          in columns) {
        var value = '';

        if (values is Map &&
            values[columnName] !=
                null) {
          value =
              values[columnName]
                  .toString();
        }

        rowValues.add(value);
      }

      tableData.add(rowValues);
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
            color:
                PdfColors.grey500,
            width: 0.5,
          ),
          cellPadding:
              const pw.EdgeInsets.all(4),
        ),
      ),
    );
  }

  pw.Widget _message(
    String message,
    pw.Font font,
    double right,
  ) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(
        right: right,
        bottom: 10,
      ),
      child: pw.Text(
        message,
        textDirection:
            pw.TextDirection.rtl,
        style: pw.TextStyle(
          font: font,
          fontSize: 10,
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

    return sanitized.isEmpty
        ? 'Pass-Managers'
        : sanitized;
  }
}
