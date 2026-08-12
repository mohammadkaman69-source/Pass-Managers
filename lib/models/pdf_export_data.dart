class PdfExportNode {
  final int id;
  final String name;
  final String type;

  final List<PdfExportNode> children;

  final List<PdfExportRow> rows;

  PdfExportNode({
    required this.id,
    required this.name,
    required this.type,
    this.children = const [],
    this.rows = const [],
  });

  bool get isFolder => type == 'folder';

  bool get isTable => type == 'table';
}

class PdfExportRow {
  final int id;
  final List<PdfExportField> fields;

  PdfExportRow({
    required this.id,
    required this.fields,
  });
}

class PdfExportField {
  final int id;
  final String name;
  final int position;
  final String value;

  PdfExportField({
    required this.id,
    required this.name,
    required this.position,
    required this.value,
  });
}
