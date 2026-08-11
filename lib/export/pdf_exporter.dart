import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'tree_export_model.dart';

class PdfExporter {
PdfExporter();

Future<Uint8List> generate({
required TreeExportDocument document,
String title = 'Pass Managers',
}) async {
final pdf = pw.Document();

pdf.addPage(
  pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    header: (context) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(
          bottom: 16,
        ),
        child: pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );
    },
    footer: (context) {
      return pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(
            fontSize: 9,
          ),
        ),
      );
    },
    build: (context) {
      final widgets = <pw.Widget>[];

      for (final node in document.roots) {
        widgets.add(
          _buildNode(
            node,
            level: 0,
          ),
        );
      }

      if (widgets.isEmpty) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(
              top: 40,
            ),
            child: pw.Text(
              'No data available.',
              style: const pw.TextStyle(
                fontSize: 12,
              ),
            ),
          ),
        );
      }

      return widgets;
    },
  ),
);

return pdf.save();

}

pw.Widget _buildNode(
TreeExportNode node, {
required int level,
}) {
final children =
<pw.Widget>[];

children.add(
  pw.Padding(
    padding: pw.EdgeInsets.only(
      left: level * 18,
      bottom: 8,
      top: level == 0 ? 4 : 8,
    ),
    child: pw.Text(
      node.name,
      style: pw.TextStyle(
        fontSize:
            node.isFolder ? 14 : 13,
        fontWeight:
            pw.FontWeight.bold,
      ),
    ),
  ),
);

if (node.isTable) {
  children.add(
    _buildTable(node),
  );
}

for (final child in node.children) {
  children.add(
    _buildNode(
      child,
      level: level + 1,
    ),
  );
}

return pw.Column(
  crossAxisAlignment:
      pw.CrossAxisAlignment.start,
  children: children,
);

}

pw.Widget _buildTable(
TreeExportNode table,
) {
if (table.rows.isEmpty) {
return pw.Padding(
padding: const pw.EdgeInsets.only(
left: 12,
bottom: 10,
),
child: pw.Text(
'No records.',
style: const pw.TextStyle(
fontSize: 10,
),
),
);
}

final fieldNames =
    <String>[];

for (final row in table.rows) {
  for (final field in row.fields) {
    if (!fieldNames.contains(
      field.name,
    )) {
      fieldNames.add(
        field.name,
      );
    }
  }
}

for (final row in table.rows) {
  for (final name in row.values.keys) {
    if (!fieldNames.contains(name)) {
      fieldNames.add(name);
    }
  }
}

if (fieldNames.isEmpty) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(
      left: 12,
      bottom: 10,
    ),
    child: pw.Text(
      'No fields.',
      style: const pw.TextStyle(
        fontSize: 10,
      ),
    ),
  );
}

final headers =
    <pw.Widget>[
  pw.Text(
    '#',
    style: pw.TextStyle(
      fontWeight:
          pw.FontWeight.bold,
      fontSize: 9,
    ),
  ),
  ...fieldNames.map(
    (name) => pw.Text(
      name,
      style: pw.TextStyle(
        fontWeight:
            pw.FontWeight.bold,
        fontSize: 9,
      ),
    ),
  ),
];

final dataRows =
    <List<pw.Widget>>[];

for (var i = 0;
    i < table.rows.length;
    i++) {
  final row =
      table.rows[i];

  dataRows.add([
    pw.Text(
      '${i + 1}',
      style: const pw.TextStyle(
        fontSize: 8,
      ),
    ),
    ...fieldNames.map(
      (fieldName) {
        final value =
            row.values[fieldName] ??
                '';

        return pw.Text(
          value.isEmpty
              ? '—'
              : value,
          style:
              const pw.TextStyle(
            fontSize: 8,
          ),
        );
      },
    ),
  ]);
}

return pw.Padding(
  padding: const pw.EdgeInsets.only(
    left: 12,
    right: 4,
    bottom: 16,
  ),
  child: pw.TableHelper.fromTextArray(
    headers: headers,
    data: dataRows,
    border:
        pw.TableBorder.all(
      color: PdfColors.grey500,
      width: 0.5,
    ),
    headerStyle:
        pw.TextStyle(
      fontSize: 9,
      fontWeight:
          pw.FontWeight.bold,
    ),
    cellStyle:
        const pw.TextStyle(
      fontSize: 8,
    ),
    cellPadding:
        const pw.EdgeInsets.all(
      5,
    ),
    headerDecoration:
        const pw.BoxDecoration(
      color: PdfColors.grey300,
    ),
    columnWidths: {
      0: const pw.FixedColumnWidth(
        24,
      ),
    },
  ),
);

}
}
