import 'package:sqflite/sqflite.dart';

import '../models/table_column_definition.dart';
import '../models/table_row_data.dart';
import '../models/tree_item.dart';
import 'app_database.dart';

class VaultRepository {
  final AppDatabase _appDatabase;

  VaultRepository({
    AppDatabase? appDatabase,
  }) : _appDatabase = appDatabase ?? AppDatabase.instance;

  Future<Database> get _db => _appDatabase.database;

  // ---------------------------------------------------------------------------
  // Tree Items
  // ---------------------------------------------------------------------------

  Future<int> createFolder({
    required String name,
    int? parentId,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;

    return db.insert(
      'tree_items',
      {
        'parent_id': parentId,
        'name': name,
        'type': 'folder',
        'created_at': now,
        'updated_at': now,
      },
    );
  }

  Future<int> createTable({
    required String name,
    int? parentId,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;

    return db.insert(
      'tree_items',
      {
        'parent_id': parentId,
        'name': name,
        'type': 'table',
        'created_at': now,
        'updated_at': now,
      },
    );
  }

  Future<List<TreeItem>> getChildren(int? parentId) async {
    final db = await _db;

    final rows = await db.query(
      'tree_items',
      where: parentId == null ? 'parent_id IS NULL' : 'parent_id = ?',
      whereArgs: parentId == null ? null : [parentId],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows.map(_treeItemFromMap).toList();
  }

  Future<TreeItem?> getTreeItem(int id) async {
    final db = await _db;

    final rows = await db.query(
      'tree_items',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return _treeItemFromMap(rows.first);
  }

  Future<void> renameTreeItem({
    required int id,
    required String name,
  }) async {
    final db = await _db;

    await db.update(
      'tree_items',
      {
        'name': name,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTreeItem(int id) async {
    final db = await _db;

    await db.transaction((txn) async {
      await _deleteTreeItemRecursive(txn, id);
    });
  }

  Future<void> _deleteTreeItemRecursive(
    DatabaseExecutor db,
    int id,
  ) async {
    final children = await db.query(
      'tree_items',
      columns: ['id', 'type'],
      where: 'parent_id = ?',
      whereArgs: [id],
    );

    for (final child in children) {
      final childId = child['id'] as int;
      final childType = child['type'] as String;

      if (childType == 'folder') {
        await _deleteTreeItemRecursive(db, childId);
      } else {
        await _deleteTableData(db, childId);
      }
    }

    await db.delete(
      'tree_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // Table / Records
  // ---------------------------------------------------------------------------

  Future<int> createRecord({
    required int tableItemId,
    required TableRowData row,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;

    return db.transaction((txn) async {
      final rowId = await txn.insert(
        'table_rows',
        {
          'table_item_id': tableItemId,
          'created_at': now,
          'updated_at': now,
        },
      );

      for (var i = 0; i < row.columns.length; i++) {
        final column = row.columns[i];
        final fieldId = await txn.insert(
          'table_fields',
          {
            'row_id': rowId,
            'name': column.name,
            'position': i,
            'created_at': now,
            'updated_at': now,
          },
        );

        await txn.insert(
          'table_values',
          {
            'field_id': fieldId,
            'value': row.values[column.fieldId] ?? '',
          },
        );
      }

      return rowId;
    });
  }

  Future<List<TableRowData>> getRecords(int tableItemId) async {
    final db = await _db;

    final rows = await db.query(
      'table_rows',
      where: 'table_item_id = ?',
      whereArgs: [tableItemId],
      orderBy: 'id ASC',
    );

    final result = <TableRowData>[];

    for (final row in rows) {
      final rowId = row['id'] as int;
      final fields = await db.query(
        'table_fields',
        where: 'row_id = ?',
        whereArgs: [rowId],
        orderBy: 'position ASC',
      );

      final columns = <TableColumnDefinition>[];
      final values = <int, String>{};

      for (final field in fields) {
        final fieldId = field['id'] as int;
        final fieldName = field['name'] as String;

        columns.add(
          TableColumnDefinition(
            fieldName,
            fieldId: fieldId,
          ),
        );

        final valueRows = await db.query(
          'table_values',
          where: 'field_id = ?',
          whereArgs: [fieldId],
          limit: 1,
        );

        values[fieldId] = valueRows.isEmpty
            ? ''
            : valueRows.first['value'] as String;
      }

      result.add(
        TableRowData(
          columns: columns,
          values: values,
        ),
      );
    }

    return result;
  }

  Future<void> updateRecord({
    required int rowId,
    required TableRowData row,
  }) async {
    final db = await _db;

    await db.transaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;

      await txn.update(
        'table_rows',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [rowId],
      );

      final oldFields = await txn.query(
        'table_fields',
        columns: ['id'],
        where: 'row_id = ?',
        whereArgs: [rowId],
      );

      for (final field in oldFields) {
        final fieldId = field['id'] as int;
        await txn.delete(
          'table_values',
          where: 'field_id = ?',
          whereArgs: [fieldId],
        );
      }

      await txn.delete(
        'table_fields',
        where: 'row_id = ?',
        whereArgs: [rowId],
      );

      for (var i = 0; i < row.columns.length; i++) {
        final column = row.columns[i];
        final value = row.values[column.fieldId] ?? '';

        final fieldId = await txn.insert(
          'table_fields',
          {
            'row_id': rowId,
            'name': column.name,
            'position': i,
            'created_at': now,
            'updated_at': now,
          },
        );

        await txn.insert(
          'table_values',
          {
            'field_id': fieldId,
            'value': value,
          },
        );
      }
    });
  }

  Future<void> deleteRecord(int rowId) async {
    final db = await _db;

    await db.transaction((txn) async {
      final fields = await txn.query(
        'table_fields',
        columns: ['id'],
        where: 'row_id = ?',
        whereArgs: [rowId],
      );

      for (final field in fields) {
        final fieldId = field['id'] as int;
        await txn.delete(
          'table_values',
          where: 'field_id = ?',
          whereArgs: [fieldId],
        );
      }

      await txn.delete(
        'table_fields',
        where: 'row_id = ?',
        whereArgs: [rowId],
      );

      await txn.delete(
        'table_rows',
        where: 'id = ?',
        whereArgs: [rowId],
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Table Data Deletion
  // ---------------------------------------------------------------------------

  Future<void> _deleteTableData(
    DatabaseExecutor db,
    int tableItemId,
  ) async {
    final rows = await db.query(
      'table_rows',
      columns: ['id'],
      where: 'table_item_id = ?',
      whereArgs: [tableItemId],
    );

    for (final row in rows) {
      final rowId = row['id'] as int;

      final fields = await db.query(
        'table_fields',
        columns: ['id'],
        where: 'row_id = ?',
        whereArgs: [rowId],
      );

      for (final field in fields) {
        final fieldId = field['id'] as int;

        await db.delete(
          'table_values',
          where: 'field_id = ?',
          whereArgs: [fieldId],
        );
      }

      await db.delete(
        'table_fields',
        where: 'row_id = ?',
        whereArgs: [rowId],
      );
    }

    await db.delete(
      'table_rows',
      where: 'table_item_id = ?',
      whereArgs: [tableItemId],
    );
  }

  // ---------------------------------------------------------------------------
  // Mapping
  // ---------------------------------------------------------------------------

  TreeItem _treeItemFromMap(Map<String, Object?> map) {
    final id = map['id'] as int;
    final parentId = map['parent_id'] as int?;
    final name = map['name'] as String;
    final type = map['type'] as String;

    if (type == 'table') {
      return TreeItem.table(
        name,
        id: id,
        parentId: parentId,
      );
    }

    return TreeItem.folder(
      name,
      id: id,
      parentId: parentId,
    );
  }
}
