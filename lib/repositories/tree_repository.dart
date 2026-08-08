import '../database/app_database.dart';
import '../models/tree_item.dart';

class TreeRepository {
  final AppDatabase _database;

  TreeRepository({
    AppDatabase? database,
  }) : _database =
            database ?? AppDatabase.instance;

  Future<int> createFolder({
    int? parentId,
    required String name,
  }) async {
    final db = await _database.database;

    final now =
        DateTime.now().millisecondsSinceEpoch;

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
    int? parentId,
    required String name,
  }) async {
    final db = await _database.database;

    final now =
        DateTime.now().millisecondsSinceEpoch;

    final tableId = await db.insert(
      'tree_items',
      {
        'parent_id': parentId,
        'name': name,
        'type': 'table',
        'created_at': now,
        'updated_at': now,
      },
    );

    return tableId;
  }

  Future<List<Map<String, dynamic>>> getItems({
    int? parentId,
  }) async {
    final db = await _database.database;

    if (parentId == null) {
      return db.query(
        'tree_items',
        where: 'parent_id IS NULL',
        orderBy: 'name COLLATE NOCASE ASC',
      );
    }

    return db.query(
      'tree_items',
      where: 'parent_id = ?',
      whereArgs: [parentId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
  }

  Future<void> renameItem({
    required int id,
    required String name,
  }) async {
    final db = await _database.database;

    final now =
        DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'tree_items',
      {
        'name': name,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteItem(
    int id,
  ) async {
    final db = await _database.database;

    await db.transaction(
      (txn) async {
        await _deleteChildren(
          txn,
          id,
        );

        await txn.delete(
          'tree_items',
          where: 'id = ?',
          whereArgs: [id],
        );
      },
    );
  }

  Future<void> _deleteChildren(
    dynamic txn,
    int parentId,
  ) async {
    final children =
        await txn.query(
      'tree_items',
      columns: ['id', 'type'],
      where: 'parent_id = ?',
      whereArgs: [parentId],
    );

    for (final child in children) {
      final childId =
          child['id'] as int;

      final childType =
          child['type'] as String;

      if (childType == 'folder') {
        await _deleteChildren(
          txn,
          childId,
        );
      } else if (childType == 'table') {
        await _deleteTableData(
          txn,
          childId,
        );
      }

      await txn.delete(
        'tree_items',
        where: 'id = ?',
        whereArgs: [childId],
      );
    }
  }

  Future<void> _deleteTableData(
    dynamic txn,
    int tableId,
  ) async {
    final rows =
        await txn.query(
      'table_rows',
      columns: ['id'],
      where: 'table_item_id = ?',
      whereArgs: [tableId],
    );

    for (final row in rows) {
      final rowId =
          row['id'] as int;

      final fields =
          await txn.query(
        'table_fields',
        columns: ['id'],
        where: 'row_id = ?',
        whereArgs: [rowId],
      );

      for (final field in fields) {
        final fieldId =
            field['id'] as int;

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
    }

    await txn.delete(
      'table_rows',
      where: 'table_item_id = ?',
      whereArgs: [tableId],
    );
  }

  Future<void> deleteAll() async {
    final db = await _database.database;

    await db.transaction(
      (txn) async {
        await txn.delete(
          'table_values',
        );

        await txn.delete(
          'table_fields',
        );

        await txn.delete(
          'table_rows',
        );

        await txn.delete(
          'tree_items',
        );
      },
    );
  }
}
