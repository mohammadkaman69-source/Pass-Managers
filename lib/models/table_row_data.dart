import 'table_column_definition.dart';

class TableRowData {
  final List<TableColumnDefinition> columns;

  final Map<int, String> values;

  TableRowData({
    required List<TableColumnDefinition> columns,
    Map<int, String>? values,
  })  : columns = columns
            .map(
              (column) => column.copy(),
            )
            .toList(),
        values = values != null
            ? Map<int, String>.from(values)
            : {
                for (final column in columns)
                  if (column.fieldId != null) column.fieldId!: '',
              };

  TableRowData copy() {
    return TableRowData(
      columns: columns,
      values: values,
    );
  }
}
