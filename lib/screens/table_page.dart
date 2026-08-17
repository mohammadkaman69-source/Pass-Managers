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
  bool _isLoading = true;
  final Map<TableRowData, int> _rowIds = {};

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
      final rowRecords = await _repository.getRows(widget.tableId);
      final loadedRows = <TableRowData>[];
      final loadedIds = <TableRowData, int>{};

      for (final rowRecord in rowRecords) {
        final rowId = rowRecord['id'] as int;
        final fieldRecords = await _repository.getFields(rowId);
        final columns = <TableColumnDefinition>[];
        final values = <String, String>{};

        for (final fieldRecord in fieldRecords) {
          final fieldId = fieldRecord['id'] as int;
          final name = fieldRecord['name'] as String;
          final valueRecords = await _repository.getValues(fieldId);
          var value = '';
          if (valueRecords.isNotEmpty) {
            value = valueRecords.first['value'] as String;
          }
          columns.add(TableColumnDefinition(name));
          values[name] = value;
        }

        if (columns.isEmpty) {
          columns.addAll(widget.table.columns.map((column) => column.copy()));
          for (final column in columns) {
            values[column.name] = '';
          }
        }

        final row = TableRowData(columns: columns, values: values);
        loadedRows.add(row);
        loadedIds[row] = rowId;
      }

      if (!mounted) return;
      setState(() {
        widget.table.rows
          ..clear()
          ..addAll(loadedRows);
        _rowIds
          ..clear()
          ..addAll(loadedIds);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Failed to load table: $error');
    }
  }

  Future<void> addRow() async {
    try {
      final rowId = await _repository.createRow(tableId: widget.tableId);
      final row = TableRowData(
        columns: widget.table.columns.map((column) => column.copy()).toList(),
      );

      for (var i = 0; i < row.columns.length; i++) {
        final column = row.columns[i];
        await _repository.createField(
          rowId: rowId,
          name: column.name,
          position: i,
          value: row.values[column.name] ?? '',
        );
      }

      if (!mounted) return;
      setState(() {
        widget.table.rows.add(row);
        _rowIds[row] = rowId;
      });
    } catch (error) {
      _showError('Failed to add record: $error');
    }
  }

  Future<void> editRow(TableRowData row) async {
    final controllers = <String, TextEditingController>{};
    final obscureStates = <String, bool>{};

    for (final column in row.columns) {
      controllers[column.name] = TextEditingController(
        text: row.values[column.name] ?? '',
      );
      obscureStates[column.name] = column.name.toLowerCase().contains('password');
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Record'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    children: row.columns.map((column) {
                      final isPassword = column.name.toLowerCase().contains('password');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: TextField(
                          controller: controllers[column.name],
                          obscureText: isPassword && (obscureStates[column.name] ?? true),
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            labelText: column.name,
                            suffixIcon: isPassword
                                ? IconButton(
                                    onPressed: () {
                                      setDialogState(() {
                                        obscureStates[column.name] =
                                            !(obscureStates[column.name] ?? true);
                                      });
                                    },
                                    icon: Icon(
                                      (obscureStates[column.name] ?? true)
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
            );
          },
        );
      },
    );

    for (final controller in controllers.values) {
      controller.dispose();
    }
    if (result != true) return;

    try {
      await _saveRow(row);
      if (mounted) setState(() {});
    } catch (error) {
      _showError('Failed to save record: $error');
    }
  }

  Future<void> _saveRow(TableRowData row) async {
    final rowId = _rowIds[row];
    if (rowId == null) throw StateError('Row ID was not found.');

    final fieldRecords = await _repository.getFields(rowId);
    for (final fieldRecord in fieldRecords) {
      final fieldId = fieldRecord['id'] as int;
      final fieldName = fieldRecord['name'] as String;
      await _repository.updateFieldValue(
        fieldId: fieldId,
        value: row.values[fieldName] ?? '',
      );
    }
  }

  Future<int?> _fieldIdForColumn(
    TableRowData row,
    TableColumnDefinition column,
  ) async {
    final rowId = _rowIds[row];
    if (rowId == null) return null;

    final fieldRecords = await _repository.getFields(rowId);
    final matching = fieldRecords.where(
      (field) => field['name'] as String == column.name,
    );

    if (matching.length != 1) return null;
    return matching.first['id'] as int;
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
            hintText: 'Example: Volume',
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
      await _repository.createField(
        rowId: rowId,
        name: name,
        position: row.columns.length,
        value: '',
      );
      if (!mounted) return;
      setState(() {
        row.columns.add(TableColumnDefinition(name));
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
    if (row.columns.any((item) => item != column && item.name.toLowerCase() == newName.toLowerCase())) {
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
        final columnName = column.name;
        row.columns.remove(column);
        row.values.remove(columnName);
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
    if (oldIndex == -1 || newIndex < 0 || newIndex >= columns.length || oldIndex == newIndex) {
      return;
    }

    final rowId = _rowIds[row];
    if (rowId == null) {
      _showError('Row ID was not found.');
      return;
    }

    try {
      final fieldRecords = await _repository.getFields(rowId);
      if (fieldRecords.length != columns.length) {
        throw StateError('Database fields and UI fields are out of sync.');
      }

      final fieldByName = <String, int>{};
      for (final field in fieldRecords) {
        final name = field['name'] as String;
        final id = field['id'] as int;
        if (fieldByName.containsKey(name)) {
          throw StateError('Duplicate field names detected in database.');
        }
        fieldByName[name] = id;
      }

      final fieldIds = <int>[];
      for (final uiColumn in columns) {
        final id = fieldByName[uiColumn.name];
        if (id == null) throw StateError('Field ID was not found.');
        fieldIds.add(id);
      }

      final movedId = fieldIds.removeAt(oldIndex);
      fieldIds.insert(newIndex, movedId);
      await _repository.updateFieldPositions(fieldIds);

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
    final name = await _askTableName();
    if (name == null || name.isEmpty) return;

    try {
      await _repository.renameItem(id: widget.tableId, name: name);
      if (!mounted) return;
      setState(() => widget.table.name = name);
    } catch (error) {
      _showError('Failed to rename table: $error');
    }
  }

  Future<String?> _askTableName() async {
    final controller = TextEditingController(text: widget.table.name);
    final result = await showDialog<String>(
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
    return result;
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
