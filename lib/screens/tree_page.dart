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
  final Map<String, String> values;

  TableRowData({
    required List<TableColumnDefinition> columns,
  }) : values = {
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
          TableColumnDefinition("Name"),
          TableColumnDefinition("IP"),
          TableColumnDefinition("Username"),
          TableColumnDefinition("Password"),
          TableColumnDefinition("Version"),
          TableColumnDefinition("Description"),
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
  // ------------------------------------------------------------
  // CREATE ITEM
  // ------------------------------------------------------------

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
                  "Create Folder",
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
                  "Create Table",
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

  // ------------------------------------------------------------
  // CREATE FOLDER
  // ------------------------------------------------------------

  void createFolder() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Create Folder",
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: "Folder name",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                "Cancel",
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

                Navigator.pop(context);
              },
              child: const Text(
                "Create",
              ),
            ),
          ],
        );
      },
    ).then((_) {
      controller.dispose();
    });
  }

  // ------------------------------------------------------------
  // CREATE TABLE
  // ------------------------------------------------------------

  void createTable() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Create Table",
          ),
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
                Navigator.pop(context);
              },
              child: const Text(
                "Cancel",
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

                Navigator.pop(context);
              },
              child: const Text(
                "Create",
              ),
            ),
          ],
        );
      },
    ).then((_) {
      controller.dispose();
    });
  }

  // ------------------------------------------------------------
  // OPEN ITEM
  // ------------------------------------------------------------

  void openItem(TreeItem item) {
    if (item.type == TreeItemType.table) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            return TablePage(
              table: item,
              onDelete: () {
                final index =
                    widget.item.children.indexOf(item);

                if (index != -1) {
                  widget.item.children.removeAt(index);
                }
              },
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
            onDelete: () {
              final index =
                  widget.item.children.indexOf(item);

              if (index != -1) {
                widget.item.children.removeAt(index);
              }
            },
          );
        },
      ),
    ).then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  // ------------------------------------------------------------
  // RENAME ITEM
  // ------------------------------------------------------------

  void renameItem() {
    final controller = TextEditingController(
      text: widget.item.name,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Rename",
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                "Cancel",
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

                Navigator.pop(context);
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

  // ------------------------------------------------------------
  // DELETE FOLDER
  // ------------------------------------------------------------

  void deleteFolder() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            "Delete Folder",
          ),
          content: Text(
            'Delete "${widget.item.name}" and everything inside it?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                "Cancel",
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
                "Delete",
              ),
            ),
          ],
        );
      },
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
          widget.item.name,
        ),
        actions: [
          IconButton(
            onPressed: renameItem,
            icon: const Icon(
              Icons.edit,
            ),
            tooltip: "Rename",
          ),
          if (widget.onDelete != null)
            IconButton(
              onPressed: deleteFolder,
              icon: const Icon(
                Icons.delete_outline,
              ),
              tooltip: "Delete Folder",
            ),
        ],
      ),
      body: widget.item.children.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 80,
                    color: Theme.of(context)
                        .colorScheme
                        .primary,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Folder is empty",
                    style: TextStyle(
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
                      "Create",
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
                                "${child.rows.length} rows • ${child.columns.length} columns",
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
}  String name;

  final TreeItemType type;

  final List<TreeItem> children;

  // این لیست فقط الگوی اولیه جدول است.
  // رکوردها از آن کپی مستقل می‌گیرند.
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
          TableColumnDefinition("Name"),
          TableColumnDefinition("IP"),
          TableColumnDefinition("Username"),
          TableColumnDefinition("Password"),
          TableColumnDefinition("Version"),
          TableColumnDefinition("Description"),
        ],
        rows = [];
}

class TreePage extends StatefulWidget {
  final TreeItem item;

  const TreePage({
    super.key,
    required this.item,
  });

  @override
  State<TreePage> createState() => _TreePageState();
}

class _TreePageState extends State<TreePage> {
  // ------------------------------------------------------------
  // CREATE ITEM
  // ------------------------------------------------------------

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
                  "Create Folder",
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
                  "Create Table",
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

  // ------------------------------------------------------------
  // CREATE FOLDER
  // ------------------------------------------------------------

  void createFolder() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Create Folder",
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: "Folder name",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                "Cancel",
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

                Navigator.pop(context);
              },
              child: const Text(
                "Create",
              ),
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------
  // CREATE TABLE
  // ------------------------------------------------------------

  void createTable() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Create Table",
          ),
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
                Navigator.pop(context);
              },
              child: const Text(
                "Cancel",
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

                Navigator.pop(context);
              },
              child: const Text(
                "Create",
              ),
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------
  // OPEN ITEM
  // ------------------------------------------------------------

  void openItem(TreeItem item) {
    if (item.type == TreeItemType.table) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            return TablePage(
              table: item,
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
          );
        },
      ),
    ).then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  // ------------------------------------------------------------
  // RENAME ITEM
  // ------------------------------------------------------------

  void renameItem() {
    final controller = TextEditingController(
      text: widget.item.name,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Rename",
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                "Cancel",
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

                Navigator.pop(context);
              },
              child: const Text(
                "Save",
              ),
            ),
          ],
        );
      },
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
          widget.item.name,
        ),
        actions: [
          IconButton(
            onPressed: renameItem,
            icon: const Icon(
              Icons.edit,
            ),
            tooltip: "Rename",
          ),
        ],
      ),
      body: widget.item.children.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 80,
                    color: Theme.of(context)
                        .colorScheme
                        .primary,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Folder is empty",
                    style: TextStyle(
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
                      "Create",
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
                                "${child.rows.length} rows • ${child.columns.length} default columns",
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
