import 'table_column_definition.dart';
import 'table_row_data.dart';

enum TreeItemType {
  folder,
  table,
}

class TreeItem {
  String name;

  final TreeItemType type;

  final List<TreeItem> children;

  final List<TableColumnDefinition> columns;

  final List<TableRowData> rows;

  TreeItem.folder(
    this.name,
  )   : type = TreeItemType.folder,
        children = [],
        columns = [],
        rows = [];

  TreeItem.table(
    this.name,
  )   : type = TreeItemType.table,
        children = [],
        columns = [
          TableColumnDefinition('Name'),
          TableColumnDefinition('IP'),
          TableColumnDefinition('Username'),
          TableColumnDefinition('Password'),
          TableColumnDefinition('Version'),
          TableColumnDefinition('Description'),
        ],
        rows = [];

  TreeItem copy() {
    if (type == TreeItemType.folder) {
      final copied = TreeItem.folder(name);

      copied.children.addAll(
        children.map(
          (child) => child.copy(),
        ),
      );

      return copied;
    }

    final copied = TreeItem.table(name);

    copied.columns
      ..clear()
      ..addAll(
        columns.map(
          (column) => column.copy(),
        ),
      );

    copied.rows
      ..clear()
      ..addAll(
        rows.map(
          (row) => row.copy(),
        ),
      );

    return copied;
  }
}
