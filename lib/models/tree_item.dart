import 'table_column_definition.dart';
import 'table_row_data.dart';

enum TreeItemType { folder, table }

class TreeItem {
  int? id;
  int? parentId;
  String name;
  final TreeItemType type;
  final List<TreeItem> children;
  final List<TableColumnDefinition> columns;
  final List<TableRowData> rows;

  TreeItem.folder(this.name, {this.id, this.parentId})
      : type = TreeItemType.folder,
        children = [],
        columns = [],
        rows = [];

  TreeItem.table(this.name, {this.id, this.parentId})
      : type = TreeItemType.table,
        children = [],
        columns = [],
        rows = [];

  TreeItem copy() {
    if (type == TreeItemType.folder) {
      final copied = TreeItem.folder(name, id: id, parentId: parentId);
      copied.children.addAll(children.map((child) => child.copy()));
      return copied;
    }

    final copied = TreeItem.table(name, id: id, parentId: parentId);
    copied.columns.addAll(columns.map((column) => column.copy()));
    copied.rows.addAll(rows.map((row) => row.copy()));
    return copied;
  }
}
