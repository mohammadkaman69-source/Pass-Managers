import 'package:flutter/material.dart';

import '../database/vault_repository.dart';
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
final VaultRepository _repository =
VaultRepository();

final List<TreeItem> items = [];

bool _isLoading = true;

@override
void initState() {
super.initState();

_loadItems();

}

Future<void> _loadItems() async {
try {
final loadedItems =
await _repository.getChildren(null);

  if (!mounted) {
    return;
  }

  setState(() {
    items
      ..clear()
      ..addAll(loadedItems);

    _isLoading = false;
  });
} catch (e) {
  if (!mounted) {
    return;
  }

  setState(() {
    _isLoading = false;
  });

  ScaffoldMessenger.of(context)
      .showSnackBar(
    SnackBar(
      content: Text(
        'Failed to load vault: $e',
      ),
    ),
  );
}

}

Future<void> _createFolder(
String name,
) async {
final id =
await _repository.createFolder(
name: name,
);

final folder = TreeItem.folder(
  name,
  id: id,
  parentId: null,
);

if (!mounted) {
  return;
}

setState(() {
  items.add(folder);
});

}

Future<void> _createTable(
String name,
) async {
final id =
await _repository.createTable(
name: name,
);

final table = TreeItem.table(
  name,
  id: id,
  parentId: null,
);

if (!mounted) {
  return;
}

setState(() {
  items.add(table);
});

}

Future<void> _deleteItem(
TreeItem item,
) async {
final id = item.id;

if (id == null) {
  return;
}

await _repository.deleteTreeItem(id);

if (!mounted) {
  return;
}

setState(() {
  items.remove(item);
});

}

void createItem() {
showModalBottomSheet(
context: context,
builder: (context) {
return SafeArea(
child: Column(
mainAxisSize:
MainAxisSize.min,
children: [
ListTile(
leading: const Icon(
Icons
.create_new_folder_outlined,
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
        decoration:
            const InputDecoration(
          labelText: 'Folder name',
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
              await _createFolder(
                name,
              );

              if (!dialogContext.mounted) {
                return;
              }

              Navigator.pop(
                dialogContext,
              );
            } catch (e) {
              if (!mounted) {
                return;
              }

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                SnackBar(
                  content: Text(
                    'Failed to create folder: $e',
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
        decoration:
            const InputDecoration(
          labelText: 'Table name',
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
              await _createTable(
                name,
              );

              if (!dialogContext.mounted) {
                return;
              }

              Navigator.pop(
                dialogContext,
              );
            } catch (e) {
              if (!mounted) {
                return;
              }

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                SnackBar(
                  content: Text(
                    'Failed to create table: $e',
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
if (item.type ==
TreeItemType.table) {
Navigator.push(
context,
MaterialPageRoute(
builder: (context) {
return TablePage(
table: item,
onDelete: () async {
await deleteItem(item);
},
);
},
),
).then(() {
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
        onDelete: () async {
          await _deleteItem(item);
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
child:
CircularProgressIndicator(),
)
: items.isEmpty
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
onPressed:
createItem,
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
final item =
items[index];

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
                    trailing:
                        const Icon(
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
