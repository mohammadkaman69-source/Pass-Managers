import 'package:flutter/material.dart';

import 'tree_page.dart';

class TablePage extends StatefulWidget {
  final TreeItem table;

  const TablePage({
    super.key,
    required this.table,
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
      controllers[column.name] =
          TextEditingController(
        text: row.values[column.name] ?? '',
      );
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            "Edit Row",
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                children: widget.table.columns.map(
                  (column) {
                    return Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 12,
                      ),
                      child: TextField(
                        controller:
                            controllers[column.name],
                        decoration:
                            InputDecoration(
                          labelText:
                              column.name,
                          border:
                              const OutlineInputBorder(),
                        ),
                        obscureText:
                            column.name
                                .toLowerCase()
                                .contains(
                                  "password",
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
                "Cancel",
              ),
            ),
            ElevatedButton(
              onPressed: () {
                for (final column
                    in widget.table.columns) {
                  row.values[column.name] =
                      controllers[column.name]!
                          .text;
                }

                Navigator.pop(
                  dialogContext,
                );

                setState(() {});
              },
              child: const Text(
                "Save",
              ),
            ),
          ],
        );
      },
    ).then((_) {
      for (final controller
          in controllers.values) {
        controller.dispose();
      }
    });
  }

  void deleteRow(int index) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            "Delete Row",
          ),
          content: const Text(
            "Are you sure you want to delete this row?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                "Cancel",
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  widget.table.rows.removeAt(
                    index,
                  );
                });

                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                "Delete",
              ),
            ),
          ],
        );
      },
    );
  }

  void addColumn() {
    final controller =
        TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            "Add Column",
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration:
                const InputDecoration(
              labelText:
                  "Column name",
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
                "Cancel",
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final name =
                    controller.text.trim();

                if (name.isEmpty) {
                  return;
                }

                final exists = widget.table
                    .columns
                    .any(
                  (column) =>
                      column.name
                          .toLowerCase() ==
                      name.toLowerCase(),
                );

                if (exists) {
                  return;
                }

                setState(() {
                  widget.table.columns.add(
                    TableColumnDefinition(
                      name,
                    ),
                  );

                  for (final row
                      in widget.table.rows) {
                    row.values[name] = '';
                  }
                });

                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                "Add",
              ),
            ),
          ],
        );
      },
    ).then((_) {
      controller.dispose();
    });
  }

  void renameColumn(
    TableColumnDefinition column,
  ) {
    final oldName = column.name;

    final controller =
        TextEditingController(
      text: oldName,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            "Rename Column",
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration:
                const InputDecoration(
              labelText:
                  "Column name",
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
                "Cancel",
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final newName =
                    controller.text.trim();

                if (newName.isEmpty) {
                  return;
                }

                if (newName != oldName) {
                  final exists =
                      widget.table.columns.any(
                    (item) =>
                        item != column &&
                        item.name
                                .toLowerCase() ==
                            newName.toLowerCase(),
                  );

                  if (exists) {
                    return;
                  }
                }

                setState(() {
                  for (final row
                      in widget.table.rows) {
                    final value =
                        row.values[oldName] ??
                            '';

                    row.values.remove(
                      oldName,
                    );

                    row.values[newName] =
                        value;
                  }

                  column.name = newName;
                });

                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                "Save",
              ),
            ),
          ],
        );
      },
    ).then((_) {
      controller.dispose();
    });
  }

  void deleteColumn(
    TableColumnDefinition column,
  ) {
    if (widget.table.columns.length <= 1) {
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            "Delete Column",
          ),
          content: Text(
            'Delete column "${column.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                "Cancel",
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  widget.table.columns
                      .remove(column);

                  for (final row
                      in widget.table.rows) {
                    row.values.remove(
                      column.name,
                    );
                  }
                });

                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                "Delete",
              ),
            ),
          ],
        );
      },
    );
  }

  void renameTable() {
    final controller =
        TextEditingController(
      text: widget.table.name,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            "Rename Table",
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration:
                const InputDecoration(
              labelText:
                  "Table name",
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
                "Cancel",
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final name =
                    controller.text.trim();

                if (name.isEmpty) {
                  return;
                }

                setState(() {
                  widget.table.name =
                      name;
                });

                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                "Save",
              ),
            ),
          ],
        );
      },
    ).then((_) {
      controller.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final columns =
        widget.table.columns;

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
                "Rename Table",
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == "add_column") {
                addColumn();
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem<String>(
                  value: "add_column",
                  child: Text(
                    "Add Column",
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: columns.isEmpty
          ? const Center(
              child: Text(
                "No columns",
              ),
            )
          : widget.table.rows.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.table_chart_outlined,
                        size: 80,
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      const Text(
                        "Table is empty",
                        style:
                            TextStyle(
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      ElevatedButton.icon(
                        onPressed:
                            addRow,
                        icon:
                            const Icon(
                          Icons.add,
                        ),
                        label:
                            const Text(
                          "Add Row",
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection:
                      Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns:
                          columns.map(
                        (column) {
                          return DataColumn(
                            label: InkWell(
                              onTap: () {
                                renameColumn(
                                  column,
                                );
                              },
                              child:
                                  Row(
                                children: [
                                  Text(
                                    column.name,
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 6,
                                  ),
                                  const Icon(
                                    Icons.edit,
                                    size: 15,
                                  ),
                                ],
                              ),
                            ),
                            onSort:
                                null,
                          );
                        },
                      ).toList()
                        ..add(
                          const DataColumn(
                            label:
                                Text(
                              "Actions",
                            ),
                          ),
                        ),
                      rows:
                          List.generate(
                        widget.table.rows.length,
                        (rowIndex) {
                          final row =
                              widget.table.rows[
                                  rowIndex];

                          return DataRow(
                            cells:
                                columns.map(
                              (column) {
                                final value =
                                    row.values[
                                            column.name] ??
                                        '';

                                final isPassword =
                                    column.name
                                        .toLowerCase()
                                        .contains(
                                          "password",
                                        );

                                return DataCell(
                                  SizedBox(
                                    width: 150,
                                    child:
                                        Text(
                                      isPassword &&
                                              value.isNotEmpty
                                          ? "••••••••"
                                          : value,
                                      overflow:
                                          TextOverflow.ellipsis,
                                    ),
                                  ),
                                  onTap: () {
                                    editRow(
                                      row,
                                    );
                                  },
                                );
                              },
                            ).toList()
                              ..add(
                                DataCell(
                                  Row(
                                    mainAxisSize:
                                        MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed:
                                            () {
                                          editRow(
                                            row,
                                          );
                                        },
                                        icon:
                                            const Icon(
                                          Icons.edit,
                                        ),
                                        tooltip:
                                            "Edit",
                                      ),
                                      IconButton(
                                        onPressed:
                                            () {
                                          deleteRow(
                                            rowIndex,
                                          );
                                        },
                                        icon:
                                            const Icon(
                                          Icons.delete_outline,
                                        ),
                                        tooltip:
                                            "Delete",
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: addRow,
        icon: const Icon(
          Icons.add,
        ),
        label: const Text(
          "Add Row",
        ),
      ),
    );
  }
}
