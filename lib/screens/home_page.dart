import 'package:flutter/material.dart';

import '../models/tree_item.dart';
import '../repositories/tree_repository.dart';
import 'table_page.dart';
import 'tree_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TreeRepository _repository = TreeRepository();

  final List<TreeItem> items = [];

  final Map<TreeItem, int> _itemIds = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final rows = await _repository.getItems();

      final loadedItems = <TreeItem>[];
      final loadedIds = <TreeItem, int>{};

      for (final row in rows) {
        final id = row['id'] as int;
        final name = row['name'] as String;
        final type = row['type'] as String;

        final item = type == 'table'
            ? TreeItem.table(
                name,
                id: id,
              )
            : TreeItem.folder(
                name,
                id: id,
              );

        loadedItems.add(item);
        loadedIds[item] = id;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        items
          ..clear()
          ..addAll(loadedItems);

        _itemIds
          ..clear()
          ..addAll(loadedIds);

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _showError(
        'Failed to load data: $error',
      );
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void createItem() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
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
                  Navigator.pop(sheetContext);
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
                  Navigator.pop(sheetContext);
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

  Future<String?> _askName({
    required String title,
    required String label,
    String? initialValue,
  }) async {
    final controller = TextEditingController(
      text: initialValue ?? '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) {
              final value = controller.text.trim();

              if (value.isNotEmpty) {
                Navigator.pop(
                  dialogContext,
                  value,
                );
              }
            },
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
                final value = controller.text.trim();

                if (value.isEmpty) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  value,
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    return result;
  }

  Future<void> createFolder() async {
    final name = await _askName(
      title: 'Create Folder',
      label: 'Folder name',
    );

    if (name == null || name.isEmpty) {
      return;
    }

    try {
      final id = await _repository.createFolder(
        name: name,
      );

      if (!mounted) {
        return;
      }

      final item = TreeItem.folder(
        name,
        id: id,
      );

      setState(() {
        items.add(item);
        _itemIds[item] = id;
      });
    } catch (error) {
      _showError(
        'Failed to create folder: $error',
      );
    }
  }

  Future<void> createTable() async {
    final name = await _askName(
      title: 'Create Table',
      label: 'Table name',
    );

    if (name == null || name.isEmpty) {
      return;
    }

    try {
      final id = await _repository.createTable(
        name: name,
      );

      if (!mounted) {
        return;
      }

      final item = TreeItem.table(
        name,
        id: id,
      );

      setState(() {
        items.add(item);
        _itemIds[item] = id;
      });
    } catch (error) {
      _showError(
        'Failed to create table: $error',
      );
    }
  }

  Future<void> renameItem(
    TreeItem item,
  ) async {
    final id = _itemIds[item];

    if (id == null) {
      return;
    }

    final name = await _askName(
      title: 'Rename',
      label: 'Name',
      initialValue: item.name,
    );

    if (name == null || name.isEmpty) {
      return;
    }

    try {
      await _repository.renameItem(
        id: id,
        name: name,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        item.name = name;
      });
    } catch (error) {
      _showError(
        'Failed to rename item: $error',
      );
    }
  }

  Future<void> deleteItem(
    TreeItem item,
  ) async {
    final id = _itemIds[item];

    if (id == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete'),
          content: Text(
            'Delete "${item.name}" and everything inside it?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _repository.deleteItem(id);

      if (!mounted) {
        return;
      }

      setState(() {
        items.remove(item);
        _itemIds.remove(item);
      });
    } catch (error) {
      _showError(
        'Failed to delete item: $error',
      );
    }
  }

  void showItemMenu(
    TreeItem item,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Rename'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  renameItem(item);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                ),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  deleteItem(item);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void openItem(TreeItem item) {
    final id = _itemIds[item];

    if (id == null) {
      return;
    }

    if (item.type == TreeItemType.table) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) {
            return TablePage(
              table: item,
              tableId: id,
              onDelete: () {
                if (!mounted) {
                  return;
                }

                setState(() {
                  items.remove(item);
                  _itemIds.remove(item);
                });
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
        builder: (_) {
          return TreePage(
            item: item,
            itemId: id,
            onDelete: () async {
              await _repository.deleteItem(id);

              if (!mounted) {
                return;
              }

              setState(() {
                items.remove(item);
                _itemIds.remove(item);
              });
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.folder_open,
                        size: 80,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'No items created yet',
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: createItem,
                        icon: const Icon(Icons.add),
                        label: const Text('Create'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];

                    final isTable =
                        item.type == TreeItemType.table;

                    return Card(
                      child: ListTile(
                        leading: Icon(
                          isTable
                              ? Icons.table_chart
                              : Icons.folder,
                        ),
                        title: Text(item.name),
                        subtitle: isTable
                            ? Text(
                                '${item.rows.length} rows • '
                                '${item.columns.length} columns',
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () {
                                showItemMenu(item);
                              },
                              icon: const Icon(
                                Icons.more_vert,
                              ),
                              tooltip: 'Options',
                            ),
                            const Icon(
                              Icons.chevron_right,
                            ),
                          ],
                        ),
                        onTap: () {
                          openItem(item);
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: createItem,
        child: const Icon(Icons.add),
      ),
    );
  }
}
