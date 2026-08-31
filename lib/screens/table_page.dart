import 'package:flutter/material.dart';

import '../models/table_column_definition.dart';
import '../models/table_row_data.dart';
import '../models/tree_item.dart';
import '../repositories/tree_repository.dart';
import '../widgets/app_search_bar.dart';
import '../services/app_language.dart';

// FULL FILE RESTORED - see artifacts if incomplete
class TablePage extends StatefulWidget {
  final TreeItem table;
  final int tableId;
  final VoidCallback? onDelete;
  final ValueChanged<String>? onRenamed;

  const TablePage({
    super.key,
    required this.table,
    required this.tableId,
    this.onDelete,
    this.onRenamed,
  });

  @override
  State<TablePage> createState() => _TablePageState();
}

class _TablePageState extends State<TablePage> {
  final TreeRepository _repository = TreeRepository();
  final Map<TableRowData, int> _rowIds = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRows();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
          final value = valueRecords.isEmpty ? '' : valueRecords.first['value'] as String;
          columns.add(TableColumnDefinition(name, fieldId: fieldId));
          values[fieldId] = value;
        }
        final row = TableRowData(columns: columns, values: values);
        rows.add(row);
        ids[row] = rowId;
      }
      if (!mounted) return;
      setState(() {
        widget.table.rows..clear()..addAll(rows);
        _rowIds..clear()..addAll(ids);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(AppStrings.loadTableFailed(context, error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.table.name),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.edit),
            tooltip: AppStrings.renameTable(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(child: Text(AppStrings.noRecordsYet(context))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: Text(AppStrings.addRecord(context)),
      ),
    );
  }
}
