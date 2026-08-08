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
      controllers[column.name] = TextEditingController(
        text: row.values[column.name] ?? '',
      );
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Edit Row"),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                children: widget.table.columns.map(
                  (column) {
                    final controller = controllers[column.name]!;

                    final isPassword = column.name
                        .toLowerCase()
                        .contains("password");

                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: 14,
                      ),
                      child: TextField(
                        controller: controller,
                        obscureText: isPassword,
                        decoration: InputDecoration(
                          labelText: column.name,
                          border: const OutlineInputBorder(),
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
                for (final column in widget.table.columns) {
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

  void deleteRow(int index) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Delete Row"),
          content: const Text(
            "Are you sure you want to delete this row?",
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

  void addColumn() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Add Column"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: "Column name",
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

                final exists = widget.table.columns.any(
                  (column) =>
                      column.name.toLowerCase() ==
                      name.toLowerCase(),
                );

                if (exists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "A column with this name already exists.",
                      ),
                    ),
                  );
                  return;
                }

                setState(() {
                  widget.table.columns.add(
                    TableColumnDefinition(name),
                  );

                  for (final row in widget.table.rows) {
                    row.values[name] = '';
                  }
                });

                Navigator.pop(dialogContext);
              },
              child: const Text("Add"),
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

    final controller = TextEditingController(
      text: oldName,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Rename Column"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: "Column name",
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
                  final exists = widget.table.columns.any(
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
                          "A column with this name already exists.",
                        ),
                      ),
                    );
                    return;
                  }
                }

                setState(() {
                  for (final row in widget.table.rows) {
                    final value = row.values[oldName] ?? '';

                    row.values.remove(oldName);
                    row.values[newName] = value;
                  }

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

  void deleteColumn(
    TableColumnDefinition column,
  ) {
    if (widget.table.columns.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "At least one column must remain.",
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Delete Column"),
          content: Text(
            'Delete column "${column.name}"?',
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
                  widget.table.columns.remove(column);

                  for (final row in widget.table.rows) {
                    row.values.remove(column.name);
                  }
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

  void moveColumn(
    TableColumnDefinition column,
    int newIndex,
  ) {
    final columns = widget.table.columns;

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

  void showColumnMenu(
    TableColumnDefinition column,
  ) {
    final index = widget.table.columns.indexOf(column);

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
                  renameColumn(column);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_upward),
                enabled: index > 0,
                title: const Text("Move Up"),
                onTap: index > 0
                    ? () {
                        Navigator.pop(sheetContext);
                        moveColumn(
                          column,
                          index - 1,
                        );
                      }
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.arrow_downward),
                enabled:
                    index <
                    widget.table.columns.length - 1,
                title: const Text("Move Down"),
                onTap:
                    index <
                            widget.table.columns.length - 1
                        ? () {
                            Navigator.pop(sheetContext);
                            moveColumn(
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

  Widget buildFieldRow(
    TableColumnDefinition column,
    String value,
  ) {
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
        if (widget.table.rows.isNotEmpty) {
          editRow(widget.table.rows.first);
        }
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
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: Text(
                displayValue,
                textAlign: TextAlign.end,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () {
                showColumnMenu(column);
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
  }

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
            ...widget.table.columns.map(
              (column) {
                final value =
                    row.values[column.name] ?? '';

                final isPassword =
                    column.name
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
                    padding:
                        const EdgeInsets.symmetric(
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
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
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
                                TextAlign.end,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            showColumnMenu(
                              column,
                            );
                          },
                          icon: const Icon(
                            Icons.more_vert,
                            size: 20,
                          ),
                          tooltip:
                              "Field options",
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const Divider(height: 1),
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 8,
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      editRow(row);
                    },
                    icon: const Icon(
                      Icons.edit,
                    ),
                    label:
                        const Text("Edit"),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      deleteRow(rowIndex);
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                    ),
                    label:
                        const Text("Delete"),
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
    final columns = widget.table.columns;

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
                    "Add Field",
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
                "No fields",
              ),
            )
          : widget.table.rows.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.all(24),
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
                            "Add Row",
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.all(16),
                  itemCount:
                      widget.table.rows.length,
                  itemBuilder:
                      (context, index) {
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
          "Add Row",
        ),
      ),
    );
  }
}
