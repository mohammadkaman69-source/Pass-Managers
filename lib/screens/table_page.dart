import 'package:flutter/material.dart';
import 'tree_page.dart';

class TablePage extends StatefulWidget {
  final TreeItem table;
  final VoidCallback? onDelete;

  const TablePage({
    super.key,
    required this.table,
    this.onDelete,
  });

  @override
  State<TablePage> createState() => _TablePageState();
}

class _TablePageState extends State<TablePage> {
  void addRow() {
    setState(() {
      widget.table.rows.add(
        TableRowData(
          columns: widget.table.columns,
        ),
      );
    });
  }

  void editRow(TableRowData row) {
    final controllers = <String, TextEditingController>{};

    for (final column in widget.table.columns) {
      controllers[column.name] = TextEditingController(
        text: row.values[column.name] ?? '',
      );
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Record'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: widget.table.columns.map((column) {
                  final controller =
                      controllers[column.name]!;

                  return Padding(
                    padding:
                        const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: column.name,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  for (final column in widget.table.columns) {
                    row.values[column.name] =
                        controllers[column.name]!.text;
                  }
                });

                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void deleteRow(TableRowData row) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Record'),
          content: const Text(
            'Are you sure you want to delete this record?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  widget.table.rows.remove(row);
                });

                Navigator.pop(dialogContext);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void addColumn() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
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
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();

                if (name.isEmpty) {
                  return;
                }

                final exists =
                    widget.table.columns.any(
                  (column) =>
                      column.name.toLowerCase() ==
                      name.toLowerCase(),
                );

                if (exists) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        'A field with this name already exists.',
                      ),
                    ),
                  );
                  return;
                }

                setState(() {
                  final newColumn =
                      TableColumnDefinition(name);

                  widget.table.columns.add(newColumn);

                  for (final row in widget.table.rows) {
                    row.values[name] = '';
                  }
                });

                Navigator.pop(dialogContext);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void renameColumn(
    TableColumnDefinition column,
  ) {
    final controller = TextEditingController(
      text: column.name,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
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
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newName =
                    controller.text.trim();

                if (newName.isEmpty ||
                    newName == column.name) {
                  Navigator.pop(dialogContext);
                  return;
                }

                final exists =
                    widget.table.columns.any(
                  (item) =>
                      !identical(item, column) &&
                      item.name.toLowerCase() ==
                          newName.toLowerCase(),
                );

                if (exists) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        'A field with this name already exists.',
                      ),
                    ),
                  );
                  return;
                }

                final oldName = column.name;

                setState(() {
                  column.name = newName;

                  for (final row in widget.table.rows) {
                    final value =
                        row.values.remove(oldName) ?? '';
                    row.values[newName] = value;
                  }
                });

                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
    void deleteColumn(
    TableColumnDefinition column,
  ) {
    if (widget.table.columns.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'At least one field must remain.',
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Field'),
          content: Text(
            'Delete "${column.name}" from this table?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  final name = column.name;

                  widget.table.columns.remove(column);

                  for (final row in widget.table.rows) {
                    row.values.remove(name);
                  }
                });

                Navigator.pop(dialogContext);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void moveColumn(
    TableColumnDefinition column,
    int direction,
  ) {
    final index =
        widget.table.columns.indexOf(column);

    if (index == -1) {
      return;
    }

    final newIndex = index + direction;

    if (newIndex < 0 ||
        newIndex >= widget.table.columns.length) {
      return;
    }

    setState(() {
      widget.table.columns.removeAt(index);
      widget.table.columns.insert(
        newIndex,
        column,
      );
    });
  }

  void showColumnMenu(
    TableColumnDefinition column,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        final index =
            widget.table.columns.indexOf(column);

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.edit_outlined,
                ),
                title: const Text('Rename Field'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  renameColumn(column);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.arrow_back,
                ),
                title: const Text('Move Left'),
                enabled: index > 0,
                onTap: index > 0
                    ? () {
                        Navigator.pop(sheetContext);
                        moveColumn(column, -1);
                      }
                    : null,
              ),
              ListTile(
                leading: const Icon(
                  Icons.arrow_forward,
                ),
                title: const Text('Move Right'),
                enabled:
                    index >= 0 &&
                    index <
                        widget.table.columns.length - 1,
                onTap:
                    index >= 0 &&
                            index <
                                widget.table.columns
                                        .length -
                                    1
                        ? () {
                            Navigator.pop(sheetContext);
                            moveColumn(column, 1);
                          }
                        : null,
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                ),
                title: const Text('Delete Field'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  deleteColumn(column);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void deleteTable() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Table'),
          content: Text(
            'Delete "${widget.table.name}" and all its records?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                widget.onDelete?.call();

                if (mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  DataRow buildDataRow(
    TableRowData row,
  ) {
    return DataRow(
      cells: [
        ...widget.table.columns.map(
          (column) {
            return DataCell(
              Text(
                row.values[column.name] ?? '',
              ),
            );
          },
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {
                  editRow(row);
                },
                icon: const Icon(
                  Icons.edit_outlined,
                ),
                tooltip: 'Edit',
              ),
              IconButton(
                onPressed: () {
                  deleteRow(row);
                },
                icon: const Icon(
                  Icons.delete_outline,
                ),
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ],
    );
  }
    Widget buildTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          ...widget.table.columns.map(
            (column) {
              return DataColumn(
                label: InkWell(
                  onTap: () {
                    showColumnMenu(column);
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          column.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.more_vert,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const DataColumn(
            label: Text(
              'Actions',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        rows: widget.table.rows
            .map(buildDataRow)
            .toList(),
      ),
    );
  }

  Widget buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.table_rows_outlined,
            size: 80,
            color: Theme.of(context)
                .colorScheme
                .primary,
          ),
          const SizedBox(height: 20),
          const Text(
            'No records',
            style: TextStyle(
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: addRow,
            icon: const Icon(Icons.add),
            label: const Text('Add Record'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.table.name,
        ),
        actions: [
          IconButton(
            onPressed: addColumn,
            icon: const Icon(
              Icons.view_column_outlined,
            ),
            tooltip: 'Add Field',
          ),
          IconButton(
            onPressed: addRow,
            icon: const Icon(
              Icons.add_box_outlined,
            ),
            tooltip: 'Add Record',
          ),
          if (widget.onDelete != null)
            IconButton(
              onPressed: deleteTable,
              icon: const Icon(
                Icons.delete_outline,
              ),
              tooltip: 'Delete Table',
            ),
        ],
      ),
      body: widget.table.rows.isEmpty
          ? buildEmptyState()
          : Padding(
              padding: const EdgeInsets.all(16),
              child: buildTable(),
            ),
      floatingActionButton:
          widget.table.rows.isEmpty
              ? null
              : FloatingActionButton(
                  onPressed: addRow,
                  child: const Icon(
                    Icons.add,
                  ),
                ),
    );
  }
}
