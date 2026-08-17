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
   /// Reads the complete tree recursively.
  ///
  /// The returned structure contains:
  ///
  /// {
  ///   id,
  ///   name,
  ///   type,
  ///   children: [...]
  /// }
  ///
  /// Tables additionally contain:
  ///
  /// {
  ///   columns: [...],
  ///   rows: [...]
  /// }
  ///
  /// Values are decrypted through the existing
  /// security manager, therefore this method requires
  /// the security session to be unlocked.
  Future<List<Map<String, dynamic>>>
      getCompleteTree() async {
    return _loadTreeLevel(
      parentId: null,
    );
  }

  Future<List<Map<String, dynamic>>>
      _loadTreeLevel({
    required int? parentId,
  }) async {
    final items = await getItems(
      parentId: parentId,
    );

    final result =
        <Map<String, dynamic>>[];

    for (final item in items) {
      final id =
          item['id'] as int;

      final name =
          item['name'] as String;

      final type =
          item['type'] as String;

      final node =
          <String, dynamic>{
        'id': id,
        'name': name,
        'type': type,
        'created_at':
            item['created_at'],
        'updated_at':
            item['updated_at'],
        'children':
            <Map<String, dynamic>>[],
      };

      if (type == 'folder') {
        node['children'] =
            await _loadTreeLevel(
          parentId: id,
        );
      } else if (type == 'table') {
        node['columns'] =
            <Map<String, dynamic>>[];

        node['rows'] =
            await _loadTableForExport(
          id,
        );
      }

      result.add(node);
    }

    return result;
  }

  Future<List<Map<String, dynamic>>>
      _loadTableForExport(
    int tableId,
  ) async {
    final rows =
        await getRows(tableId);

    final result =
        <Map<String, dynamic>>[];

    for (final row in rows) {
      final rowId =
          row['id'] as int;

      final fields =
          await getFields(rowId);

      final values =
          <String, dynamic>{};

      final fieldsForExport =
          <Map<String, dynamic>>[];

      for (final field in fields) {
        final fieldId =
            field['id'] as int;

        final fieldName =
            field['name'] as String;

        final position =
            field['position'] as int;

        final valueRecords =
            await getValues(fieldId);

        var value = '';

        if (valueRecords.isNotEmpty) {
          value =
              valueRecords.first['value']
                  as String;
        }

        fieldsForExport.add({
          'id': fieldId,
          'name': fieldName,
          'position': position,
        });

        values[fieldId.toString()] =
            value;
      }

      result.add({
        'id': rowId,
        'created_at':
            row['created_at'],
        'updated_at':
            row['updated_at'],
        'fields':
            fieldsForExport,
        'values':
            values,
      });
    }

    return result;
  }
  /// Reads the selected tree item and all of its descendants.
  ///
  /// This is used when exporting PDF from any point
  /// in the tree, not only from the root.
  ///
  /// Example:
  ///
  /// Folder A
  /// ├── Table 1
  /// ├── Table 2
  /// └── Folder B
  ///     ├── Table 3
  ///     └── Folder C
  ///
  /// Calling this method with Folder A's ID returns
  /// Folder A as the root of the exported structure.
  Future<Map<String, dynamic>?> getCompleteTreeItem(
    int itemId,
  ) async {
    final db = await _database.database;

    final records = await db.query(
      'tree_items',
      where: 'id = ?',
      whereArgs: [itemId],
      limit: 1,
    );

    if (records.isEmpty) {
      return null;
    }

    final item = records.first;

    final id = item['id'] as int;
    final name = item['name'] as String;
    final type = item['type'] as String;

    final node = <String, dynamic>{
      'id': id,
      'name': name,
      'type': type,
      'created_at': item['created_at'],
      'updated_at': item['updated_at'],
      'children': <Map<String, dynamic>>[],
    };

    if (type == 'folder') {
      node['children'] = await _loadTreeLevel(
        parentId: id,
      );
    } else if (type == 'table') {
      node['columns'] = <Map<String, dynamic>>[];
      node['rows'] = await _loadTableForExport(id);
    }

    return node;
  }
  /// Replaces the complete vault with data from an already decrypted backup.
  /// IDs from the backup are intentionally not reused; new IDs are generated
  /// by SQLite so foreign-key relationships remain valid.
  Future<void> replaceFromBackup(
    List<Map<String, dynamic>> roots,
  ) async {
    final db = await _database.database;

    await db.transaction((txn) async {
      await txn.delete('table_values');
      await txn.delete('table_fields');
      await txn.delete('table_rows');
      await txn.delete('tree_items');

      for (final root in roots) {
        await _restoreNode(txn, root, parentId: null);
      }
    });
  }

  Future<void> _restoreNode(
    dynamic db,
    Map<String, dynamic> node, {
    required int? parentId,
  }) async {
    final name = node['name']?.toString().trim() ?? '';
    final type = node['type']?.toString() ?? '';
    if (name.isEmpty || (type != 'folder' && type != 'table')) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final itemId = await db.insert('tree_items', {
      'parent_id': parentId,
      'name': name,
      'type': type,
      'created_at': node['created_at'] is int ? node['created_at'] : now,
      'updated_at': node['updated_at'] is int ? node['updated_at'] : now,
    });

    if (type == 'folder') {
      final children = node['children'];
      if (children is List) {
        for (final child in children) {
          if (child is Map) {
            await _restoreNode(
              db,
              Map<String, dynamic>.from(child),
              parentId: itemId,
            );
          }
        }
      }
      return;
    }

    final rows = node['rows'];
    if (rows is! List) {
      return;
    }

    for (final rawRow in rows) {
      if (rawRow is! Map) {
        continue;
      }

      final row = Map<String, dynamic>.from(rawRow);
      final rowId = await db.insert('table_rows', {
        'table_item_id': itemId,
        'created_at': row['created_at'] is int ? row['created_at'] : now,
        'updated_at': row['updated_at'] is int ? row['updated_at'] : now,
      });

      final fields = row['fields'];
      final values = row['values'];
      if (fields is! List) {
        continue;
      }

      for (final rawField in fields) {
        if (rawField is! Map) {
          continue;
        }

        final field = Map<String, dynamic>.from(rawField);
        final fieldName = field['name']?.toString() ?? '';
        if (fieldName.isEmpty) {
          continue;
        }

        final position = field['position'] is int
            ? field['position'] as int
            : 0;

        final originalFieldId = field['id'];

        final fieldId = await db.insert('table_fields', {
          'row_id': rowId,
          'name': fieldName,
          'position': position,
          'created_at': now,
          'updated_at': now,
        });

        var value = '';
        if (values is Map) {
          final key = originalFieldId?.toString();
          if (key != null && values[key] != null) {
            value = values[key].toString();
          }
        }

        final encryptedValue = await _encryptValue(value);
        await db.insert('table_values', {
          'field_id': fieldId,
          'value': encryptedValue,
        });
      }
    }
  }
}
