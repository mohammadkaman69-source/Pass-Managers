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

  // Template اصلی Table
  final List<TableColumnDefinition> columns;

  // Recordهای Table
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
          TableColumnDefinition("Name"),
          TableColumnDefinition("IP"),
          TableColumnDefinition("Username"),
          TableColumnDefinition("Password"),
          TableColumnDefinition("Version"),
          TableColumnDefinition("Description"),
        ],
        rows = [];
}
