import 'package:flutter/material.dart';

import '../models/table_column_definition.dart';
import '../models/table_row_data.dart';
import '../models/tree_item.dart';
import '../repositories/tree_repository.dart';

class TablePage extends StatefulWidget {
  final TreeItem table;
  final int tableId;
  final VoidCallback? onDelete;

  const TablePage({
    super.key,
    required this.table,
    required this.tableId,
    this.onDelete,
  });

  @override
  State<TablePage> createState() => _TablePageState();
}

class _TablePageState extends State<TablePage> {
  final TreeRepository _repository = TreeRepository();
  final Map<TableRowData, int> _rowIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRows();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadRows() async {
    try {
      final records = await _repository.getRows(widget.tableId);
      final rows = <TableRowData>[];
      final ids = <TableRowData, int>{};

      for (final record in records) {
        final rowId = record['id'] as int;
        final fields = await _repository.getFields(rowId);
        final columns = <TableColumnDefinition>[];
        final values = <String, String>{};

        for (final field in fields) {
          final fieldId = field['id'] as int;
          final name = field['name'] as String;
          final valueRecords = await _repository.getValues(fieldId);
          final value = valueRecords.isEmpty
              ? ''
              : valueRecords.first['value'] as String;
          columns.add(
            TableColumnDefinition(
              name,
              fieldId: fieldId,
            ),
          );
          values[name] = value;
        }

        final row = TableRowData(columns: columns, values: values);
        rows.add(row);
        ids[row] = rowId;
      }

      if (!mounted) return;
      setState(() {
        widget.table.rows
          ..clear()
          ..addAll(rows);
        _rowIds
          ..clear()
          ..addAll(ids);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Failed to load table: $error');
    }
  }

  Future<Map<String, int>?> _askRowAndColumnCounts() async {
    final rowsController = TextEditingController(text: '1');
    final columnsController = TextEditingController();

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Record'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: rowsController,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number of rows',
                hintText: 'Example: 3',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: columnsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number of columns',
                hintText: 'Example: 5',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final rowCount = int.tryParse(rowsController.text.trim());
              final columnCount = int.tryParse(columnsController.text.trim());
              if (rowCount != null &&
                  rowCount > 0 &&
                  columnCount != null &&
                  columnCount > 0) {
                Navigator.pop(dialogContext, {
                  'rows': rowCount,
                  'columns': columnCount,
                });
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    rowsController.dispose();
    columnsController.dispose();
    return result;
  }

  Future<List<String>?> _askColumnNames(int count) async {
    final names = <String>[];

    for (var i = 0; i < count; i++) {
      final controller = TextEditingController();
      final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Column ${i + 1} of $count'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Header name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                Navigator.pop(dialogContext, value.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) {
                  Navigator.pop(dialogContext, value);
                }
              },
              child: const Text('Next'),
            ),
          ],
        ),
      );
      controller.dispose();

      if (name == null || name.trim().isEmpty) return null;
      final normalized = name.trim();
      if (names.any((item) => item.toLowerCase() == normalized.toLowerCase())) {
        _showError('Column names must be unique.');
        return null;
      }
      names.add(normalized);
    }

    return names;
  }

  Future<void> addRow() async {
    final counts = await _askRowAndColumnCounts();
    if (counts == null) return;

    final rowCount = counts['rows']!;
    final columnCount = counts['columns']!;
    final names = await _askColumnNames(columnCount);
    if (names == null || names.isEmpty) return;

    try {
      final createdRows = <TableRowData>[];
      final createdIds = <TableRowData, int>{};

      for (var rowIndex = 0; rowIndex < rowCount; rowIndex++) {
        final rowId = await _repository.createRow(tableId: widget.tableId);
        final columns = <TableColumnDefinition>[];
        final row = TableRowData(columns: columns);

        for (var i = 0; i < names.length; i++) {
          final fieldId = await _repository.createField(
            rowId: rowId,
            name: names[i],
            position: i,
            value: '',
          );
          columns.add(
            TableColumnDefinition(
              names[i],
              fieldId: fieldId,
            ),
          );
        }

        createdRows.add(row);
        createdIds[row] = rowId;
      }

      if (!mounted) return;
      setState(() {
        widget.table.rows.addAll(createdRows);
        _rowIds.addAll(createdIds);
      });
    } catch (error) {
      _showError('Failed to add records: $error');
    }
  }

  Future<int?> _fieldIdForColumn(
    TableRowData row,
    TableColumnDefinition column,
  ) async {
    if (_rowIds[row] == null) return null;
    return column.fieldId;
  }

  Future<void> editRow(TableRowData row) async {
    final controllers = <String, TextEditingController>{};
    final obscure = <String, bool>{};

    for (final column in row.columns) {
      controllers[column.name] = TextEditingController(
        text: row.values[column.name] ?? '',
      );
      obscure[column.name] = column.name.toLowerCase().contains('password');
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Record'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                children: row.columns.map((column) {
                  final isPassword = column.name.toLowerCase().contains('password');
                  final isObscured = obscure[column.name] ?? true;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: TextField(
                      controller: controllers[column.name],
                      obscureText: isPassword && isObscured,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: column.name,
                        suffixIcon: isPassword
                            ? IconButton(
                                onPressed: () {
                                  setDialogState(() {
                                    obscure[column.name] = !isObscured;
                                  });
                                },
                                icon: Icon(
                                  isObscured
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                for (final column in row.columns) {
                  row.values[column.name] = controllers[column.name]!.text;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    for (final controller in controllers.values) {
      controller.dispose();
    }
    if (result != true) return;

    try {
      final rowId = _rowIds[row];
      if (rowId == null) throw StateError('Row ID was not found.');
      final fields = await _repository.getFields(rowId);
      for (final field in fields) {
        final fieldId = field['id'] as int;
        final fieldName = field['name'] as String;
        await _repository.updateFieldValue(
          fieldId: fieldId,
          value: row.values[fieldName] ?? '',
        );
      }
      if (mounted) setState(() {});
    } catch (error) {
      _showError('Failed to save record: $error');
    }
  }

  Future<void> deleteRow(int index) async {
    if (index < 0 || index >= widget.table.rows.length) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text('Are you sure you want to delete this record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final row = widget.table.rows[index];
    final rowId = _rowIds[row];
    if (rowId == null) {
      _showError('Row ID was not found.');
      return;
    }

    try {
      await _repository.deleteRow(rowId);
      if (!mounted) return;
      setState(() {
        widget.table.rows.removeAt(index);
        _rowIds.remove(row);
      });
    } catch (error) {
      _showError('Failed to delete record: $error');
    }
  }

  Future<void> addColumn(TableRowData row) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Field'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Field name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Add Field'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;

    if (row.columns.any((column) => column.name.toLowerCase() == name.toLowerCase())) {
      _showError('A field with this name already exists in this record.');
      return;
    }

    final rowId = _rowIds[row];
    if (rowId == null) {
      _showError('Row ID was not found.');
      return;
    }

    try {
      final fieldId = await _repository.createField(
        rowId: rowId,
        name: name,
        position: row.columns.length,
        value: '',
      );
      if (!mounted) return;
      setState(() {
        row.columns.add(
          TableColumnDefinition(
            name,
            fieldId: fieldId,
          ),
        );
        row.values[name] = '';
      });
    } catch (error) {
      _showError('Failed to add field: $error');
    }
  }

  Future<void> renameColumn(
    TableRowData row,
    TableColumnDefinition column,
  ) async {
    final oldName = column.name;
    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Field'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Field name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName.isEmpty || newName == oldName) return;

    if (row.columns.any(
      (item) => item != column && item.name.toLowerCase() == newName.toLowerCase(),
    )) {
      _showError('A field with this name already exists in this record.');
      return;
    }

    try {
      final fieldId = await _fieldIdForColumn(row, column);
      if (fieldId == null) throw StateError('Field ID was not found.');
      final value = row.values[oldName] ?? '';
      await _repository.renameField(fieldId: fieldId, name: newName);
      await _repository.updateFieldValue(fieldId: fieldId, value: value);
      if (!mounted) return;
      setState(() {
        row.values.remove(oldName);
        row.values[newName] = value;
        column.name = newName;
      });
    } catch (error) {
      _showError('Failed to rename field: $error');
    }
  }

  Future<void> deleteColumn(
    TableRowData row,
    TableColumnDefinition column,
  ) async {
    if (row.columns.length <= 1) {
      _showError('At least one field must remain in this record.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Field'),
        content: Text('Delete field "${column.name}" from this record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final fieldId = await _fieldIdForColumn(row, column);
      if (fieldId == null) throw StateError('Field ID was not found.');
      await _repository.deleteField(fieldId);
      if (!mounted) return;
      setState(() {
        final name = column.name;
        row.columns.remove(column);
        row.values.remove(name);
      });
    } catch (error) {
      _showError('Failed to delete field: $error');
    }
  }

  Future<void> moveColumn(
    TableRowData row,
    TableColumnDefinition column,
    int newIndex,
  ) async {
    final columns = row.columns;
    final oldIndex = columns.indexOf(column);
    if (oldIndex < 0 || newIndex < 0 || newIndex >= columns.length || oldIndex == newIndex) {
      return;
    }

    if (columns.any((item) => item.fieldId == null)) {
      _showError('Field ID is missing for one or more fields.');
      return;
    }

    try {
      final ids = columns
          .map((item) => item.fieldId!)
          .toList();

      final moved = ids.removeAt(oldIndex);
      ids.insert(newIndex, moved);
      await _repository.updateFieldPositions(ids);

      if (!mounted) return;
      setState(() {
        columns.removeAt(oldIndex);
        columns.insert(newIndex, column);
      });
    } catch (error) {
      _showError('Failed to move field: $error');
    }
  }

  void showColumnMenu(TableRowData row, TableColumnDefinition column) {
    final index = row.columns.indexOf(column);
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename Field'),
              onTap: () {
                Navigator.pop(sheetContext);
                renameColumn(row, column);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward),
              enabled: index > 0,
              title: const Text('Move Up'),
              onTap: index > 0
                  ? () {
                      Navigator.pop(sheetContext);
                      moveColumn(row, column, index - 1);
                    }
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward),
              enabled: index < row.columns.length - 1,
              title: const Text('Move Down'),
              onTap: index < row.columns.length - 1
                  ? () {
                      Navigator.pop(sheetContext);
                      moveColumn(row, column, index + 1);
                    }
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete Field'),
              onTap: () {
                Navigator.pop(sheetContext);
                deleteColumn(row, column);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> renameTable() async {
    final controller = TextEditingController(text: widget.table.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Table'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Table name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;

    try {
      await _repository.renameItem(id: widget.tableId, name: name);
      if (!mounted) return;
      setState(() => widget.table.name = name);
    } catch (error) {
      _showError('Failed to rename table: $error');
    }
  }

  Future<void> deleteTable() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Table'),
        content: Text('Delete "${widget.table.name}" and all its records?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _repository.deleteItem(widget.tableId);
      if (!mounted) return;
      widget.onDelete?.call();
      Navigator.pop(context);
    } catch (error) {
      _showError('Failed to delete table: $error');
    }
  }

  Widget buildRowCard(TableRowData row, int rowIndex) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Column(
          children: [
            if (row.columns.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('This record has no fields.'),
              )
            else
              ...row.columns.map((column) {
                final value = row.values[column.name] ?? '';
                final isPassword = column.name.toLowerCase().contains('password');
                final displayValue = isPassword && value.isNotEmpty
                    ? '••••••••'
                    : value.isEmpty
                        ? '—'
                        : value;

                return InkWell(
                  onTap: () => editRow(row),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: Text(
                            column.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 6,
                          child: Text(displayValue, textAlign: TextAlign.end),
                        ),
                        IconButton(
                          onPressed: () => showColumnMenu(row, column),
                          icon: const Icon(Icons.more_vert, size: 20),
                          tooltip: 'Field options',
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                alignment: WrapAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => editRow(row),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                  TextButton.icon(
                    onPressed: () => deleteRow(rowIndex),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                  TextButton.icon(
                    onPressed: () => addColumn(row),
                    icon: const Icon(Icons.add_box_outlined),
                    label: const Text('Add Field'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.table.name),
        actions: [
          IconButton(
            onPressed: renameTable,
            icon: const Icon(Icons.edit),
            tooltip: 'Rename Table',
          ),
          if (widget.onDelete != null)
            IconButton(
              onPressed: deleteTable,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete Table',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : widget.table.rows.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.table_chart_outlined, size: 80),
                        const SizedBox(height: 20),
                        const Text('No records yet', style: TextStyle(fontSize: 18)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: addRow,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Record'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  itemCount: widget.table.rows.length,
                  itemBuilder: (context, index) =>
                      buildRowCard(widget.table.rows[index], index),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addRow,
        icon: const Icon(Icons.add),
        label: const Text('Add Record'),
      ),
    );
  }
}
