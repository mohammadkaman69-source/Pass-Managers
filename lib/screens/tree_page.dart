import 'package:flutter/material.dart';
import 'table_page.dart';

enum TreeItemType {
  folder,
  table,
}

class TableColumnDefinition {
  String name;

  TableColumnDefinition(this.name);
}

class TableRowData {
  final List<TableColumnDefinition> columns;
  final Map<String, String> values;

  TableRowData({
    required List<TableColumnDefinition> columns,
  })  : columns = columns
            .map(
              (column) => TableColumnDefinition(column.name),
            )
            .toList(),
        values = {
          for (final column in columns) column.name: '',
        };
}

class TreeItem {
  String name;

  final TreeItemType type;
  final List<TreeItem> children;

  final List<TableColumnDefinition> columns;
  final List<TableRowData> rows;

  TreeItem.folder(
    this.name,
  )   : type = TreeItemType.folder,
        children = [],
        columns = [],
        rows = [];

  TreeItem.table(
    this.name,
  )   : type = TreeItemType.table,
        children = [],
        columns = [
          TableColumnDefinition('Name'),
          TableColumnDefinition('IP'),
          TableColumnDefinition('Username'),
          TableColumnDefinition('Password'),
          TableColumnDefinition('Version'),
          TableColumnDefinition('Description'),
        ],
        rows = [];
}

class TreePage extends StatefulWidget {
  final TreeItem item;
  final VoidCallback? onDelete;

  const TreePage({
    super.key,
    required this.item,
    this.onDelete,
  });

  @override
  State<TreePage> createState() => _TreePageState();
}

class _TreePageState extends State<TreePage> {
  void createItem() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.create_new_folder_outlined,
                ),
                title: const Text(
                  'Create Folder',
                ),
                onTap: () {
                  Navigator.pop(context);
                  createFolder();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.table_chart_outlined,
                ),
                title: const Text(
                  'Create Table',
                ),
                onTap: () {
                  Navigator.pop(context);
                  createTable();
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void createFolder() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Create Folder',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Folder name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();

                if (name.isEmpty) {
                  return;
                }

                setState(() {
                  widget.item.children.add(
                    TreeItem.folder(name),
                  );
                });

                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Create',
              ),
            ),
          ],
        );
      },
    );
  }

  void createTable() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Create Table',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Table name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();

                if (name.isEmpty) {
                  return;
                }

                setState(() {
                  widget.item.children.add(
                    TreeItem.table(name),
                  );
                });

                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Create',
              ),
            ),
          ],
        );
      },
    );
  }

  void openItem(TreeItem item) {
    final index = widget.item.children.indexOf(item);

    void removeItem() {
      if (index >= 0 &&
          index < widget.item.children.length &&
          identical(widget.item.children[index], item)) {
        widget.item.children.removeAt(index);
      }
    }

    if (item.type == TreeItemType.table) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            return TablePage(
              table: item,
              onDelete: removeItem,
            );
          },
        ),
      ).then((_) {
        if (mounted) {
          setState(() {});
        }
      });

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return TreePage(
            item: item,
            onDelete: removeItem,
          );
        },
      ),
    ).then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void renameItem() {
    final controller = TextEditingController(
      text: widget.item.name,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Rename',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();

                if (name.isEmpty) {
                  return;
                }

                setState(() {
                  widget.item.name = name;
                });

                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Save',
              ),
            ),
          ],
        );
      },
    );
  }

  void deleteCurrentItem() {
    final isFolder =
        widget.item.type == TreeItemType.folder;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            isFolder ? 'Delete Folder' : 'Delete Table',
          ),
          content: Text(
            isFolder
                ? 'Delete "${widget.item.name}" and everything inside it?'
                : 'Delete "${widget.item.name}" and all its records?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                widget.onDelete?.call();

                if (mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFolder =
        widget.item.type == TreeItemType.folder;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.item.name,
        ),
        actions: [
          IconButton(
            onPressed: renameItem,
            icon: const Icon(
              Icons.edit,
            ),
            tooltip: 'Rename',
          ),
          if (widget.onDelete != null)
            IconButton(
              onPressed: deleteCurrentItem,
              icon: const Icon(
                Icons.delete_outline,
              ),
              tooltip: isFolder
                  ? 'Delete Folder'
                  : 'Delete Table',
            ),
        ],
      ),
      body: widget.item.children.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFolder
                        ? Icons.folder_open
                        : Icons.table_chart_outlined,
                    size: 80,
                    color: Theme.of(context)
                        .colorScheme
                        .primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isFolder
                        ? 'Folder is empty'
                        : 'Table is empty',
                    style: const TextStyle(
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: createItem,
                    icon: const Icon(
                      Icons.add,
                    ),
                    label: const Text(
                      'Create',
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.item.children.length,
              itemBuilder: (context, index) {
                final child =
                    widget.item.children[index];

                return Card(
                  child: ListTile(
                    leading: Icon(
                      child.type ==
                              TreeItemType.folder
                          ? Icons.folder
                          : Icons.table_chart,
                    ),
                    title: Text(
                      child.name,
                    ),
                    subtitle:
                        child.type ==
                                TreeItemType.table
                            ? Text(
                                '${child.rows.length} rows • '
                                '${child.columns.length} columns',
                              )
                            : null,
                    trailing: const Icon(
                      Icons.chevron_right,
                    ),
                    onTap: () {
                      openItem(child);
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: createItem,
        child: const Icon(
          Icons.add,
        ),
      ),
    );
  }
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
          title: const Text("Edit Record"),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                children: widget.table.columns.map(
                  (column) {
                    final isPassword = column.name
                        .toLowerCase()
                        .contains("password");

                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: 14,
                      ),
                      child: TextField(
                        controller: controllers[column.name],
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
  // ADD FIELD
  // ------------------------------------------------------------

  void addColumn() {
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

                final exists = widget.table.columns.any(
                  (column) =>
                      column.name.toLowerCase() ==
                      name.toLowerCase(),
                );

                if (exists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "A field with this name already exists.",
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
  // RENAME FIELD
  // ------------------------------------------------------------

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
                  final exists = widget.table.columns.any(
                    (item) =>
                        item != column &&
                        item.name.toLowerCase() ==
                            newName.toLowerCase(),
                  );

                  if (exists) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "A field with this name already exists.",
                        ),
                      ),
                    );
                    return;
                  }
                }

                setState(() {
                  for (final row in widget.table.rows) {
                    final value =
                        row.values[oldName] ?? '';

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

  // ------------------------------------------------------------
  // DELETE FIELD
  // ------------------------------------------------------------

  void deleteColumn(
    TableColumnDefinition column,
  ) {
    if (widget.table.columns.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "At least one field must remain.",
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
            'Delete field "${column.name}"?',
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
                final columnName = column.name;

                setState(() {
                  widget.table.columns.remove(column);

                  for (final row in widget.table.rows) {
                    row.values.remove(columnName);
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
    // ------------------------------------------------------------
  // MOVE FIELD
  // ------------------------------------------------------------

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

  // ------------------------------------------------------------
  // FIELD MENU
  // ------------------------------------------------------------

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
  // DELETE TABLE
  // ------------------------------------------------------------

  void deleteTable() {
    if (widget.onDelete == null) {
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Delete Table"),
          content: Text(
            'Delete "${widget.table.name}" and all its records?',
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
                Navigator.pop(dialogContext);

                widget.onDelete?.call();

                if (mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
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
            ...widget.table.columns.map(
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
              },
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
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
                    onPressed: addColumn,
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
          if (widget.onDelete != null)
            IconButton(
              onPressed: deleteTable,
              icon: const Icon(
                Icons.delete_outline,
              ),
              tooltip: "Delete Table",
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == "add_field") {
                addColumn();
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem<String>(
                  value: "add_field",
                  child: Text(
                    "Add Field",
                  ),
                ),
              ];
            },
          ),
        ],
      ),
