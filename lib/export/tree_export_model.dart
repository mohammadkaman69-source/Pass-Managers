import 'dart:convert';

class TreeExportDocument {
final List<TreeExportNode> roots;

const TreeExportDocument({
required this.roots,
});

factory TreeExportDocument.fromRepositoryData(
List<Map<String, dynamic>> data,
) {
return TreeExportDocument(
roots: data
.map(
(node) => TreeExportNode.fromMap(node),
)
.toList(),
);
}

Map<String, dynamic> toMap() {
return {
'version': 1,
'roots': roots
.map(
(node) => node.toMap(),
)
.toList(),
};
}

String toJson() {
return jsonEncode(toMap());
}
}

class TreeExportNode {
final int id;
final String name;
final String type;
final int? createdAt;
final int? updatedAt;

final List<TreeExportNode> children;

final List<TreeExportColumn> columns;
final List<TreeExportRow> rows;

const TreeExportNode({
required this.id,
required this.name,
required this.type,
this.createdAt,
this.updatedAt,
this.children = const [],
this.columns = const [],
this.rows = const [],
});

bool get isFolder => type == 'folder';

bool get isTable => type == 'table';

factory TreeExportNode.fromMap(
Map<String, dynamic> map,
) {
final childrenData =
map['children'];

final columnsData =
    map['columns'];

final rowsData =
    map['rows'];

return TreeExportNode(
  id: map['id'] as int,
  name: map['name'] as String,
  type: map['type'] as String,
  createdAt:
      map['created_at'] as int?,
  updatedAt:
      map['updated_at'] as int?,
  children:
      childrenData is List
          ? childrenData
              .whereType<
                  Map<String, dynamic>>()
              .map(
                TreeExportNode.fromMap,
              )
              .toList()
          : const [],
  columns:
      columnsData is List
          ? columnsData
              .whereType<
                  Map<String, dynamic>>()
              .map(
                TreeExportColumn.fromMap,
              )
              .toList()
          : const [],
  rows:
      rowsData is List
          ? rowsData
              .whereType<
                  Map<String, dynamic>>()
              .map(
                TreeExportRow.fromMap,
              )
              .toList()
          : const [],
);

}

Map<String, dynamic> toMap() {
return {
'id': id,
'name': name,
'type': type,
'created_at': createdAt,
'updated_at': updatedAt,
'children': children
.map(
(child) => child.toMap(),
)
.toList(),
'columns': columns
.map(
(column) => column.toMap(),
)
.toList(),
'rows': rows
.map(
(row) => row.toMap(),
)
.toList(),
};
}
}

class TreeExportColumn {
final int id;
final String name;
final int position;

const TreeExportColumn({
required this.id,
required this.name,
required this.position,
});

factory TreeExportColumn.fromMap(
Map<String, dynamic> map,
) {
return TreeExportColumn(
id: map['id'] as int,
name: map['name'] as String,
position: map['position'] as int,
);
}

Map<String, dynamic> toMap() {
return {
'id': id,
'name': name,
'position': position,
};
}
}

class TreeExportRow {
final int id;
final int? createdAt;
final int? updatedAt;

final List<TreeExportColumn> fields;

final Map<String, String> values;

const TreeExportRow({
required this.id,
this.createdAt,
this.updatedAt,
this.fields = const [],
this.values = const {},
});

factory TreeExportRow.fromMap(
Map<String, dynamic> map,
) {
final fieldsData =
map['fields'];

final valuesData =
    map['values'];

final values =
    <String, String>{};

if (valuesData is Map) {
  for (final entry
      in valuesData.entries) {
    values[
        entry.key.toString()] =
        entry.value?.toString() ?? '';
  }
}

return TreeExportRow(
  id: map['id'] as int,
  createdAt:
      map['created_at'] as int?,
  updatedAt:
      map['updated_at'] as int?,
  fields:
      fieldsData is List
          ? fieldsData
              .whereType<
                  Map<String, dynamic>>()
              .map(
                TreeExportColumn.fromMap,
              )
              .toList()
          : const [],
  values: values,
);

}

Map<String, dynamic> toMap() {
return {
'id': id,
'created_at': createdAt,
'updated_at': updatedAt,
'fields': fields
.map(
(field) => field.toMap(),
)
.toList(),
'values': values,
};
}
}
