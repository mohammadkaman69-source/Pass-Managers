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
    _loadTable();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadTable() async {
    try {
      final columnRecords = await _repository.getColumns(widget.tableId);
      final columns = columnRecords
          .map((column) => TableColumnDefinition(column['name'] as String))
          .toList();

      final rows = <TableRowData>[];
      final ids = <TableRowData, int>{};
      final rowRecords = await _repository.getRows(widget.tableId);

      for (final rowRecord in rowRecords) {
        final rowId = rowRecord['id'] as int;
        await _repository.ensureRowMatchesSchema(rowId);
        final fields = await _repository.getFields(rowId);
        final values = <String, String>{};
        final byName = <String, String>{};

        for (final field in fields) {
          final fieldId = field['id'] as int;
          final name = field['name'] as String;
          final valueRecords = await _repository.getValues(fieldId);
          byName[name.toLowerCase()] =
              valueRecords.isEmpty ? '' : valueRecords.first['value'] as String;
        }

        for (final column in columns) {
          values[column.name] = byName[column.name.toLowerCase()] ?? '';
        }

        final row = TableRowData(columns: columns, values: values);
        rows.add(row);
        ids[row] = rowId;
      }

      if (!mounted) return;
      setState(() {
        widget.table.columns
          ..clear()
          ..addAll(columns.map((column) => column.copy()));
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

  Future<void> addRow() async {
    try {
      final rowId = await _repository.createRow(tableId: widget.tableId);
      final row = TableRowData(columns: widget.table.columns);
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
    final obscure = <String, bool>{};

    for (final column in widget.table.columns) {
      controllers[column.name] = TextEditingController(text: row.values[column.name] ?? '');
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
                children: widget.table.columns.map((column) {
                  final password = column.name.toLowerCase().contains('password');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: TextField(
                      controller: controllers[column.name],
                      obscureText: password && (obscure[column.name] ?? true),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: column.name,
                        suffixIcon: password
                            ? IconButton(
                                onPressed: () => setDialogState(() {
                                  obscure[column.name] = !(obscure[column.name] ?? true);
                                }),
                                icon: Icon((obscure[column.name] ?? true)
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
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
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                for (final column in widget.table.columns) {
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
      await _repository.ensureRowMatchesSchema(rowId);
      final fields = await _repository.getFields(rowId);
      final fieldByName = <String, int>{
        for (final field in fields) (field['name'] as String).toLowerCase(): field['id'] as int,
      };
      for (final column in widget.table.columns) {
        final fieldId = fieldByName[column.name.toLowerCase()];
        if (fieldId != null) {
          await _repository.updateFieldValue(fieldId: fieldId, value: row.values[column.name] ?? '');
        }
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
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    final row = widget.table.rows[index];
    final rowId = _rowIds[row];
    if (rowId == null) return;
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

  Future<void> addColumn() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Field'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Field name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
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

    try {
      await _repository.addColumn(tableId: widget.tableId, name: name);
      if (!mounted) return;
      setState(() {
        widget.table.columns.add(TableColumnDefinition(name));
        for (final row in widget.table.rows) {
          row.columns.add(TableColumnDefinition(name));
          row.values[name] = '';
        }
      });
    } catch (error) {
      _showError('Failed to add field: $error');
    }
  }

  Future<void> renameColumn(TableColumnDefinition column) async {
    final controller = TextEditingController(text: column.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Field'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
            final value = controller.text.trim();
            if (value.isNotEmpty) Navigator.pop(dialogContext, value);
          }, child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName.isEmpty || newName == column.name) return;

    try {
      final columns = await _repository.getColumns(widget.tableId);
      final index = widget.table.columns.indexOf(column);
      if (index < 0 || index >= columns.length) throw StateError('Column was not found.');
      final columnId = columns[index]['id'] as int;
      final oldName = column.name;
      await _repository.renameColumn(tableId: widget.tableId, columnId: columnId, name: newName);
      if (!mounted) return;
      setState(() {
        for (final row in widget.table.rows) {
          final value = row.values.remove(oldName) ?? '';
          row.values[newName] = value;
          final rowColumn = row.columns.firstWhere((item) => item.name == oldName);
          rowColumn.name = newName;
        }
        column.name = newName;
      });
    } catch (error) {
      _showError('Failed to rename field: $error');
    }
  }

  Future<void> deleteColumn(TableColumnDefinition column) async {
    if (widget.table.columns.length <= 1) {
      _showError('At least one field must remain in this table.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Field'),
        content: Text('Delete field "${column.name}" from the entire table?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final columns = await _repository.getColumns(widget.tableId);
      final index = widget.table.columns.indexOf(column);
      if (index < 0 || index >= columns.length) throw StateError('Column was not found.');
      await _repository.deleteColumn(tableId: widget.tableId, columnId: columns[index]['id'] as int);
      if (!mounted) return;
      setState(() {
        widget.table.columns.removeAt(index);
        for (final row in widget.table.rows) {
          row.values.remove(column.name);
          row.columns.removeWhere((item) => item.name == column.name);
        }
      });
    } catch (error) {
      _showError('Failed to delete field: $error');
    }
  }

  Future<void> moveColumn(TableColumnDefinition column, int newIndex) async {
    final oldIndex = widget.table.columns.indexOf(column);
    if (oldIndex < 0 || newIndex < 0 || newIndex >= widget.table.columns.length || oldIndex == newIndex) return;
    try {
      final columns = await _repository.getColumns(widget.tableId);
      await _repository.moveColumn(
        tableId: widget.tableId,
        columnId: columns[oldIndex]['id'] as int,
        newIndex: newIndex,
      );
      if (!mounted) return;
      setState(() {
        widget.table.columns.removeAt(oldIndex);
        widget.table.columns.insert(newIndex, column);
        for (final row in widget.table.rows) {
          final rowColumn = row.columns.removeAt(oldIndex);
          row.columns.insert(newIndex, rowColumn);
        }
      });
    } catch (error) {
      _showError('Failed to move field: $error');
    }
  }

  void showColumnMenu(TableColumnDefinition column) {
    final index = widget.table.columns.indexOf(column);
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.edit), title: const Text('Rename Field'), onTap: () { Navigator.pop(sheetContext); renameColumn(column); }),
            ListTile(leading: const Icon(Icons.arrow_upward), enabled: index > 0, title: const Text('Move Up'), onTap: index > 0 ? () { Navigator.pop(sheetContext); moveColumn(column, index - 1); } : null),
            ListTile(leading: const Icon(Icons.arrow_downward), enabled: index < widget.table.columns.length - 1, title: const Text('Move Down'), onTap: index < widget.table.columns.length - 1 ? () { Navigator.pop(sheetContext); moveColumn(column, index + 1); } : null),
            ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Delete Field'), onTap: () { Navigator.pop(sheetContext); deleteColumn(column); }),
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
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(onPressed: () { final value = controller.text.trim(); if (value.isNotEmpty) Navigator.pop(dialogContext, value); }, child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    try {
      await _repository.renameItem(id: widget.tableId, name: name);
      if (mounted) setState(() => widget.table.name = name);
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
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
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

  Widget buildRowCard(TableRowData row, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Column(
          children: [
            ...widget.table.columns.map((column) {
              final value = row.values[column.name] ?? '';
              final password = column.name.toLowerCase().contains('password');
              final display = password && value.isNotEmpty ? '••••••••' : value.isEmpty ? '—' : value;
              return InkWell(
                onTap: () => editRow(row),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: Text(column.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                      const SizedBox(width: 12),
                      Expanded(flex: 6, child: Text(display, textAlign: TextAlign.end)),
                      IconButton(onPressed: () => showColumnMenu(column), icon: const Icon(Icons.more_vert, size: 20), tooltip: 'Field options'),
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
                  TextButton.icon(onPressed: () => editRow(row), icon: const Icon(Icons.edit), label: const Text('Edit')),
                  TextButton.icon(onPressed: () => deleteRow(index), icon: const Icon(Icons.delete_outline), label: const Text('Delete')),
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
          IconButton(onPressed: addColumn, icon: const Icon(Icons.add_box_outlined), tooltip: 'Add Field'),
          IconButton(onPressed: renameTable, icon: const Icon(Icons.edit), tooltip: 'Rename Table'),
          if (widget.onDelete != null) IconButton(onPressed: deleteTable, icon: const Icon(Icons.delete_outline), tooltip: 'Delete Table'),
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
                        ElevatedButton.icon(onPressed: addRow, icon: const Icon(Icons.add), label: const Text('Add Record')),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  itemCount: widget.table.rows.length,
                  itemBuilder: (context, index) => buildRowCard(widget.table.rows[index], index),
                ),
      floatingActionButton: FloatingActionButton.extended(onPressed: addRow, icon: const Icon(Icons.add), label: const Text('Add Record')),
    );
  }
}
