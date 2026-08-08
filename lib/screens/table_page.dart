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
  // ------------------------------------------------------------
  // ADD RECORD
  // ------------------------------------------------------------

  void addRow() {
    setState(() {
      widget.table.rows.add(
        TableRowData(
          columns: widget.table.columns,
        ),
      );
    });
  }

  // ------------------------------------------------------------
  // EDIT RECORD
  // ------------------------------------------------------------

  void editRow(TableRowData row) {
    final controllers = <String, TextEditingController>{};

    for (final column in row.columns) {
      controllers[column.name] = TextEditingController(
        text: row.values[column.name] ?? '',
      );
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Edit Record"),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                children: row.columns.map(
                  (column) {
                    final isPassword = column.name
                        .toLowerCase()
                        .contains("password");

                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: 14,
                      ),
                      child: TextField(
                        controller:
                            controllers[column.name],
                        obscureText: isPassword,
                        decoration: InputDecoration(
                          labelText: column.name,
                          border:
                              const OutlineInputBorder(),
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
                Navigator.pop(dialogContext);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                for (final column in row.columns) {
                  row.values[column.name] =
                      controllers[column.name]!.text;
                }

                Navigator.pop(dialogContext);

                setState(() {});
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    ).then((_) {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    });
  }

  // ------------------------------------------------------------
  // DELETE RECORD
  // ------------------------------------------------------------

  void deleteRow(int index) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Delete Record"),
          content: const Text(
            "Are you sure you want to delete this record?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  widget.table.rows.removeAt(index);
                });

                Navigator.pop(dialogContext);
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------
  // ADD FIELD TO THIS RECORD ONLY
  // ------------------------------------------------------------

  void addColumn(TableRowData row) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Add Field"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: "Field name",
              hintText: "Example: Volume",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();

                if (name.isEmpty) {
                  return;
                }

                final exists = row.columns.any(
                  (column) =>
                      column.name.toLowerCase() ==
                      name.toLowerCase(),
                );

                if (exists) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        "A field with this name already exists in this record.",
                      ),
                    ),
                  );
                  return;
                }

                setState(() {
                  row.columns.add(
                    TableColumnDefinition(name),
                  );

                  row.values[name] = '';
                });

                Navigator.pop(dialogContext);
              },
              child: const Text("Add Field"),
            ),
          ],
        );
      },
    ).then((_) {
      controller.dispose();
    });
  }

  // ------------------------------------------------------------
  // RENAME FIELD IN THIS RECORD ONLY
  // ------------------------------------------------------------

  void renameColumn(
    TableRowData row,
    TableColumnDefinition column,
  ) {
    final oldName = column.name;

    final controller = TextEditingController(
      text: oldName,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Rename Field"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: "Field name",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = controller.text.trim();

                if (newName.isEmpty) {
                  return;
                }

                if (newName != oldName) {
                  final exists = row.columns.any(
                    (item) =>
                        item != column &&
                        item.name.toLowerCase() ==
                            newName.toLowerCase(),
                  );

                  if (exists) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          "A field with this name already exists in this record.",
                        ),
                      ),
                    );
                    return;
                  }
                }

                setState(() {
                  final value =
                      row.values[oldName] ?? '';

                  row.values.remove(oldName);
                  row.values[newName] = value;

                  column.name = newName;
                });

                Navigator.pop(dialogContext);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    ).then((_) {
      controller.dispose();
    });
  }

  // ------------------------------------------------------------
  // DELETE FIELD FROM THIS RECORD ONLY
  // ------------------------------------------------------------

  void deleteColumn(
    TableRowData row,
    TableColumnDefinition column,
  ) {
    if (row.columns.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "At least one field must remain in this record.",
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Delete Field"),
          content: Text(
            'Delete field "${column.name}" from this record?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  final columnName = column.name;

                  row.columns.remove(column);
                  row.values.remove(columnName);
                });

                Navigator.pop(dialogContext);
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------
  // MOVE FIELD IN THIS RECORD ONLY
  // ------------------------------------------------------------

  void moveColumn(
    TableRowData row,
    TableColumnDefinition column,
    int newIndex,
  ) {
    final columns = row.columns;

    final oldIndex = columns.indexOf(column);

    if (oldIndex == -1) {
      return;
    }

    if (newIndex < 0 || newIndex >= columns.length) {
      return;
    }

    if (oldIndex == newIndex) {
      return;
    }

    setState(() {
      columns.removeAt(oldIndex);
      columns.insert(newIndex, column);
    });
  }

  // ------------------------------------------------------------
  // FIELD MENU
  // ------------------------------------------------------------

  void showColumnMenu(
    TableRowData row,
    TableColumnDefinition column,
  ) {
    final index = row.columns.indexOf(column);

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text("Rename Field"),
                onTap: () {
                  Navigator.pop(sheetContext);

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
                title: const Text("Move Up"),
                onTap: index > 0
                    ? () {
                        Navigator.pop(sheetContext);

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
                enabled:
                    index < row.columns.length - 1,
                title: const Text("Move Down"),
                onTap:
                    index < row.columns.length - 1
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
                title: const Text("Delete Field"),
                onTap: () {
                  Navigator.pop(sheetContext);

                  deleteColumn(
                    row,
                    column,
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // RENAME TABLE
  // ------------------------------------------------------------

  void renameTable() {
    final controller = TextEditingController(
      text: widget.table.name,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Rename Table"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: "Table name",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();

                if (name.isEmpty) {
                  return;
                }

                setState(() {
                  widget.table.name = name;
                });

                Navigator.pop(dialogContext);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    ).then((_) {
      controller.dispose();
    });
  }

  // ------------------------------------------------------------
  // RECORD CARD
  // ------------------------------------------------------------

  Widget buildRowCard(
    TableRowData row,
    int rowIndex,
  ) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      child: Padding(
        padding: const EdgeInsets.only(
          top: 8,
          bottom: 8,
        ),
        child: Column(
          children: [
            ...row.columns.map(
              (column) {
                final value =
                    row.values[column.name] ?? '';

                final isPassword = column.name
                    .toLowerCase()
                    .contains("password");

                final displayValue =
                    isPassword && value.isNotEmpty
                        ? "••••••••"
                        : value.isEmpty
                            ? "—"
                            : value;

                return InkWell(
                  onTap: () {
                    editRow(row);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: Text(
                            column.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
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
                            textAlign: TextAlign.end,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            showColumnMenu(
                              row,
                              column,
                            );
                          },
                          icon: const Icon(
                            Icons.more_vert,
                            size: 20,
                          ),
                          tooltip: "Field options",
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      editRow(row);
                    },
                    icon: const Icon(
                      Icons.edit,
                    ),
                    label: const Text("Edit"),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      deleteRow(rowIndex);
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                    ),
                    label: const Text("Delete"),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      addColumn(row);
                    },
                    icon: const Icon(
                      Icons.add_box_outlined,
                    ),
                    label: const Text("Add Field"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
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
            tooltip: "Rename Table",
          ),
        ],
      ),
      body: widget.table.rows.isEmpty
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.table_chart_outlined,
                      size: 80,
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    const Text(
                      "No records yet",
                      style: TextStyle(
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    ElevatedButton.icon(
                      onPressed: addRow,
                      icon: const Icon(
                        Icons.add,
                      ),
                      label: const Text(
                        "Add Record",
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                120,
              ),
              itemCount: widget.table.rows.length,
              itemBuilder: (context, index) {
                return buildRowCard(
                  widget.table.rows[index],
                  index,
                );
              },
            ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: addRow,
        icon: const Icon(
          Icons.add,
        ),
        label: const Text(
          "Add Record",
        ),
      ),
    );
  }
}
