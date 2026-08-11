import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/tree_item.dart';

class PdfExportService {
  Future<File> exportTable({
    required TreeItem table,
    required Directory directory,
  }) async {
    final document = pw.Document();

    final columns = <String>[];

    for (final row in table.rows) {
      for (final column in row.columns) {
        if (!columns.contains(column.name)) {
          columns.add(column.name);
        }
      }
    }

    if (columns.isEmpty) {
      columns.addAll(
        table.columns.map(
          (column) => column.name,
        ),
      );
    }

    final rows = <List<String>>[];

    for (final row in table.rows) {
      rows.add(
        columns.map((columnName) {
          final value =
              row.values[columnName] ?? '';

          final isPassword =
              columnName
                  .toLowerCase()
                  .contains('password');

          if (isPassword &&
              value.isNotEmpty) {
            return '••••••••';
          }

          return value;
        }).toList(),
      );
    }

    final fontData = await rootBundle.load(
      'assets/fonts/NotoSans-Regular.ttf',
    );

    final font = pw.Font.ttf(
      fontData,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection:
            pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: font,
        ),
        build: (context) {
          return [
            pw.Directionality(
              textDirection:
                  pw.TextDirection.rtl,
              child: pw.Text(
                table.name,
                style: pw.TextStyle(
                  font: font,
                  fontSize: 20,
                  fontWeight:
                      pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 16),
            if (columns.isNotEmpty)
              pw.TableHelper.fromTextArray(
                headers: columns,
                data: rows,
                headerStyle:
                    pw.TextStyle(
                  font: font,
                  fontWeight:
                      pw.FontWeight.bold,
                ),
                cellStyle:
                    pw.TextStyle(
                  font: font,
                  fontSize: 9,
                ),
                headerDecoration:
                    const pw.BoxDecoration(
                  color:
                      PdfColors.grey300,
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
              ),
          ];
        },
      ),
    );

    final safeName = _sanitizeFileName(
      table.name,
    );

    final file = File(
      '${directory.path}/$safeName.pdf',
    );

    await file.writeAsBytes(
      await document.save(),
    );

    return file;
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
      return 'table';
    }

    return sanitized;
  }
}
