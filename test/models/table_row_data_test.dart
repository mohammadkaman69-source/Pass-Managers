import 'package:flutter_test/flutter_test.dart';
import 'package:pass_managers/models/table_column_definition.dart';
import 'package:pass_managers/models/table_row_data.dart';

void main() {
  test('TableRowData preserves independent columns and values', () {
    final columns = [
      TableColumnDefinition('Username'),
      TableColumnDefinition('Password'),
    ];

    final row = TableRowData(
      columns: columns,
      values: const {
        'Username': 'alice',
        'Password': 'secret',
      },
    );

    columns[0].name = 'Changed outside row';

    expect(row.columns[0].name, 'Username');
    expect(row.values['Username'], 'alice');
    expect(row.values['Password'], 'secret');
  });
}
