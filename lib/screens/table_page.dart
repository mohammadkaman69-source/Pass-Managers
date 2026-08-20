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
      _showError('بارگذاری جدول ناموفق بود: $error');
    }
  }

  Future<Map<String, int>?> _askRowAndColumnCounts() async {
    final columnsController = TextEditingController();
    final rowsController = TextEditingController(text: '1');

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('افزودن رکورد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: columnsController,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'تعداد ستون',
                hintText: 'مثال: ۵',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rowsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'تعداد سطر',
                hintText: 'مثال: ۳',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('انصراف'),
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
            child: const Text('ادامه'),
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
          title: Text('نام ستون ${i + 1} از $count'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'نام فیلد / هدر',
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
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) Navigator.pop(dialogContext, value);
              },
              child: const Text('بعدی'),
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
      _showError('افزودن رکورد ناموفق بود: $error');
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
      obscure[fieldId] = column.name.toLowerCase().contains('password') ||
          column.name.contains('رمز') ||
          column.name.contains('پسورد');
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('ویرایش رکورد'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                children: row.columns.map((column) {
                  final fieldId = column.fieldId;
                  if (fieldId == null) return const SizedBox.shrink();
                  final isPassword =
                      column.name.toLowerCase().contains('password') ||
                          column.name.contains('رمز') ||
                          column.name.contains('پسورد');
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
              child: const Text('انصراف'),
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
              child: const Text('ذخیره'),
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
      _showError('ذخیره رکورد ناموفق بود: $error');
    }
  }

  Future<void> editCell(
    TableRowData row,
    TableColumnDefinition column,
  ) async {
    final fieldId = column.fieldId;
    if (fieldId == null) return;

    final controller = TextEditingController(text: row.values[fieldId] ?? '');
    final isPassword = column.name.toLowerCase().contains('password') ||
        column.name.contains('رمز') ||
        column.name.contains('پسورد');
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
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('ذخیره'),
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
      _showError('ذخیره مقدار ناموفق بود: $error');
    }
  }

  Future<void> deleteRow(int index) async {
    if (index < 0 || index >= widget.table.rows.length) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف رکورد'),
        content: const Text('آیا از حذف این رکورد مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final row = widget.table.rows[index];
    final rowId = _rowIds[row];
    if (rowId == null) {
      _showError('شناسه رکورد پیدا نشد.');
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
      _showError('حذف رکورد ناموفق بود: $error');
    }
  }

  Future<void> deleteRowObject(TableRowData row) async {
    final index = widget.table.rows.indexOf(row);
    if (index < 0) return;
    await deleteRow(index);
  }

  Future<void> addRowToGroup(List<TableRowData> group) async {
    if (group.isEmpty) return;
    final sample = group.first;
    if (sample.columns.isEmpty) {
      _showError('این گروه فیلدی ندارد.');
      return;
    }

    final names = sample.columns.map((c) => c.name).toList();

    try {
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

      final lastInGroup = group.last;
      final insertAt = widget.table.rows.indexOf(lastInGroup);
      if (insertAt < 0) {
        widget.table.rows.add(row);
      } else {
        widget.table.rows.insert(insertAt + 1, row);
      }
      _rowIds[row] = rowId;

      if (mounted) setState(() {});
    } catch (error) {
      _showError('افزودن سطر ناموفق بود: $error');
    }
  }

  Future<void> addColumnToGroup(List<TableRowData> group) async {
    if (group.isEmpty) return;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('افزودن فیلد'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'نام فیلد',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('افزودن'),
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
      _showError('افزودن فیلد ناموفق بود: $error');
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
        title: const Text('تغییر نام فیلد'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'نام فیلد',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('ذخیره'),
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
      _showError('تغییر نام فیلد ناموفق بود: $error');
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
      _showError('حداقل یک فیلد باید در رکورد باقی بماند.');
      return;
    }

    final name = sample.columns[columnIndex].name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف فیلد'),
        content: Text('فیلد «$name» از همه سطرهای این گروه حذف شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
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
      _showError('حذف فیلد ناموفق بود: $error');
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
      _showError('جابه‌جایی فیلد ناموفق بود: $error');
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
              title: const Text('تغییر نام فیلد'),
              onTap: () {
                Navigator.pop(sheetContext);
                renameColumnInGroup(group, columnIndex);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward),
              enabled: columnIndex > 0,
              title: const Text('انتقال به بالا'),
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
              title: const Text('انتقال به پایین'),
              onTap: columnIndex < sample.columns.length - 1
                  ? () {
                      Navigator.pop(sheetContext);
                      moveColumnInGroup(group, columnIndex, columnIndex + 1);
                    }
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('حذف فیلد'),
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
        title: const Text('تغییر نام جدول'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'نام جدول',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('ذخیره'),
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
      _showError('تغییر نام جدول ناموفق بود: $error');
    }
  }

  Future<void> deleteTable() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف جدول'),
        content: Text('جدول «${widget.table.name}» و همه رکوردهایش حذف شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
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
      _showError('حذف جدول ناموفق بود: $error');
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
    final isPassword = column.name.toLowerCase().contains('password') ||
        column.name.contains('رمز') ||
        column.name.contains('پسورد');
    if (isPassword && raw.isNotEmpty) return '••••••••';
    return raw;
  }

  Widget _valueCell({
    required TableRowData row,
    required int fieldIndex,
    required double width,
    required double height,
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
      var maxW = 80.0;
      for (var i = 0; i < fieldCount; i++) {
        if (i >= row.columns.length) continue;
        final col = row.columns[i];
        final fieldId = col.fieldId;
        final raw = fieldId == null ? '' : (row.values[fieldId] ?? '');
        final display = _displayValue(col, raw);
        final w = _measureWidth(display.isEmpty ? ' ' : display);
        if (w > maxW) maxW = w;
      }
      if (maxW < 88) maxW = 88;
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
    const actionH = 44.0;

    Widget headerCell(int i) {
      return Material(
        color: headerBg,
        child: InkWell(
          onLongPress: () => showColumnMenuForGroup(group, i),
          child: Container(
            width: headerWidth,
            height: rowHeights[i],
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: headerBg,
              border: Border.all(color: borderColor, width: 0.55),
            ),
            alignment: Alignment.centerRight,
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
        ),
      );
    }

    final headerColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < fieldCount; i++) headerCell(i),
        Container(
          width: headerWidth,
          height: actionH,
          decoration: BoxDecoration(
            color: headerBg,
            border: Border.all(color: borderColor, width: 0.55),
          ),
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
              ),
            Container(
              width: w,
              height: actionH,
              decoration: BoxDecoration(
                border: Border.all(color: borderColor, width: 0.55),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: const Icon(Icons.edit, size: 18),
                    tooltip: 'ویرایش',
                    onPressed: () => editRow(row),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    tooltip: 'حذف',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: recordStrips.reversed.toList(),
                    ),
                  ),
                ),
                headerColumn,
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => addRowToGroup(group),
                  icon: const Icon(Icons.playlist_add, size: 18),
                  label: const Text('افزودن سطر'),
                ),
                TextButton.icon(
                  onPressed: () => addColumnToGroup(group),
                  icon: const Icon(Icons.add_box_outlined, size: 18),
                  label: const Text('افزودن فیلد'),
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
            tooltip: 'تغییر نام جدول',
          ),
          if (widget.onDelete != null)
            IconButton(
              onPressed: deleteTable,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'حذف جدول',
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
                        const Text('هنوز رکوردی نیست',
                            style: TextStyle(fontSize: 18)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: addRow,
                          icon: const Icon(Icons.add),
                          label: const Text('افزودن رکورد'),
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
        label: const Text('افزودن رکورد'),
      ),
    );
  }
}
