import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// PDF export is intentionally separated into a small document model and a
/// layout layer. This keeps database-shaped input away from PDF widgets and
/// makes RTL, pagination and table rendering deterministic.
class PdfExportService {
  static const MethodChannel _channel =
      MethodChannel('pass_managers/file_saver');

  Future<String?> exportTree({required Map<String, dynamic> root}) async {
    final document = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/BNazanin.ttf');
    final persianFont = pw.Font.ttf(fontData);
    final latinFont = pw.Font.helvetica();

    final model = _PdfDocumentModel.fromRoot(root);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 34, 28, 32),
        header: (context) => _buildHeader(
          model.title,
          persianFont,
          latinFont,
        ),
        footer: (context) => _buildFooter(
          context,
          persianFont,
          latinFont,
        ),
        build: (_) {
          final widgets = <pw.Widget>[];
          for (final folder in model.folders) {
            widgets.add(
              _buildFolder(
                folder,
                persianFont,
                latinFont,
              ),
            );
          }
          for (final table in model.rootTables) {
            widgets.add(
              _buildTable(
                table,
                persianFont,
                latinFont,
              ),
            );
          }
          if (widgets.isEmpty) {
            widgets.add(
              _buildText(
                'محتوایی برای Export وجود ندارد.',
                persianFont,
                latinFont,
                fontSize: 14,
              ),
            );
          }
          return widgets;
        },
      ),
    );

    final savedBytes = await document.save();
    final safeName = _sanitizeFileName(model.title);
    final fileName = '$safeName.pdf';

    if (Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod<String>(
          'savePdf',
          <String, dynamic>{
            'fileName': fileName,
            'bytes': savedBytes,
          },
        );
        if (result == null || result.trim().isEmpty) {
          return result;
        }
        try {
          await _channel.invokeMethod<bool>(
            'openPdf',
            <String, dynamic>{'uri': result},
          );
        } catch (_) {}
        return result;
      } finally {
        savedBytes.fillRange(0, savedBytes.length, 0);
      }
    }

    try {
      final result = await FilePicker.saveFile(
        dialogTitle: 'ذخیره PDF Pass Managers',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        bytes: savedBytes,
      );
      return result?.toString();
    } finally {
      savedBytes.fillRange(0, savedBytes.length, 0);
    }
  }

  pw.Widget _buildHeader(
    String title,
    pw.Font persianFont,
    pw.Font latinFont,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(bottom: 10),
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: PdfColors.grey500,
            width: 0.7,
          ),
        ),
      ),
      child: pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: _buildText(
          title.isEmpty ? 'Pass Managers' : title,
          persianFont,
          latinFont,
          fontSize: 20,
          bold: true,
          align: pw.TextAlign.right,
        ),
      ),
    );
  }

  pw.Widget _buildFooter(
    pw.Context context,
    pw.Font persianFont,
    pw.Font latinFont,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(top: 8),
      margin: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
            color: PdfColors.grey400,
            width: 0.5,
          ),
        ),
      ),
      child: pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: _buildText(
          'صفحه ${context.pageNumber} از ${context.pagesCount}',
          persianFont,
          latinFont,
          fontSize: 9,
          align: pw.TextAlign.center,
        ),
      ),
    );
  }

  pw.Widget _buildFolder(
    _PdfFolder folder,
    pw.Font persianFont,
    pw.Font latinFont,
  ) {
    final children = <pw.Widget>[
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 12, bottom: 7),
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: const pw.BoxDecoration(
          color: PdfColors.grey200,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
        ),
        child: pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: _buildText(
            'پوشه: ${folder.name}',
            persianFont,
            latinFont,
            fontSize: 16,
            bold: true,
            align: pw.TextAlign.right,
          ),
        ),
      ),
    ];

    for (final table in folder.tables) {
      children.add(_buildTable(table, persianFont, latinFont));
    }
    for (final child in folder.children) {
      children.add(_buildFolder(child, persianFont, latinFont));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: children,
    );
  }

  pw.Widget _buildTable(
    _PdfTable table,
    pw.Font persianFont,
    pw.Font latinFont,
  ) {
    final heading = pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10, bottom: 7),
      child: pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: _buildText(
          'جدول: ${table.name}',
          persianFont,
          latinFont,
          fontSize: 16,
          bold: true,
          align: pw.TextAlign.right,
        ),
      ),
    );

    if (table.columns.isEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          heading,
          _buildMessage(
            'این جدول فیلدی ندارد.',
            persianFont,
            latinFont,
          ),
        ],
      );
    }

    if (table.rows.isEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          heading,
          _buildMessage(
            'این جدول رکوردی ندارد.',
            persianFont,
            latinFont,
          ),
        ],
      );
    }

    final header = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      children: <pw.Widget>[
        _tableCell('#', persianFont, latinFont, bold: true),
        ...table.columns.map(
          (column) => _tableCell(
            column,
            persianFont,
            latinFont,
            bold: true,
          ),
        ),
      ],
    );

    final rows = <pw.TableRow>[header];
    for (var index = 0; index < table.rows.length; index++) {
      final row = table.rows[index];
      rows.add(
        pw.TableRow(
          children: <pw.Widget>[
            _tableCell('${index + 1}', persianFont, latinFont),
            ...table.columns.map(
              (column) => _tableCell(
                row.values[column] ?? '—',
                persianFont,
                latinFont,
              ),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: <pw.Widget>[
        heading,
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Table(
            border: pw.TableBorder.all(
              color: PdfColors.grey500,
              width: 0.5,
            ),
            defaultVerticalAlignment:
                pw.TableCellVerticalAlignment.middle,
            children: rows,
          ),
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }

  pw.Widget _tableCell(
    String value,
    pw.Font persianFont,
    pw.Font latinFont, {
    bool bold = false,
  }) {
    final rtl = _containsRtl(value);
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Directionality(
        textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        child: _buildText(
          value,
          persianFont,
          latinFont,
          fontSize: bold ? 9 : 8,
          bold: bold,
          align: rtl ? pw.TextAlign.right : pw.TextAlign.left,
        ),
      ),
    );
  }

  pw.Widget _buildMessage(
    String message,
    pw.Font persianFont,
    pw.Font latinFont,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 10),
      child: pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: _buildText(
          message,
          persianFont,
          latinFont,
          fontSize: 10,
          align: pw.TextAlign.right,
        ),
      ),
    );
  }

  pw.Text _buildText(
    String value,
    pw.Font persianFont,
    pw.Font latinFont, {
    double fontSize = 14,
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    final rtl = _containsRtl(value);
    return pw.Text(
      value,
      textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      textAlign: align,
      style: pw.TextStyle(
        font: rtl ? persianFont : latinFont,
        fontFallback: <pw.Font>[rtl ? latinFont : persianFont],
        fontSize: fontSize,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    );
  }

  bool _containsRtl(String value) => RegExp(
        r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]',
      ).hasMatch(value);

  String _sanitizeFileName(String name) {
    final sanitized = name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .trim();
    return sanitized.isEmpty ? 'Pass-Managers' : sanitized;
  }
}

class _PdfDocumentModel {
  const _PdfDocumentModel({
    required this.title,
    required this.folders,
    required this.rootTables,
  });

  final String title;
  final List<_PdfFolder> folders;
  final List<_PdfTable> rootTables;

  factory _PdfDocumentModel.fromRoot(Map<String, dynamic> root) {
    final folders = <_PdfFolder>[];
    final rootTables = <_PdfTable>[];
    final children = root['children'];

    if (children is List) {
      for (final child in children) {
        if (child is! Map) continue;
        final map = Map<String, dynamic>.from(child);
        final type = map['type']?.toString();
        if (type == 'folder') {
          folders.add(_PdfFolder.fromMap(map));
        } else if (type == 'table') {
          rootTables.add(_PdfTable.fromMap(map));
        }
      }
    }

    return _PdfDocumentModel(
      title: root['name']?.toString() ?? 'Pass Managers',
      folders: folders,
      rootTables: rootTables,
    );
  }
}

class _PdfFolder {
  const _PdfFolder({
    required this.name,
    required this.tables,
    required this.children,
  });

  final String name;
  final List<_PdfTable> tables;
  final List<_PdfFolder> children;

  factory _PdfFolder.fromMap(Map<String, dynamic> map) {
    final tables = <_PdfTable>[];
    final children = <_PdfFolder>[];
    final rawChildren = map['children'];

    if (rawChildren is List) {
      for (final child in rawChildren) {
        if (child is! Map) continue;
        final childMap = Map<String, dynamic>.from(child);
        switch (childMap['type']?.toString()) {
          case 'table':
            tables.add(_PdfTable.fromMap(childMap));
          case 'folder':
            children.add(_PdfFolder.fromMap(childMap));
        }
      }
    }

    return _PdfFolder(
      name: map['name']?.toString() ?? '',
      tables: tables,
      children: children,
    );
  }
}

class _PdfTable {
  const _PdfTable({
    required this.name,
    required this.columns,
    required this.rows,
  });

  final String name;
  final List<String> columns;
  final List<_PdfRow> rows;

  factory _PdfTable.fromMap(Map<String, dynamic> map) {
    final rawRows = map['rows'];
    final positions = <String, int>{};
    final parsedRows = <_PdfRow>[];

    if (rawRows is List) {
      for (final rawRow in rawRows) {
        if (rawRow is! Map) continue;
        final fields = rawRow['fields'];
        if (fields is List) {
          for (final rawField in fields) {
            if (rawField is! Map) continue;
            final name = rawField['name']?.toString() ?? '';
            if (name.isEmpty) continue;
            final rawPosition = rawField['position'];
            final position = rawPosition is int ? rawPosition : 999999;
            final previous = positions[name];
            if (previous == null || position < previous) {
              positions[name] = position;
            }
          }
        }

        final values = <String, String>{};
        final rawValues = rawRow['values'];
        if (rawValues is Map) {
          rawValues.forEach((key, value) {
            values[key.toString()] = value?.toString() ?? '';
          });
        }
        parsedRows.add(_PdfRow(values));
      }
    }

    final columns = positions.keys.toList()
      ..sort((a, b) {
        final compare = positions[a]!.compareTo(positions[b]!);
        return compare == 0 ? a.compareTo(b) : compare;
      });

    return _PdfTable(
      name: map['name']?.toString() ?? '',
      columns: columns,
      rows: parsedRows,
    );
  }
}

class _PdfRow {
  const _PdfRow(this.values);

  final Map<String, String> values;
}
