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
              on
