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

    final fontData = await rootBundle.load('assets/fonts/BNazanin.ttf');
    final persianFont = pw.Font.ttf(fontData);
    final latinFont = pw.Font.helvetica();

    final content = <pw.Widget>[];

    _buildTreeContent(
      node: root,
      content: content,
      persianFont: persianFont,
      latinFont: latinFont,
      level: 0,
    );

    if (content.isEmpty) {
      content.add(
        _text(
          'محتوایی برای Export وجود ندارد.',
          persianFont: persianFont,
          latinFont: latinFont,
          fontSize: 14,
        ),
      );
    }

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),

        header: (_) {
          final title = root['name']?.toString() ?? 'Pass Managers';

          return pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(bottom: 12),
            child: _text(
              title,
              persianFont: persianFont,
              latinFont: latinFont,
              fontSize: 20,
              bold: true,
            ),
          );
        },

        footer: (context) {
          return pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(top: 10),
            child: _text(
              'صفحه ${context.pageNumber} / ${context.pagesCount}',
              persianFont: persianFont,
              latinFont: latinFont,
              fontSize: 9,
            ),
          );
        },

        build: (_) => content,
      ),
    );

    final savedBytes = Uint8List.fromList(await document.save());

    final safeName = _sanitizeFileName(
      root['name']?.toString() ?? 'Pass-Managers',
    );

    final fileName = '$safeName.pdf';

    if (Platform.isAndroid) {
      final nativeBytes = Uint8List.fromList(savedBytes);

      try {
        final result = await _channel.invokeMethod<String>(
          'savePdf',
          <String, dynamic>{
            'fileName': fileName,
            'bytes': nativeBytes,
          },
        );

        if (result == null || result.trim().isEmpty) {
          return result;
        }

        /*
         * The Android side returns the URI of the saved PDF.
         *
         * We immediately ask Android to open that exact URI with the
         * device's default PDF application.
         *
         * If no PDF application is available, Android simply reports
         * failure and the saved file remains untouched.
         */
        try {
          await _channel.invokeMethod<bool>(
            'openPdf',
            <String, dynamic>{
              'uri': result,
            },
          );
        } catch (_) {
          // Opening is optional.
          // The PDF has already been successfully saved.
        }

        return result;
      } finally {
        nativeBytes.fillRange(0, nativeBytes.length, 0);
        savedBytes.fillRange(0, savedBytes.length, 0);
      }
    }

    /*
     * Desktop:
     *
     * FilePicker owns the save operation.
     * We intentionally do not add printing or another PDF package.
     */
    final pickerBytes = Uint8List.fromList(savedBytes);

    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'ذخیره PDF Pass Managers',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const <String>['pdf'],
        bytes: pickerBytes,
      );

      /*
       * On desktop FilePicker normally returns the actual saved path.
       *
       * We do not attempt to open it here yet because the Android
       * MethodChannel is the reliable cross-platform part of this
       * application's existing architecture.
       */
      return result;
    } finally {
      pickerBytes.fillRange(0, pickerBytes.length, 0);
      savedBytes.fillRange(0, savedBytes.length, 0);
    }
  }

  void _buildTreeContent({
    required Map<String, dynamic> node,
    required List<pw.Widget> content,
    required pw.Font persianFont,
    required pw.Font latinFont,
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
            persianFont: persianFont,
            latinFont: latinFont,
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
              persianFont: persianFont,
              latinFont: latinFont,
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
        persianFont: persianFont,
        latinFont: latinFont,
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
          persianFont: persianFont,
          latinFont: latinFont,
          fontSize: 14,
        ),
      ),
    );
  }

  void _buildTableContent({
    required Map<String, dynamic> node,
    required List<pw.Widget> content,
    required pw.Font persianFont,
    required pw.Font latinFont,
    required int level,
  }) {
    final name = node['name']?.toString() ?? '';
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
        child: _text(
          'جدول: $name',
          persianFont: persianFont,
          latinFont: latinFont,
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
          persianFont,
          latinFont,
          indent + 10,
        ),
      );

      return;
    }

    final fieldPositions = <String, int>{};

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

        final fieldName = rawField['name']?.toString() ?? '';

        if (fieldName.isEmpty) {
          continue;
        }

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
          persianFont,
          latinFont,
          indent + 10,
        ),
      );

      return;
    }

    final columns = fieldPositions.keys.toList()
      ..sort(
        (a, b) {
          final positionCompare =
              fieldPositions[a]!.compareTo(fieldPositions[b]!);

          if (positionCompare != 0) {
            return positionCompare;
          }

          return a.compareTo(b);
        },
      );

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          color: PdfColors.grey300,
        ),
        children: <pw.Widget>[
          _tableCell(
            '#',
            persianFont,
            latinFont,
            bold: true,
          ),
          ...columns.map(
            (column) {
              return _tableCell(
                column,
                persianFont,
                latinFont,
                bold: true,
              );
            },
          ),
        ],
      ),
    ];

    for (var i = 0; i < rows.length; i++) {
      final rawRow = rows[i];

      final values = rawRow is Map ? rawRow['values'] : null;

      tableRows.add(
        pw.TableRow(
          children: <pw.Widget>[
            _tableCell(
              '${i + 1}',
              persianFont,
              latinFont,
            ),
            ...columns.map(
              (column) {
                final value =
                    values is Map && values[column] != null
                        ? values[column].toString()
                        : '';

                return _tableCell(
                  value.isEmpty ? '—' : value,
                  persianFont,
                  latinFont,
                );
              },
            ),
          ],
        ),
      );
    }

    content.add(
      pw.Padding(
        padding: pw.EdgeInsets.only(
          right: indent,
          bottom: 16,
        ),
        child: pw.Table(
          border: pw.TableBorder.all(
            color: PdfColors.grey500,
            width: 0.5,
          ),
          defaultVerticalAlignment:
              pw.TableCellVerticalAlignment.middle,
          children: tableRows,
        ),
      ),
    );
  }

  pw.Widget _tableCell(
    String value,
    pw.Font persianFont,
    pw.Font latinFont, {
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: _text(
        value,
        persianFont: persianFont,
        latinFont: latinFont,
        fontSize: bold ? 9 : 8,
        bold: bold,
      ),
    );
  }

  pw.Widget _message(
    String message,
    pw.Font persianFont,
    pw.Font latinFont,
    double right,
  ) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(
        right: right,
        bottom: 10,
      ),
      child: _text(
        message,
        persianFont: persianFont,
        latinFont: latinFont,
        fontSize: 10,
      ),
    );
  }

  bool _containsRtl(String value) {
    return RegExp(
      r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]',
    ).hasMatch(value);
  }

  bool _containsLtr(String value) {
    return RegExp(
      r'[A-Za-z]',
    ).hasMatch(value);
  }

  bool _containsNumber(String value) {
    return RegExp(
      r'[0-9]',
    ).hasMatch(value);
  }

  /*
   * Protect Latin/number runs inside an RTL sentence.
   *
   * This is intentionally NOT a reverse() operation.
   *
   * LRM (Left-to-Right Mark) tells the PDF BiDi engine that the
   * enclosed Latin/number section must remain LTR.
   *
   * Example:
   *
   *   پوشه: Pass Managers
   *
   * becomes internally:
   *
   *   پوشه: [LRM]Pass Managers[LRM]
   *
   * so "Pass Managers" cannot become "sreganaM ssaP".
   */
  String _prepareBidi(String value) {
    if (value.isEmpty) {
      return value;
    }

    final hasRtl = _containsRtl(value);

    if (!hasRtl) {
      return value;
    }

    final buffer = StringBuffer();

    var i = 0;

    while (i < value.length) {
      final codeUnit = value.codeUnitAt(i);

      final character = String.fromCharCode(codeUnit);

      final isAsciiLetter =
          RegExp(r'[A-Za-z]').hasMatch(character);

      final isDigit =
          RegExp(r'[0-9]').hasMatch(character);

      if (isAsciiLetter || isDigit) {
        final start = i;

        while (i < value.length) {
          final current =
              String.fromCharCode(value.codeUnitAt(i));

          final isLetter =
              RegExp(r'[A-Za-z]').hasMatch(current);

          final isDigitCharacter =
              RegExp(r'[0-9]').hasMatch(current);

          final isLtrPunctuation = RegExp(
            r'''[A-Za-z0-9@._:/\\+\-=%,#?&~*()[\]{}]''',
          ).hasMatch(current);

          if (!isLetter &&
              !isDigitCharacter &&
              !isLtrPunctuation) {
            break;
          }

          i++;
        }

        final run = value.substring(start, i);

        buffer
          ..write('\u200E')
          ..write(run)
          ..write('\u200E');

        continue;
      }

      buffer.write(character);
      i++;
    }

    return buffer.toString();
  }

  pw.Text _text(
    String value, {
    required pw.Font persianFont,
    required pw.Font latinFont,
    double fontSize = 14,
    bool bold = false,
  }) {
    final hasRtl = _containsRtl(value);
    final hasLtr = _containsLtr(value);
    final hasNumber = _containsNumber(value);

    /*
     * Pure LTR:
     *
     * Pass Managers
     * user@example.com
     * https://example.com
     * com.example.pass_managers
     */
    if (!hasRtl) {
      return pw.Text(
        value,
        textDirection: pw.TextDirection.ltr,
        textAlign: pw.TextAlign.left,
        style: pw.TextStyle(
          font: latinFont,
          fontFallback: <pw.Font>[persianFont],
          fontSize: fontSize,
          fontWeight:
              bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      );
    }

    /*
     * RTL or mixed RTL/LTR.
     *
     * Persian remains RTL.
     * Latin and numbers are protected with LRM.
     */
    final prepared = _prepareBidi(value);

    return pw.Text(
      prepared,
      textDirection: pw.TextDirection.rtl,
      textAlign: pw.TextAlign.right,
      style: pw.TextStyle(
        font: persianFont,
        fontFallback: <pw.Font>[latinFont],
        fontSize: fontSize,
        fontWeight:
            bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    );
  }

  String _sanitizeFileName(String name) {
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
