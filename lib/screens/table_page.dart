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
        final values = <int, String>{};

        for (final field in fields) {
          final fieldId = field['id'] as int;
          final name = field['name'] as String;
          final valueRecords = await _repository.getValues(fieldId);
          final value = valueRecords.isEmpty
              ? ''
              : valueRecords.first['value'] as String;
          columns.add(TableColumnDefinition(name, fieldId: fieldId));
          values[fieldId] = value;
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
    final columnsController = TextEditingController();
    final rowsController = TextEditingController(text: '1');

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Record'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: columnsController,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number of columns',
                hintText: 'Example: 5',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rowsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number of rows',
                hintText: 'Example: 3',
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
              final columnCount = int.tryParse(columnsController.text.trim());
              final rowCount = int.tryParse(rowsController.text.trim());
              if (columnCount != null &&
                  columnCount > 0 &&
                  rowCount != null &&
                  rowCount > 0) {
                Navigator.pop(dialogContext, {
                  'columns': columnCount,
                  'rows': rowCount,
                });
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    columnsController.dispose();
    rowsController.dispose();
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
                if (value.isNotEmpty) Navigator.pop(dialogContext, value);
              },
              child: const Text('Next'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (name == null || name.trim().isEmpty) return null;
      names.add(name.trim());
    }

    return names;
  }

  Future<void> addRow() async {
    final counts = await _askRowAndColumnCounts();
    if (counts == null) return;

    final columnCount = counts['columns']!;
    final rowCount = counts['rows']!;
    final names = await _askColumnNames(columnCount);
    if (names == null || names.isEmpty) return;

    try {
      final createdRows = <TableRowData>[];
      final createdIds = <TableRowData, int>{};

      for (var rowIndex = 0; rowIndex < rowCount; rowIndex++) {
        final rowId = await _repository.createRow(tableId: widget.tableId);
        final columns = <TableColumnDefinition>[];
        final values = <int, String>{};

        for (var i = 0; i < names.length; i++) {
          final fieldId = await _repository.createField(
            rowId: rowId,
            name: names[i],
            position: i,
            value: '',
          );
          columns.add(TableColumnDefinition(names[i], fieldId: fieldId));
          values[fieldId] = '';
        }

        final row = TableRowData(columns: columns, values: values);
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

  Future<void> editRow(TableRowData row) async {
    final controllers = <int, TextEditingController>{};
    final obscure = <int, bool>{};

    for (final column in row.columns) {
      final fieldId = column.fieldId;
      if (fieldId == null) continue;
      controllers[fieldId] =
          TextEditingController(text: row.values[fieldId] ?? '');
      obscure[fieldId] = column.name.toLowerCase().contains('password');
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
                  final fieldId = column.fieldId;
                  if (fieldId == null) return const SizedBox.shrink();
                  final isPassword =
                      column.name.toLowerCase().contains('password');
                  final isObscured = obscure[fieldId] ?? true;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: TextField(
                      controller: controllers[fieldId],
                      obscureText: isPassword && isObscured,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: column.name,
                        suffixIcon: isPassword
                            ? IconButton(
                                onPressed: () {
                                  setDialogState(() {
                                    obscure[fieldId] = !isObscured;
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
                  final fieldId = column.fieldId;
                  if (fieldId == null) continue;
                  row.values[fieldId] = controllers[fieldId]!.text;
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
      for (final column in row.columns) {
        final fieldId = column.fieldId;
        if (fieldId == null) continue;
        await _repository.updateFieldValue(
          fieldId: fieldId,
          value: row.values[fieldId] ?? '',
        );
      }
      if (mounted) setState(() {});
    } catch (error) {
      _showError('Failed to save record: $error');
    }
  }

  Future<void> editCell(
    TableRowData row,
    TableColumnDefinition column,
  ) async {
    final fieldId = column.fieldId;
    if (fieldId == null) return;

    final controller = TextEditingController(text: row.values[fieldId] ?? '');
    final isPassword = column.name.toLowerCase().contains('password');
    var obscure = isPassword;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(column.name),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: isPassword && obscure,
            maxLines: isPassword ? 1 : 4,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              suffixIcon: isPassword
                  ? IconButton(
                      onPressed: () {
                        setDialogState(() => obscure = !obscure);
                      },
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    )
                  : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    final newValue = controller.text;
    controller.dispose();
    if (result != true) return;

    try {
      row.values[fieldId] = newValue;
      await _repository.updateFieldValue(fieldId: fieldId, value: newValue);
      if (mounted) setState(() {});
    } catch (error) {
      _showError('Failed to save cell: $error');
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

  Future<void> deleteRowObject(TableRowData row) async {
    final index = widget.table.rows.indexOf(row);
    if (index < 0) return;
    await deleteRow(index);
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
        row.columns.add(TableColumnDefinition(name, fieldId: fieldId));
        row.values[fieldId] = '';
      });
    } catch (error) {
      _showError('Failed to add field: $error');
    }
  }

  Future<void> addColumnToGroup(List<TableRowData> group) async {
    if (group.isEmpty) return;
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

    try {
      for (final row in group) {
        final rowId = _rowIds[row];
        if (rowId == null) continue;
        final fieldId = await _repository.createField(
          rowId: rowId,
          name: name,
          position: row.columns.length,
          value: '',
        );
        row.columns.add(TableColumnDefinition(name, fieldId: fieldId));
        row.values[fieldId] = '';
      }
      if (mounted) setState(() {});
    } catch (error) {
      _showError('Failed to add field: $error');
    }
  }

  Future<void> renameColumnInGroup(
    List<TableRowData> group,
    int columnIndex,
  ) async {
    if (group.isEmpty) return;
    final sample = group.first;
    if (columnIndex < 0 || columnIndex >= sample.columns.length) return;

    final oldName = sample.columns[columnIndex].name;
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

    try {
      for (final row in group) {
        if (columnIndex >= row.columns.length) continue;
        final column = row.columns[columnIndex];
        final fieldId = column.fieldId;
        if (fieldId == null) continue;
        await _repository.renameField(fieldId: fieldId, name: newName);
        column.name = newName;
      }
      if (mounted) setState(() {});
    } catch (error) {
      _showError('Failed to rename field: $error');
    }
  }

  Future<void> deleteColumnInGroup(
    List<TableRowData> group,
    int columnIndex,
  ) async {
    if (group.isEmpty) return;
    final sample = group.first;
    if (columnIndex < 0 || columnIndex >= sample.columns.length) return;
    if (sample.columns.length <= 1) {
      _showError('At least one field must remain in this record.');
      return;
    }

    final name = sample.columns[columnIndex].name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Field'),
        content: Text('Delete field "$name" from all rows in this group?'),
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
      for (final row in group) {
        if (columnIndex >= row.columns.length) continue;
        final column = row.columns[columnIndex];
        final fieldId = column.fieldId;
        if (fieldId == null) continue;
        await _repository.deleteField(fieldId);
        row.columns.removeAt(columnIndex);
        row.values.remove(fieldId);
      }
      if (mounted) setState(() {});
    } catch (error) {
      _showError('Failed to delete field: $error');
    }
  }

  Future<void> moveColumnInGroup(
    List<TableRowData> group,
    int oldIndex,
    int newIndex,
  ) async {
    if (group.isEmpty) return;
    final sample = group.first;
    if (oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= sample.columns.length ||
        newIndex >= sample.columns.length ||
        oldIndex == newIndex) {
      return;
    }

    try {
      for (final row in group) {
        if (row.columns.any((c) => c.fieldId == null)) continue;
        if (oldIndex >= row.columns.length || newIndex >= row.columns.length) {
          continue;
        }
        final ids = row.columns.map((c) => c.fieldId!).toList();
        final moved = ids.removeAt(oldIndex);
        ids.insert(newIndex, moved);
        await _repository.updateFieldPositions(ids);

        final col = row.columns.removeAt(oldIndex);
        row.columns.insert(newIndex, col);
      }
      if (mounted) setState(() {});
    } catch (error) {
      _showError('Failed to move field: $error');
    }
  }

  void showColumnMenuForGroup(
    List<TableRowData> group,
    int columnIndex,
  ) {
    final sample = group.first;
    if (columnIndex < 0 || columnIndex >= sample.columns.length) return;

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
                renameColumnInGroup(group, columnIndex);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward),
              enabled: columnIndex > 0,
              title: const Text('Move Up'),
              onTap: columnIndex > 0
                  ? () {
                      Navigator.pop(sheetContext);
                      moveColumnInGroup(group, columnIndex, columnIndex - 1);
                    }
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward),
              enabled: columnIndex < sample.columns.length - 1,
              title: const Text('Move Down'),
              onTap: columnIndex < sample.columns.length - 1
                  ? () {
                      Navigator.pop(sheetContext);
                      moveColumnInGroup(group, columnIndex, columnIndex + 1);
                    }
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete Field'),
              onTap: () {
                Navigator.pop(sheetContext);
                deleteColumnInGroup(group, columnIndex);
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

  String _rowSignature(TableRowData row) {
    return row.columns.map((c) => c.name.trim()).join('|');
  }

  List<List<TableRowData>> _groupRows(List<TableRowData> rows) {
    final groups = <List<TableRowData>>[];
    List<TableRowData>? current;
    String? currentSig;

    for (final row in rows) {
      final sig = _rowSignature(row);
      if (current == null || sig != currentSig) {
        current = <TableRowData>[row];
        currentSig = sig;
        groups.add(current);
      } else {
        current.add(row);
      }
    }
    return groups;
  }

  double _measureWidth(String text) {
    final len = text.trim().length;
    final width = 24.0 + len * 9.0;
    if (width < 72) return 72;
    if (width > 260) return 260;
    return width;
  }

  double _measureHeight(String text) {
    final lines = (text.trim().length / 18).ceil().clamp(1, 5);
    return 36.0 + (lines - 1) * 16.0;
  }

  String _displayValue(TableColumnDefinition column, String raw) {
    final isPassword = column.name.toLowerCase().contains('password');
    if (isPassword && raw.isNotEmpty) return '••••••••';
    return raw;
  }

  Widget _valueCell({
    required TableRowData row,
    required int fieldIndex,
    required double width,
    required double height,
    required int fieldCount,
  }) {
    if (fieldIndex >= row.columns.length) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFBDBDBD), width: 0.55),
        ),
      );
    }
    final col = row.columns[fieldIndex];
    final fieldId = col.fieldId;
    final raw = fieldId == null ? '' : (row.values[fieldId] ?? '');
    final display = _displayValue(col, raw);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => editCell(row, col),
        onLongPress: () => editRow(row),
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFBDBDBD), width: 0.55),
          ),
          alignment: Alignment.centerRight,
          child: Text(
            display,
            textAlign: TextAlign.right,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildSideBySideGroup(List<TableRowData> group) {
    if (group.isEmpty) return const SizedBox.shrink();

    final sample = group.first;
    final fieldCount = sample.columns.length;

    var headerWidth = 88.0;
    for (final col in sample.columns) {
      final w = _measureWidth(col.name);
      if (w > headerWidth) headerWidth = w;
    }
    if (headerWidth > 160) headerWidth = 160;

    final recordWidths = <double>[];
    for (final row in group) {
      var maxW = 72.0;
      for (var i = 0; i < fieldCount; i++) {
        if (i >= row.columns.length) continue;
        final col = row.columns[i];
        final fieldId = col.fieldId;
        final raw = fieldId == null ? '' : (row.values[fieldId] ?? '');
        final display = _displayValue(col, raw);
        final w = _measureWidth(display.isEmpty ? ' ' : display);
        if (w > maxW) maxW = w;
      }
      recordWidths.add(maxW);
    }

    final rowHeights = <double>[];
    for (var i = 0; i < fieldCount; i++) {
      var h = _measureHeight(sample.columns[i].name);
      for (final row in group) {
        if (i >= row.columns.length) continue;
        final col = row.columns[i];
        final fieldId = col.fieldId;
        final raw = fieldId == null ? '' : (row.values[fieldId] ?? '');
        final display = _displayValue(col, raw);
        final cellH = _measureHeight(display.isEmpty ? ' ' : display);
        if (cellH > h) h = cellH;
      }
      rowHeights.add(h);
    }

    const headerBg = Color(0xFFECECEC);
    const borderColor = Color(0xFFBDBDBD);

    Widget cell({
      required double width,
      required double height,
      required Widget child,
      Color? color,
      VoidCallback? onTap,
      VoidCallback? onLongPress,
    }) {
      final box = Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: borderColor, width: 0.55),
        ),
        alignment: Alignment.centerRight,
        child: child,
      );
      if (onTap == null && onLongPress == null) return box;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: box,
        ),
      );
    }

    final headerStrip = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < fieldCount; i++)
          cell(
            width: headerWidth,
            height: rowHeights[i],
            color: headerBg,
            onLongPress: () => showColumnMenuForGroup(group, i),
            child: Text(
              sample.columns[i].name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              textAlign: TextAlign.right,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        cell(
          width: headerWidth,
          height: 40,
          color: headerBg,
          child: const SizedBox.shrink(),
        ),
      ],
    );

    final recordStrips = <Widget>[];
    for (var r = 0; r < group.length; r++) {
      final row = group[r];
      final w = recordWidths[r];

      recordStrips.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < fieldCount; i++)
              _valueCell(
                row: row,
                fieldIndex: i,
                width: w,
                height: rowHeights[i],
                fieldCount: fieldCount,
              ),
            cell(
              width: w,
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: const Icon(Icons.edit, size: 16),
                    tooltip: 'Edit',
                    onPressed: () => editRow(row),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    tooltip: 'Delete',
                    onPressed: () => deleteRowObject(row),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        headerStrip,
                        ...recordStrips,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => addColumnToGroup(group),
                  icon: const Icon(Icons.add_box_outlined, size: 18),
                  label: const Text('Add Field'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupRows(widget.table.rows);

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
                        const Text('No records yet',
                            style: TextStyle(fontSize: 18)),
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
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
                  itemCount: groups.length,
                  itemBuilder: (context, index) =>
                      _buildSideBySideGroup(groups[index]),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addRow,
        icon: const Icon(Icons.add),
        label: const Text('Add Record'),
      ),
    );
  }
}
