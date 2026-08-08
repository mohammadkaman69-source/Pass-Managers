import 'package:flutter/material.dart';

import '../models/tree_item.dart';
import 'table_page.dart';
import 'tree_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
  });

  @override
  State<HomePage> createState() =>
      _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<TreeItem> items = [];

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
              const SizedBox(
                height: 10,
              ),
            ],
          ),
        );
      },
    );
  }

  void createFolder() {
    final controller =
        TextEditingController();

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
                final name =
                    controller.text.trim();

                if (name.isEmpty) {
                  return;
                }

                setState(() {
                  items.add(
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
    ).then((_) {
      controller.dispose();
    });
  }

  void createTable() {
    final controller =
        TextEditingController();

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
                final name =
                    controller.text.trim();

                if (name.isEmpty) {
                  return;
                }

                setState(() {
                  items.add(
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
    ).then((_) {
      controller.dispose();
    });
  }

  void openItem(TreeItem item) {
    final index = items.indexOf(item);

    if (item.type == TreeItemType.table) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            return TablePage(
              table: item,
              onDelete: () {
                if (index >= 0 &&
                    index < items.length) {
                  items.removeAt(index);
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
              if (index >= 0 &&
                  index < items.length) {
                items.removeAt(index);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pass Managers',
        ),
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.folder_open,
                    size: 80,
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  const Text(
                    'No items created yet',
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
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
              padding:
                  const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder:
                  (context, index) {
                final item = items[index];

                final isTable =
                    item.type ==
                        TreeItemType.table;

                return Card(
                  child: ListTile(
                    leading: Icon(
                      isTable
                          ? Icons.table_chart
                          : Icons.folder,
                    ),
                    title: Text(
                      item.name,
                    ),
                    subtitle: isTable
                        ? Text(
                            '${item.rows.length} rows • '
                            '${item.columns.length} columns',
                          )
                        : null,
                    trailing: const Icon(
                      Icons.chevron_right,
                    ),
                    onTap: () {
                      openItem(item);
                    },
                  ),
                );
              },
            ),
      floatingActionButton:
          FloatingActionButton(
        onPressed: createItem,
        child: const Icon(
          Icons.add,
        ),
      ),
    );
  }
}
