import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

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

  Future<List<Map<String, dynamic>>> getItems({
    int? parentId,
  }) async {
    final db = await _database.database;

    if (parentId == null) {
      return db.query(
        'tree_items',
        where: 'parent_id IS NULL',
        orderBy:
            'name COLLATE NOCASE ASC',
      );
    }

    return db.query(
      'tree_items',
      where: 'parent_id = ?',
      whereArgs: [parentId],
      orderBy:
          'name COLLATE NOCASE ASC',
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
        final item = await txn.query(
          'tree_items',
          columns: ['id', 'type'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );

        if (item.isEmpty) {
          return;
        }

        final type =
            item.first['type'] as String;

        if (type == 'folder') {
          await _deleteChildren(
            txn,
            id,
          );
        } else if (type == 'table') {
          await _deleteTableData(
            txn,
            id,
          );
        }

        await txn.delete(
          'tree_items',
          where: 'id = ?',
          whereArgs: [id],
        );
      },
    );
  }

  Future<void> _deleteChildren(
    Transaction txn,
    int parentId,
  ) async {
    final children = await txn.query(
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
    Transaction txn,
    int tableId,
  ) async {
    final rows = await txn.query(
      'table_rows',
      columns: ['id'],
      where: 'table_item_id = ?',
      whereArgs: [tableId],
    );

    for (final row in rows) {
      final rowId =
          row['id'] as int;

      final fields = await txn.query(
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

  Future<List<Map<String, dynamic>>> getRows(
    int tableId,
  ) async {
    final db = await _database.database;

    return db.query(
      'table_rows',
      where: 'table_item_id = ?',
      whereArgs: [tableId],
      orderBy: 'id ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getFields(
    int rowId,
  ) async {
    final db = await _database.database;

    return db.query(
      'table_fields',
      where: 'row_id = ?',
      whereArgs: [rowId],
      orderBy: 'position ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getValues(
    int fieldId,
  ) async {
    final db = await _database.database;

    return db.query(
      'table_values',
      where: 'field_id = ?',
      whereArgs: [fieldId],
      limit: 1,
    );
  }

  Future<int> createRow({
    required int tableId,
  }) async {
    final db = await _database.database;

    final now =
        DateTime.now().millisecondsSinceEpoch;

    return db.insert(
      'table_rows',
      {
        'table_item_id': tableId,
        'created_at': now,
        'updated_at': now,
      },
    );
  }

  Future<int> createField({
    required int rowId,
    required String name,
    required int position,
    String value = '',
  }) async {
    final db = await _database.database;

    final now =
        DateTime.now().millisecondsSinceEpoch;

    return db.transaction(
      (txn) async {
        final fieldId = await txn.insert(
          'table_fields',
          {
            'row_id': rowId,
            'name': name,
            'position': position,
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

        return fieldId;
      },
    );
  }

  Future<void> updateFieldValue({
    required int fieldId,
    required String value,
  }) async {
    final db = await _database.database;

    final existing =
        await db.query(
      'table_values',
      columns: ['id'],
      where: 'field_id = ?',
      whereArgs: [fieldId],
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert(
        'table_values',
        {
          'field_id': fieldId,
          'value': value,
        },
      );

      return;
    }

    final valueId =
        existing.first['id'] as int;

    await db.update(
      'table_values',
      {
        'value': value,
      },
      where: 'id = ?',
      whereArgs: [valueId],
    );
  }

  Future<void> renameField({
    required int fieldId,
    required String name,
  }) async {
    final db = await _database.database;

    await db.update(
      'table_fields',
      {
        'name': name,
        'updated_at':
            DateTime.now()
                .millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [fieldId],
    );
  }

  Future<void> deleteField(
    int fieldId,
  ) async {
    final db = await _database.database;

    await db.transaction(
      (txn) async {
        await txn.delete(
          'table_values',
          where: 'field_id = ?',
          whereArgs: [fieldId],
        );

        await txn.delete(
          'table_fields',
          where: 'id = ?',
          whereArgs: [fieldId],
        );
      },
    );
  }

  Future<void> updateFieldPositions(
    List<int> fieldIds,
  ) async {
    final db = await _database.database;

    await db.transaction(
      (txn) async {
        for (var i = 0;
            i < fieldIds.length;
            i++) {
          await txn.update(
            'table_fields',
            {
              'position': i,
              'updated_at':
                  DateTime.now()
                      .millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [fieldIds[i]],
          );
        }
      },
    );
  }

  Future<void> deleteRow(
    int rowId,
  ) async {
    final db = await _database.database;

    await db.transaction(
      (txn) async {
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

        await txn.delete(
          'table_rows',
          where: 'id = ?',
          whereArgs: [rowId],
        );
      },
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
