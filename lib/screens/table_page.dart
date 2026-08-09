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
  State<TablePage> createState() =>
      _TablePageState();
}

class _TablePageState
    extends State<TablePage> {
  final TreeRepository _repository =
      TreeRepository();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _loadRows();
  }

  Future<void> _loadRows() async {
    try {
      final rowRecords =
          await _repository.getRows(
        widget.tableId,
      );

      final loadedRows =
          <TableRowData>[];

      for (final rowRecord
          in rowRecords) {
        final rowId =
            rowRecord['id'] as int;

        final fieldRecords =
            await _repository
                .getFields(rowId);

        final columns =
            <TableColumnDefinition>[];

        final values =
            <String, String>{};

        for (final fieldRecord
            in fieldRecords) {
          final fieldId =
              fieldRecord['id'] as int;

          final name =
              fieldRecord['name'] as String;

          final valueRecords =
              await _repository
                  .getValues(fieldId);

          var value = '';

          if (valueRecords
              .isNotEmpty) {
            value =
                valueRecords.first['value']
                    as String;
          }

          columns.add(
            TableColumnDefinition(
              name,
            ),
          );

          values[name] = value;
        }

        if (columns.isEmpty) {
          columns.addAll(
            widget.table.columns
                .map(
              (column) => column.copy(),
            ),
          );

          for (final column
              in columns) {
            values[column.name] =
                '';
          }
        }

        loadedRows.add(
          TableRowData(
            columns: columns,
            values: values,
          ),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        widget.table.rows
          ..clear()
          ..addAll(loadedRows);

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load table: $error',
          ),
        ),
      );
    }
  }

  Future<void> addRow() async {
    try {
      final rowId =
          await _repository.createRow(
        tableId: widget.tableId,
      );

      final row =
          TableRowData(
        columns:
            widget.table.columns,
      );

      for (var i = 0;
          i < row.columns.length;
          i++) {
        await _repository
            .createField(
          rowId: rowId,
          name:
              row.columns[i].name,
          position: i,
          value:
              row.values[
                      row.columns[i].name] ??
                  '',
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        widget.table.rows.add(row);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to add record: $error',
          ),
        ),
      );
    }
  }

  Future<void> editRow(
    TableRowData row,
  ) async {
    final controllers =
        <String, TextEditingController>{};

    for (final column
        in row.columns) {
      controllers[column.name] =
          TextEditingController(
        text:
            row.values[column.name] ??
                '',
      );
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Edit Record',
          ),
          content: SizedBox(
            width: 500,
            child:
                SingleChildScrollView(
              child: Column(
                children:
                    row.columns.map(
                  (column) {
                    final isPassword =
                        column.name
                            .toLowerCase()
                            .contains(
                              'password',
                            );

                    return Padding(
                      padding:
                          const EdgeInsets
                              .only(
                        bottom: 14,
                      ),
                      child: TextField(
                        controller:
                            controllers[
                                column.name],
                        obscureText:
                            isPassword,
                        decoration:
                            const InputDecoration(
                          border:
                              OutlineInputBorder(),
                        ).copyWith(
                          labelText:
                              column.name,
                        ),
                      ),
                    );
                  },
                ).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  for (final column
                      in row.columns) {
                    final value =
                        controllers[
                                column.name]!
                            .text;

                    row.values[
                            column.name] =
                        value;
                  }

                  /*
                   * The current row object does not
                   * carry SQLite field IDs.
                   *
                   * Reloading after save guarantees
                   * that the UI and database remain
                   * synchronized.
                   */
                  await _saveRow(
                    row,
                  );

                  if (!mounted) {
                    return;
                  }

                  Navigator.pop(
                    dialogContext,
                  );

                  setState(() {});
                } catch (error) {
                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to save record: $error',
                      ),
                    ),
                  );
                }
              },
              child: const Text(
                'Save',
              ),
            ),
          ],
        );
      },
    );

    for (final controller
        in controllers.values) {
      controller.dispose();
    }
  }

  Future<void> _saveRow(
    TableRowData row,
  ) async {
    final rowRecords =
        await _repository.getRows(
      widget.tableId,
    );

    /*
     * Rows are loaded in the same database
     * order as widget.table.rows.
     */
    final index =
        widget.table.rows.indexOf(row);

    if (index < 0 ||
        index >= rowRecords.length) {
      return;
    }

    final rowId =
        rowRecords[index]['id'] as int;

    final fieldRecords =
        await _repository.getFields(
      rowId,
    );

    for (final fieldRecord
        in fieldRecords) {
      final fieldId =
          fieldRecord['id'] as int;

      final fieldName =
          fieldRecord['name'] as String;

      final value =
          row.values[fieldName] ??
              '';

      await _repository
          .updateFieldValue(
        fieldId: fieldId,
        value: value,
      );
    }
  }

  Future<void> deleteRow(
    int index,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Record',
          ),
          content: const Text(
            'Are you sure you want to delete this record?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final rowRecords =
          await _repository.getRows(
        widget.tableId,
      );

      if (index < 0 ||
          index >= rowRecords.length) {
        return;
      }

      final rowId =
          rowRecords[index]['id'] as int;

      await _repository.deleteRow(
        rowId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        widget.table.rows
            .removeAt(index);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete record: $error',
          ),
        ),
      );
    }
  }

  Future<void> addColumn(
    TableRowData row,
  ) async {
    final controller =
        TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Add Field',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration:
                const InputDecoration(
              labelText: 'Field name',
              hintText:
                  'Example: Volume',
              border:
                  OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final name =
                    controller.text.trim();

                if (name.isEmpty) {
                  return;
                }

                final exists =
                    row.columns.any(
                  (column) =>
                      column.name
                          .toLowerCase() ==
                      name.toLowerCase(),
                );

                if (exists) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'A field with this name already exists in this record.',
                      ),
                    ),
                  );

                  return;
                }

                try {
                  final rowRecords =
                      await _repository
                          .getRows(
                    widget.tableId,
                  );

                  final rowIndex =
                      widget.table.rows
                          .indexOf(row);

                  if (rowIndex <
                          0 ||
                      rowIndex >=
                          rowRecords
                              .length) {
                    return;
                  }

                  final rowId =
                      rowRecords[rowIndex]
                          ['id'] as int;

                  final position =
                      row.columns.length;

                  await _repository
                      .createField(
                    rowId: rowId,
                    name: name,
                    position:
                        position,
                  );

                  if (!mounted) {
                    return;
                  }

                  setState(() {
                    row.columns.add(
                      TableColumnDefinition(
                        name,
                      ),
                    );

                    row.values[name] =
                        '';
                  });

                  if (dialogContext
                      .mounted) {
                    Navigator.pop(
                      dialogContext,
                    );
                  }
                } catch (error) {
                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to add field: $error',
                      ),
                    ),
                  );
                }
              },
              child: const Text(
                'Add Field',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  Future<void> renameColumn(
    TableRowData row,
    TableColumnDefinition column,
  ) async {
    final oldName =
        column.name;

    final controller =
        TextEditingController(
      text: oldName,
    );

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Rename Field',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration:
                const InputDecoration(
              labelText:
                  'Field name',
              border:
                  OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName =
                    controller.text.trim();

                if (newName.isEmpty) {
                  return;
                }

                if (newName !=
                    oldName) {
                  final exists =
                      row.columns.any(
                    (item) =>
                        item != column &&
                        item.name
                                .toLowerCase() ==
                            newName
                                .toLowerCase(),
                  );

                  if (exists) {
                    ScaffoldMessenger
                            .of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'A field with this name already exists in this record.',
                        ),
                      ),
                    );

                    return;
                  }
                }

                try {
                  final rowRecords =
                      await _repository
                          .getRows(
                    widget.tableId,
                  );

                  final rowIndex =
                      widget.table.rows
                          .indexOf(row);

                  if (rowIndex <
                          0 ||
                      rowIndex >=
                          rowRecords
                              .length) {
                    return;
                  }

                  final rowId =
                      rowRecords[rowIndex]
                          ['id'] as int;

                  final fieldRecords =
                      await _repository
                          .getFields(
                    rowId,
                  );

                  final fieldIndex =
                      row.columns
                          .indexOf(
                    column,
                  );

                  if (fieldIndex <
                          0 ||
                      fieldIndex >=
                          fieldRecords
                              .length) {
                    return;
                  }

                  final fieldId =
                      fieldRecords[
                              fieldIndex]
                          ['id'] as int;

                  final value =
                      row.values[
                              oldName] ??
                          '';

                  await _repository
                      .renameField(
                    fieldId:
                        fieldId,
                    name:
                        newName,
                  );

                  await _repository
                      .updateFieldValue(
                    fieldId:
                        fieldId,
                    value:
                        value,
                  );

                  if (!mounted) {
                    return;
                  }

                  setState(() {
                    row.values
                        .remove(
                      oldName,
                    );

                    row.values[
                            newName] =
                        value;

                    column.name =
                        newName;
                  });

                  if (dialogContext
                      .mounted) {
                    Navigator.pop(
                      dialogContext,
                    );
                  }
                } catch (error) {
                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to rename field: $error',
                      ),
                    ),
                  );
                }
              },
              child: const Text(
                'Save',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  Future<void> deleteColumn(
    TableRowData row,
    TableColumnDefinition column,
  ) async {
    if (row.columns.length <= 1) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'At least one field must remain in this record.',
          ),
        ),
      );

      return;
    }

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Field',
          ),
          content: Text(
            'Delete field "${column.name}" from this record?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final rowRecords =
          await _repository.getRows(
        widget.tableId,
      );

      final rowIndex =
          widget.table.rows.indexOf(row);

      if (rowIndex < 0 ||
          rowIndex >=
              rowRecords.length) {
        return;
      }

      final rowId =
          rowRecords[rowIndex]['id']
              as int;

      final fieldRecords =
          await _repository.getFields(
        rowId,
      );

      final columnIndex =
          row.columns.indexOf(
        column,
      );

      if (columnIndex < 0 ||
          columnIndex >=
              fieldRecords.length) {
        return;
      }

      final fieldId =
          fieldRecords[columnIndex]
              ['id'] as int;

      await _repository.deleteField(
        fieldId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final columnName =
            column.name;

        row.columns.remove(
          column,
        );

        row.values.remove(
          columnName,
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete field: $error',
          ),
        ),
      );
    }
  }

  Future<void> moveColumn(
    TableRowData row,
    TableColumnDefinition column,
    int newIndex,
  ) async {
    final columns =
        row.columns;

    final oldIndex =
        columns.indexOf(column);

    if (oldIndex == -1) {
      return;
    }

    if (newIndex < 0 ||
        newIndex >= columns.length) {
      return;
    }

    if (oldIndex == newIndex) {
      return;
    }

    try {
      final rowRecords =
          await _repository.getRows(
        widget.tableId,
      );

      final rowIndex =
          widget.table.rows.indexOf(row);

      if (rowIndex < 0 ||
          rowIndex >= rowRecords.length) {
        return;
      }

      final rowId =
          rowRecords[rowIndex]['id']
              as int;

      final fieldRecords =
          await _repository.getFields(
        rowId,
      );

      if (fieldRecords.length !=
          columns.length) {
        return;
      }

      final fieldIds =
          fieldRecords
              .map(
                (field) =>
                    field['id'] as int,
              )
              .toList();

      final movedId =
          fieldIds.removeAt(
        oldIndex,
      );

      fieldIds.insert(
        newIndex,
        movedId,
      );

      await _repository
          .updateFieldPositions(
        fieldIds,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        columns.removeAt(
          oldIndex,
        );

        columns.insert(
          newIndex,
          column,
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to move field: $error',
          ),
        ),
      );
    }
  }

  void showColumnMenu(
    TableRowData row,
    TableColumnDefinition column,
  ) {
    final index =
        row.columns.indexOf(column);

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.edit,
                ),
                title: const Text(
                  'Rename Field',
                ),
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  renameColumn(
                    row,
                    column,
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.arrow_upward,
                ),
                enabled: index > 0,
                title: const Text(
                  'Move Up',
                ),
                onTap: index > 0
                    ? () {
                        Navigator.pop(
                          sheetContext,
                        );

                        moveColumn(
                          row,
                          column,
                          index - 1,
                        );
                      }
                    : null,
              ),
              ListTile(
                leading: const Icon(
                  Icons.arrow_downward,
                ),
                enabled: index <
                    row.columns.length -
                        1,
                title: const Text(
                  'Move Down',
                ),
                onTap: index <
                        row.columns.length -
                            1
                    ? () {
                        Navigator.pop(
                          sheetContext,
                        );

                        moveColumn(
                          row,
                          column,
                          index + 1,
                        );
                      }
                    : null,
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                ),
                title: const Text(
                  'Delete Field',
                ),
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  deleteColumn(
                    row,
                    column,
                  );
                },
              ),
              const SizedBox(
                height: 8,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> renameTable() async {
    final controller =
        TextEditingController(
      text: widget.table.name,
    );

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Rename Table',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration:
                const InputDecoration(
              labelText:
                  'Table name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final name =
                    controller.text.trim();

                if (name.isEmpty) {
                  return;
                }

                try {
                  await _repository
                      .renameItem(
                    id:
                        widget.tableId,
                    name:
                        name,
                  );

                  if (!mounted) {
                    return;
                  }

                  setState(() {
                    widget.table.name =
                        name;
                  });

                  if (dialogContext
                      .mounted) {
                    Navigator.pop(
                      dialogContext,
                    );
                  }
                } catch (error) {
                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to rename table: $error',
                      ),
                    ),
                  );
                }
              },
              child: const Text(
                'Save',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  Future<void> deleteTable() async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Table',
          ),
          content: Text(
            'Delete "${widget.table.name}" and all its records?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _repository.deleteItem(
        widget.tableId,
      );

      if (!mounted) {
        return;
      }

      widget.onDelete?.call();

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete table: $error',
          ),
        ),
      );
    }
  }

  Widget buildRowCard(
    TableRowData row,
    int rowIndex,
  ) {
    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 16,
      ),
      child: Padding(
        padding:
            const EdgeInsets.only(
          top: 8,
          bottom: 8,
        ),
        child: Column(
          children: [
            ...row.columns.map(
              (column) {
                final value =
                    row.values[
                            column.name] ??
                        '';

                final isPassword =
                    column.name
                        .toLowerCase()
                        .contains(
                          'password',
                        );

                final displayValue =
                    isPassword &&
                            value.isNotEmpty
                        ? '••••••••'
                        : value.isEmpty
                            ? '—'
                            : value;

                return InkWell(
                  onTap: () {
                    editRow(row);
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: Text(
                            column.name,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 12,
                        ),
                        Expanded(
                          flex: 6,
                          child: Text(
                            displayValue,
                            textAlign:
                                TextAlign
                                    .end,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            showColumnMenu(
                              row,
                              column,
                            );
                          },
                          icon:
                              const Icon(
                            Icons.more_vert,
                            size: 20,
                          ),
                          tooltip:
                              'Field options',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const Divider(
              height: 1,
            ),
            Padding(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 8,
              ),
              child: Wrap(
                alignment:
                    WrapAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      editRow(row);
                    },
                    icon: const Icon(
                      Icons.edit,
                    ),
                    label:
                        const Text(
                      'Edit',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      deleteRow(
                        rowIndex,
                      );
                    },
                    icon:
                        const Icon(
                      Icons
                          .delete_outline,
                    ),
                    label:
                        const Text(
                      'Delete',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      addColumn(row);
                    },
                    icon:
                        const Icon(
                      Icons
                          .add_box_outlined,
                    ),
                    label:
                        const Text(
                      'Add Field',
                    ),
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
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.table.name,
        ),
        actions: [
          IconButton(
            onPressed: renameTable,
            icon: const Icon(
              Icons.edit,
            ),
            tooltip:
                'Rename Table',
          ),
          if (widget.onDelete != null)
            IconButton(
              onPressed:
                  deleteTable,
              icon: const Icon(
                Icons
                    .delete_outline,
              ),
              tooltip:
                  'Delete Table',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : widget.table.rows
                  .isEmpty
              ? Center(
                  child:
                      SingleChildScrollView(
                    padding:
                        const EdgeInsets
                            .all(
                      24,
                    ),
                    child: Column(
                      mainAxisSize:
                          MainAxisSize
                              .min,
                      children: [
                        const Icon(
                          Icons
                              .table_chart_outlined,
                          size: 80,
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        const Text(
                          'No records yet',
                          style:
                              TextStyle(
                            fontSize:
                                18,
                          ),
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        ElevatedButton
                            .icon(
                          onPressed:
                              addRow,
                          icon:
                              const Icon(
                            Icons.add,
                          ),
                          label:
                              const Text(
                            'Add Record',
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    16,
                    16,
                    16,
                    120,
                  ),
                  itemCount: widget
                      .table
                      .rows
                      .length,
                  itemBuilder:
                      (context, index) {
                    return buildRowCard(
                      widget.table
                          .rows[index],
                      index,
                    );
                  },
                ),
      floatingActionButton:
          FloatingActionButton
              .extended(
        onPressed: addRow,
        icon: const Icon(
          Icons.add,
        ),
        label:
            const Text(
          'Add Record',
        ),
      ),
    );
  }
}
