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
