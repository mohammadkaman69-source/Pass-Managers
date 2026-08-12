import 'package:flutter/material.dart';

import '../models/tree_item.dart';
import '../repositories/tree_repository.dart';
import '../services/pdf_export_service.dart';
import 'table_page.dart';

class TreePage extends StatefulWidget {
  final TreeItem item;

  final int? itemId;

  final VoidCallback? onDelete;

  const TreePage({
    super.key,
    required this.item,
    this.itemId,
    this.onDelete,
  });

  @override
  State<TreePage> createState() => _TreePageState();
}

class _TreePageState extends State<TreePage> {
  final TreeRepository _repository = TreeRepository();

  final PdfExportService _pdfExportService =
      PdfExportService();

  final Map<TreeItem, int> _itemIds = {};

  bool _isLoading = true;

  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    try {
      final rows = await _repository.getItems(
        parentId: widget.itemId,
      );

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
                parentId: widget.itemId,
              )
            : TreeItem.folder(
                name,
                id: id,
                parentId: widget.itemId,
              );

        loadedItems.add(item);
        loadedIds[item] = id;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        widget.item.children
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load folder: $error',
          ),
        ),
      );
    }
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
              onPressed: () async {
                final name = controller.text.trim();

                if (name.isEmpty) {
                  return;
                }

                try {
                  final id =
                      await _repository.createFolder(
                    parentId: widget.itemId,
                    name: name,
                  );

                  if (!mounted) {
                    return;
                  }

                  final item = TreeItem.folder(
                    name,
                    id: id,
                    parentId: widget.itemId,
                  );

                  setState(() {
                    widget.item.children.add(item);
                    _itemIds[item] = id;
                  });

                  if (!dialogContext.mounted) {
                    return;
                  }

                  Navigator.pop(dialogContext);
                } catch (error) {
                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to create folder: $error',
                      ),
                    ),
                  );
                }
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
              onPressed: () async {
                final name = controller.text.trim();

                if (name.isEmpty) {
                  return;
                }

                try {
                  final id =
                      await _repository.createTable(
                    parentId: widget.itemId,
                    name: name,
                  );

                  if (!mounted) {
                    return;
                  }

                  final item = TreeItem.table(
                    name,
                    id: id,
                    parentId: widget.itemId,
                  );

                  setState(() {
                    widget.item.children.add(item);
                    _itemIds[item] = id;
                  });

                  if (!dialogContext.mounted) {
                    return;
                  }

                  Navigator.pop(dialogContext);
                } catch (error) {
                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to create table: $error',
                      ),
                    ),
                  );
                }
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
    final itemId = _itemIds[item];

    if (itemId == null) {
      return;
    }

    final index =
        widget.item.children.indexOf(item);

    if (item.type == TreeItemType.table) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            return TablePage(
              table: item,
              tableId: itemId,
              onDelete: () {
                if (index >= 0 &&
                    index <
                        widget.item.children.length) {
                  widget.item.children.removeAt(index);
                }

                _itemIds.remove(item);
              },
            );
          },
        ),
      ).then((_) {
        if (!mounted) {
          return;
        }

        setState(() {});
      });

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return TreePage(
            item: item,
            itemId: itemId,
            onDelete: () {
              if (index >= 0 &&
                  index <
                      widget.item.children.length) {
                widget.item.children.removeAt(index);
              }

              _itemIds.remove(item);
            },
          );
        },
      ),
    ).then((_) {
      if (!mounted) {
        return;
      }

      setState(() {});
    });
  }

  Future<void> renameItem() async {
    final controller = TextEditingController(
      text: widget.item.name,
    );

    await showDialog(
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
              onPressed: () async {
                final name =
                    controller.text.trim();

                if (name.isEmpty) {
                  return;
                }

                try {
                  final id = widget.itemId;

                  if (id != null) {
                    await _repository.renameItem(
                      id: id,
                      name: name,
                    );
                  }

                  if (!mounted) {
                    return;
                  }

                  setState(() {
                    widget.item.name = name;
                  });

                  if (!dialogContext.mounted) {
                    return;
                  }

                  Navigator.pop(dialogContext);
                } catch (error) {
                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to rename folder: $error',
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

  Future<void> deleteFolder() async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Folder',
          ),
          content: Text(
            'Delete "${widget.item.name}" and everything inside it?',
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
      final id = widget.itemId;

      if (id != null) {
        await _repository.deleteItem(id);
      }

      if (!mounted) {
        return;
      }

      widget.onDelete?.call();

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete folder: $error',
          ),
        ),
      );
    }
  }

  Future<void> _exportPdf() async {
    if (_isExporting) {
      return;
    }

    final itemId = widget.itemId;

    if (itemId == null) {
      _showExportError(
        'شناسه این مورد برای Export PDF موجود نیست.',
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final completeTree =
          await _repository.getCompleteTree();

      if (!mounted) {
        return;
      }

      Map<String, dynamic>? target;

      void findNode(
        List<Map<String, dynamic>> nodes,
      ) {
        for (final node in nodes) {
          final nodeId = node['id'];

          if (nodeId == itemId) {
            target = node;
            return;
          }

          final children = node['children'];

          if (children is List) {
            final childNodes =
                <Map<String, dynamic>>[];

            for (final child in children) {
              if (child is Map<String, dynamic>) {
                childNodes.add(child);
              }
            }

            if (childNodes.isNotEmpty) {
              findNode(childNodes);

              if (target != null) {
                return;
              }
            }
          }
        }
      }

      findNode(completeTree);

      if (target == null) {
        throw StateError(
          'Export target was not found.',
        );
      }

      final file =
          await _pdfExportService.exportTree(
        root: target!,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PDF با موفقیت ساخته شد:\n${file.path}',
          ),
          duration:
              const Duration(seconds: 5),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showExportError(
        'خطا در ساخت PDF:\n$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  void _showExportError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.item.name,
        ),
        actions: [
          _isExporting
              ? const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  onPressed: _exportPdf,
                  icon: const Icon(
                    Icons.picture_as_pdf_outlined,
                  ),
                  tooltip: 'Export PDF',
                ),
          IconButton(
            onPressed: renameItem,
            icon: const Icon(
              Icons.edit,
            ),
            tooltip: 'Rename',
          ),
          if (widget.onDelete != null)
            IconButton(
              onPressed: deleteFolder,
              icon: const Icon(
                Icons.delete_outline,
              ),
              tooltip: 'Delete Folder',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : widget.item.children.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 80,
                        color: Theme.of(context)
                            .colorScheme
                            .primary,
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      const Text(
                        'Folder is empty',
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
                  itemCount:
                      widget.item.children.length,
                  itemBuilder:
                      (context, index) {
                    final child =
                        widget.item.children[
                            index];

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
                        subtitle: child.type ==
                                TreeItemType.table
                            ? Text(
                                '${child.rows.length} rows • '
                                '${child.columns.length} default columns',
                              )
                            : null,
                        trailing:
                            const Icon(
                          Icons.chevron_right,
                        ),
                        onTap: () {
                          openItem(child);
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
