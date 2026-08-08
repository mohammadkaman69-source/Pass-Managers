import 'table_column_definition.dart';

class TableRowData {
  final List<TableColumnDefinition> columns;
  final Map<String, String> values;

  TableRowData({
    required List<TableColumnDefinition> columns,
    Map<String, String>? values,
  })  : columns = columns
            .map(
              (column) => TableColumnDefinition(
                column.name,
              ),
            )
            .toList(),
        values = values != null
            ? Map<String, String>.from(values)
            : {
                for (final column in columns)
                  column.name: '',
              };
}
