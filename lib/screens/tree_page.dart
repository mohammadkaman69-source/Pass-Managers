import 'package:flutter/material.dart';


enum TreeItemType {

  folder,

  table,

}


class TableColumnDefinition {

  String name;


  TableColumnDefinition(
    this.name,
  );

}


class TreeItem {

  String name;

  final TreeItemType type;

  final List<TreeItem> children;

  final List<TableColumnDefinition> columns;


  TreeItem.folder(
    this.name,
  )   : type = TreeItemType.folder,
        children = [],
        columns = [];


  TreeItem.table(
    this.name,
  )   : type = TreeItemType.table,
        children = [],
        columns = [

          TableColumnDefinition(
            "Name",
          ),

          TableColumnDefinition(
            "IP",
          ),

          TableColumnDefinition(
            "Username",
          ),

          TableColumnDefinition(
            "Password",
          ),

          TableColumnDefinition(
            "Version",
          ),

          TableColumnDefinition(
            "Description",
          ),

        ];

}


class TreePage extends StatefulWidget {

  final TreeItem item;


  const TreePage({

    super.key,

    required this.item,

  });


  @override
  State<TreePage> createState() =>
      _TreePageState();

}


class _TreePageState extends State<TreePage> {


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

      builder: (context) {

        return AlertDialog(

          title: const Text(
            "Create Folder",
          ),

          content: TextField(

            controller: controller,

            autofocus: true,

            decoration:
                const InputDecoration(

              labelText:
                  "Folder name",

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

                final name =
                    controller.text.trim();


                if (name.isEmpty) {

                  return;

                }


                setState(() {

                  widget.item.children.add(

                    TreeItem.folder(
                      name,
                    ),

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


  void createTable() {

    final controller =
        TextEditingController();


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

            decoration:
                const InputDecoration(

              labelText:
                  "Table name",

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

                final name =
                    controller.text.trim();


                if (name.isEmpty) {

                  return;

                }


                setState(() {

                  widget.item.children.add(

                    TreeItem.table(
                      name,
                    ),

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


  void openItem(TreeItem item) {

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

      setState(() {});

    });

  }


  void renameItem() {

    final controller =
        TextEditingController(
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

            controller:
                controller,

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

                final name =
                    controller.text.trim();


                if (name.isEmpty) {

                  return;

                }


                setState(() {

                  widget.item.name =
                      name;

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


  void deleteItem() {

    Navigator.pop(
      context,
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

          IconButton(

            onPressed:
                renameItem,

            icon: const Icon(
              Icons.edit,
            ),

            tooltip:
                "Rename",

          ),

        ],

      ),


      body:

          widget.item.children.isEmpty

              ? Center(

                  child: Column(

                    mainAxisSize:
                        MainAxisSize.min,

                    children: [

                      Icon(

                        widget.item.type ==
                                TreeItemType.folder

                            ? Icons.folder_open

                            : Icons.table_chart,

                        size: 80,

                      ),


                      const SizedBox(
                        height: 20,
                      ),


                      Text(

                        widget.item.type ==
                                TreeItemType.folder

                            ? "Folder is empty"

                            : "Table is empty",

                        style:
                            const TextStyle(
                          fontSize: 18,
                        ),

                      ),


                      const SizedBox(
                        height: 20,
                      ),


                      if (widget.item.type ==
                          TreeItemType.folder)

                        ElevatedButton.icon(

                          onPressed:
                              createItem,

                          icon:
                              const Icon(
                            Icons.add,
                          ),

                          label:
                              const Text(
                            "Create",
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

                        trailing:
                            const Icon(
                          Icons.chevron_right,
                        ),

                        onTap: () {

                          openItem(
                            child,
                          );

                        },

                      ),

                    );

                  },

                ),


      floatingActionButton:

          widget.item.type ==
                  TreeItemType.folder

              ? FloatingActionButton(

                  onPressed:
                      createItem,

                  child: const Icon(
                    Icons.add,
                  ),

                )

              : null,

    );

  }

}
