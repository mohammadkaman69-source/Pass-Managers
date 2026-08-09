import 'package:cryptography/cryptography.dart';

import '../database/app_database.dart';
import '../security/security_manager.dart';

class TreeRepository {
  final AppDatabase _database = AppDatabase.instance;

  final SecurityManager _securityManager =
      SecurityManager();

  Future<List<Map<String, dynamic>>> getItems({
    int? parentId,
  }) async {
    final db = await _database.database;

    if (parentId == null) {
      return db.query(
        'tree_items',
        where: 'parent_id IS NULL',
        orderBy: 'id ASC',
      );
    }

    return db.query(
      'tree_items',
      where: 'parent_id = ?',
      whereArgs: [parentId],
      orderBy: 'id ASC',
    );
  }

  Future<int> createFolder({
    required String name,
    int? parentId,
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
    required String name,
    int? parentId,
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

  Future<void> renameItem({
    required int id,
    required String name,
  }) async {
    final db = await _database.database;

    await db.update(
      'tree_items',
      {
        'name': name,
        'updated_at':
            DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteItem(
    int itemId,
  ) async {
    final db = await _database.database;

    await db.transaction(
      (txn) async {
        await _deleteItemRecursive(
          txn,
          itemId,
        );
      },
    );
  }

  Future<void> _deleteItemRecursive(
    dynamic db,
    int itemId,
  ) async {
    final children = await db.query(
      'tree_items',
      columns: ['id'],
      where: 'parent_id = ?',
      whereArgs: [itemId],
    );

    for (final child in children) {
      final childId = child['id'] as int;

      await _deleteItemRecursive(
        db,
        childId,
      );
    }

    final rows = await db.query(
      'table_rows',
      columns: ['id'],
      where: 'table_item_id = ?',
      whereArgs: [itemId],
    );

    for (final row in rows) {
      final rowId = row['id'] as int;

      await _deleteRowRecursive(
        db,
        rowId,
      );
    }

    await db.delete(
      'tree_items',
      where: 'id = ?',
      whereArgs: [itemId],
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

        final encryptedValue =
            await _encryptValue(value);

        await txn.insert(
          'table_values',
          {
            'field_id': fieldId,
            'value': encryptedValue,
          },
        );

        await txn.update(
          'table_rows',
          {
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [rowId],
        );

        return fieldId;
      },
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

    final records = await db.query(
      'table_values',
      where: 'field_id = ?',
      whereArgs: [fieldId],
      orderBy: 'id ASC',
    );

    final decryptedRecords =
        <Map<String, dynamic>>[];

    for (final record in records) {
      final encryptedValue =
          record['value'] as String;

      final decryptedValue =
          await _decryptValue(
        encryptedValue,
      );

      decryptedRecords.add({
        ...record,
        'value': decryptedValue,
      });
    }

    return decryptedRecords;
  }

  Future<void> updateFieldValue({
    required int fieldId,
    required String value,
  }) async {
    final db = await _database.database;

    await db.transaction(
      (txn) async {
        final encryptedValue =
            await _encryptValue(value);

        final existing = await txn.query(
          'table_values',
          columns: ['id'],
          where: 'field_id = ?',
          whereArgs: [fieldId],
          limit: 1,
        );

        if (existing.isEmpty) {
          await txn.insert(
            'table_values',
            {
              'field_id': fieldId,
              'value': encryptedValue,
            },
          );
        } else {
          final valueId =
              existing.first['id'] as int;

          await txn.update(
            'table_values',
            {
              'value': encryptedValue,
            },
            where: 'id = ?',
            whereArgs: [valueId],
          );
        }

        final field = await txn.query(
          'table_fields',
          columns: ['row_id'],
          where: 'id = ?',
          whereArgs: [fieldId],
          limit: 1,
        );

        if (field.isNotEmpty) {
          final rowId =
              field.first['row_id'] as int;

          final now =
              DateTime.now()
                  .millisecondsSinceEpoch;

          await txn.update(
            'table_fields',
            {
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [fieldId],
          );

          await txn.update(
            'table_rows',
            {
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [rowId],
          );
        }
      },
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
            DateTime.now().millisecondsSinceEpoch,
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
        final field = await txn.query(
          'table_fields',
          columns: [
            'row_id',
            'position',
          ],
          where: 'id = ?',
          whereArgs: [fieldId],
          limit: 1,
        );

        if (field.isEmpty) {
          return;
        }

        final rowId =
            field.first['row_id'] as int;

        final deletedPosition =
            field.first['position'] as int;

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

        final now =
            DateTime.now()
                .millisecondsSinceEpoch;

        await txn.rawUpdate(
          '''
          UPDATE table_fields
          SET position = position - 1,
              updated_at = ?
          WHERE row_id = ?
            AND position > ?
          ''',
          [
            now,
            rowId,
            deletedPosition,
          ],
        );

        await txn.update(
          'table_rows',
          {
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [rowId],
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
        final now =
            DateTime.now()
                .millisecondsSinceEpoch;

        for (var i = 0;
            i < fieldIds.length;
            i++) {
          await txn.update(
            'table_fields',
            {
              'position': i,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [fieldIds[i]],
          );
        }

        if (fieldIds.isEmpty) {
          return;
        }

        final firstField =
            await txn.query(
          'table_fields',
          columns: ['row_id'],
          where: 'id = ?',
          whereArgs: [fieldIds.first],
          limit: 1,
        );

        if (firstField.isNotEmpty) {
          final rowId =
              firstField.first['row_id'] as int;

          await txn.update(
            'table_rows',
            {
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [rowId],
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
        await _deleteRowRecursive(
          txn,
          rowId,
        );
      },
    );
  }

  Future<void> _deleteRowRecursive(
    dynamic db,
    int rowId,
  ) async {
    final fields = await db.query(
      'table_fields',
      columns: ['id'],
      where: 'row_id = ?',
      whereArgs: [rowId],
    );

    for (final field in fields) {
      final fieldId =
          field['id'] as int;

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

    await db.delete(
      'table_rows',
      where: 'id = ?',
      whereArgs: [rowId],
    );
  }

  Future<String> _encryptValue(
    String value,
  ) async {
    if (!_securityManager.isUnlocked) {
      throw StateError(
        'Security manager is locked.',
      );
    }

    final key =
        _securityManager.encryptionKey;

    try {
      final secretKey =
          SecretKey(key);

      return await _securityManager.cryptoService.encrypt(
        plainText: value,
        key: secretKey,
      );
    } finally {
      key.fillRange(
        0,
        key.length,
        0,
      );
    }
  }

  Future<String> _decryptValue(
    String encryptedValue,
  ) async {
    if (!_securityManager.isUnlocked) {
      throw StateError(
        'Security manager is locked.',
      );
    }

    final key =
        _securityManager.encryptionKey;

    try {
      final secretKey =
          SecretKey(key);

      return await _securityManager.cryptoService.decrypt(
        encryptedText: encryptedValue,
        key: secretKey,
      );
    } finally {
      key.fillRange(
        0,
        key.length,
        0,
      );
    }
  }
}
