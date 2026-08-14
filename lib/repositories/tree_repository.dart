import 'package:cryptography/cryptography.dart';

import '../database/app_database.dart';
import '../security/security_manager.dart';

class TreeRepository {
  final AppDatabase _database = AppDatabase.instance;
  final SecurityManager _securityManager = SecurityManager();

  Future<List<Map<String, dynamic>>> getItems({int? parentId}) async {
    final db = await _database.database;
    return db.query(
      'tree_items',
      where: parentId == null ? 'parent_id IS NULL' : 'parent_id = ?',
      whereArgs: parentId == null ? null : [parentId],
      orderBy: 'id ASC',
    );
  }

  Future<int> createFolder({required String name, int? parentId}) async {
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.insert('tree_items', {
      'parent_id': parentId,
      'name': name,
      'type': 'folder',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<int> createTable({required String name, int? parentId}) async {
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    return db.transaction((txn) async {
      final tableId = await txn.insert('tree_items', {
        'parent_id': parentId,
        'name': name,
        'type': 'table',
        'created_at': now,
        'updated_at': now,
      });

      for (var i = 0; i < AppDatabase.defaultTableColumns.length; i++) {
        await txn.insert('table_columns', {
          'table_item_id': tableId,
          'name': AppDatabase.defaultTableColumns[i],
          'position': i,
          'created_at': now,
          'updated_at': now,
        });
      }

      return tableId;
    });
  }

  Future<void> renameItem({required int id, required String name}) async {
    final db = await _database.database;
    await db.update(
      'tree_items',
      {'name': name, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getColumns(int tableId) async {
    final db = await _database.database;
    return db.query(
      'table_columns',
      where: 'table_item_id = ?',
      whereArgs: [tableId],
      orderBy: 'position ASC',
    );
  }

  Future<int> createRow({required int tableId}) async {
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    return db.transaction((txn) async {
      final rowId = await txn.insert('table_rows', {
        'table_item_id': tableId,
        'created_at': now,
        'updated_at': now,
      });

      final columns = await txn.query(
        'table_columns',
        where: 'table_item_id = ?',
        whereArgs: [tableId],
        orderBy: 'position ASC',
      );

      for (final column in columns) {
        await _insertField(
          txn,
          rowId: rowId,
          name: column['name'] as String,
          position: column['position'] as int,
          value: '',
          now: now,
        );
      }

      return rowId;
    });
  }

  Future<List<Map<String, dynamic>>> getRows(int tableId) async {
    final db = await _database.database;
    return db.query(
      'table_rows',
      where: 'table_item_id = ?',
      whereArgs: [tableId],
      orderBy: 'id ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getFields(int rowId) async {
    final db = await _database.database;
    return db.query(
      'table_fields',
      where: 'row_id = ?',
      whereArgs: [rowId],
      orderBy: 'position ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getValues(int fieldId) async {
    final db = await _database.database;
    final records = await db.query(
      'table_values',
      where: 'field_id = ?',
      whereArgs: [fieldId],
      orderBy: 'id ASC',
    );

    final result = <Map<String, dynamic>>[];
    for (final record in records) {
      result.add({
        ...record,
        'value': await _decryptValue(record['value'] as String),
      });
    }
    return result;
  }

  Future<int> createField({
    required int rowId,
    required String name,
    required int position,
    String value = '',
  }) async {
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.transaction((txn) async {
      return _insertField(
        txn,
        rowId: rowId,
        name: name,
        position: position,
        value: value,
        now: now,
      );
    });
  }

  Future<int> _insertField(
    DatabaseExecutor db, {
    required int rowId,
    required String name,
    required int position,
    required String value,
    required int now,
  }) async {
    final fieldId = await db.insert('table_fields', {
      'row_id': rowId,
      'name': name,
      'position': position,
      'created_at': now,
      'updated_at': now,
    });

    final encryptedValue = await _encryptValue(value);
    await db.insert('table_values', {
      'field_id': fieldId,
      'value': encryptedValue,
    });

    await db.update(
      'table_rows',
      {'updated_at': now},
      where: 'id = ?',
      whereArgs: [rowId],
    );
    return fieldId;
  }

  Future<void> ensureRowMatchesSchema(int rowId) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final row = await txn.query(
        'table_rows',
        columns: ['table_item_id'],
        where: 'id = ?',
        whereArgs: [rowId],
        limit: 1,
      );
      if (row.isEmpty) return;

      final tableId = row.first['table_item_id'] as int;
      final columns = await txn.query(
        'table_columns',
        where: 'table_item_id = ?',
        whereArgs: [tableId],
        orderBy: 'position ASC',
      );
      final fields = await txn.query(
        'table_fields',
        columns: ['id', 'name'],
        where: 'row_id = ?',
        whereArgs: [rowId],
      );
      final existing = <String>{
        for (final field in fields)
          (field['name'] as String).toLowerCase(),
      };

      final now = DateTime.now().millisecondsSinceEpoch;
      for (final column in columns) {
        final name = column['name'] as String;
        if (existing.contains(name.toLowerCase())) continue;
        await _insertField(
          txn,
          rowId: rowId,
          name: name,
          position: column['position'] as int,
          value: '',
          now: now,
        );
      }
    });
  }

  Future<int> addColumn({required int tableId, required String name}) async {
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    return db.transaction((txn) async {
      final columns = await txn.query(
        'table_columns',
        columns: ['id', 'name', 'position'],
        where: 'table_item_id = ?',
        whereArgs: [tableId],
        orderBy: 'position ASC',
      );
      if (columns.any((c) => (c['name'] as String).toLowerCase() == name.toLowerCase())) {
        throw StateError('A field with this name already exists in this table.');
      }

      final columnId = await txn.insert('table_columns', {
        'table_item_id': tableId,
        'name': name,
        'position': columns.length,
        'created_at': now,
        'updated_at': now,
      });

      final rows = await txn.query(
        'table_rows',
        columns: ['id'],
        where: 'table_item_id = ?',
        whereArgs: [tableId],
      );
      for (final row in rows) {
        await _insertField(
          txn,
          rowId: row['id'] as int,
          name: name,
          position: columns.length,
          value: '',
          now: now,
        );
      }
      return columnId;
    });
  }

  Future<void> renameColumn({
    required int tableId,
    required int columnId,
    required String name,
  }) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final columns = await txn.query(
        'table_columns',
        columns: ['id', 'name'],
        where: 'table_item_id = ?',
        whereArgs: [tableId],
      );
      if (columns.any((c) => c['id'] != columnId &&
          (c['name'] as String).toLowerCase() == name.toLowerCase())) {
        throw StateError('A field with this name already exists in this table.');
      }

      final old = await txn.query(
        'table_columns',
        columns: ['name'],
        where: 'id = ? AND table_item_id = ?',
        whereArgs: [columnId, tableId],
        limit: 1,
      );
      if (old.isEmpty) throw StateError('Column was not found.');
      final oldName = old.first['name'] as String;

      await txn.update(
        'table_columns',
        {'name': name, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [columnId],
      );
      await txn.update(
        'table_fields',
        {'name': name, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'row_id IN (SELECT id FROM table_rows WHERE table_item_id = ?) AND name = ?',
        whereArgs: [tableId, oldName],
      );
    });
  }

  Future<void> deleteColumn({required int tableId, required int columnId}) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final columns = await txn.query(
        'table_columns',
        columns: ['id', 'name', 'position'],
        where: 'table_item_id = ?',
        whereArgs: [tableId],
        orderBy: 'position ASC',
      );
      if (columns.length <= 1) {
        throw StateError('At least one field must remain in this table.');
      }
      final target = columns.where((c) => c['id'] == columnId).firstOrNull;
      if (target == null) throw StateError('Column was not found.');
      final name = target['name'] as String;
      final position = target['position'] as int;

      final fields = await txn.rawQuery('''
        SELECT tf.id FROM table_fields tf
        INNER JOIN table_rows tr ON tr.id = tf.row_id
        WHERE tr.table_item_id = ? AND tf.name = ?
      ''', [tableId, name]);
      for (final field in fields) {
        final fieldId = field['id'] as int;
        await txn.delete('table_values', where: 'field_id = ?', whereArgs: [fieldId]);
        await txn.delete('table_fields', where: 'id = ?', whereArgs: [fieldId]);
      }
      await txn.delete('table_columns', where: 'id = ?', whereArgs: [columnId]);
      await txn.rawUpdate('''
        UPDATE table_columns
        SET position = position - 1, updated_at = ?
        WHERE table_item_id = ? AND position > ?
      ''', [DateTime.now().millisecondsSinceEpoch, tableId, position]);
    });
  }

  Future<void> moveColumn({
    required int tableId,
    required int columnId,
    required int newIndex,
  }) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final columns = await txn.query(
        'table_columns',
        columns: ['id'],
        where: 'table_item_id = ?',
        whereArgs: [tableId],
        orderBy: 'position ASC',
      );
      final ids = columns.map((c) => c['id'] as int).toList();
      final oldIndex = ids.indexOf(columnId);
      if (oldIndex < 0 || newIndex < 0 || newIndex >= ids.length || oldIndex == newIndex) return;
      final moved = ids.removeAt(oldIndex);
      ids.insert(newIndex, moved);
      final now = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < ids.length; i++) {
        await txn.update('table_columns', {'position': i, 'updated_at': now}, where: 'id = ?', whereArgs: [ids[i]]);
      }
      final rows = await txn.query('table_rows', columns: ['id'], where: 'table_item_id = ?', whereArgs: [tableId]);
      for (final row in rows) {
        final fields = await txn.query('table_fields', columns: ['id', 'name'], where: 'row_id = ?', whereArgs: [row['id']], orderBy: 'position ASC');
        final byName = {for (final f in fields) (f['name'] as String).toLowerCase(): f['id'] as int};
        for (var i = 0; i < ids.length; i++) {
          final col = await txn.query('table_columns', columns: ['name'], where: 'id = ?', whereArgs: [ids[i]], limit: 1);
          if (col.isEmpty) continue;
          final fieldId = byName[(col.first['name'] as String).toLowerCase()];
          if (fieldId != null) {
            await txn.update('table_fields', {'position': i, 'updated_at': now}, where: 'id = ?', whereArgs: [fieldId]);
          }
        }
      }
    });
  }

  Future<void> updateFieldValue({required int fieldId, required String value}) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final encrypted = await _encryptValue(value);
      final existing = await txn.query('table_values', columns: ['id'], where: 'field_id = ?', whereArgs: [fieldId], limit: 1);
      if (existing.isEmpty) {
        await txn.insert('table_values', {'field_id': fieldId, 'value': encrypted});
      } else {
        await txn.update('table_values', {'value': encrypted}, where: 'id = ?', whereArgs: [existing.first['id']]);
      }
      final field = await txn.query('table_fields', columns: ['row_id'], where: 'id = ?', whereArgs: [fieldId], limit: 1);
      if (field.isNotEmpty) {
        await txn.update('table_fields', {'updated_at': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [fieldId]);
        await txn.update('table_rows', {'updated_at': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [field.first['row_id']]);
      }
    });
  }

  Future<void> deleteRow(int rowId) async {
    final db = await _database.database;
    await db.transaction((txn) async => _deleteRowRecursive(txn, rowId));
  }

  Future<void> _deleteRowRecursive(DatabaseExecutor db, int rowId) async {
    final fields = await db.query('table_fields', columns: ['id'], where: 'row_id = ?', whereArgs: [rowId]);
    for (final field in fields) {
      await db.delete('table_values', where: 'field_id = ?', whereArgs: [field['id']]);
    }
    await db.delete('table_fields', where: 'row_id = ?', whereArgs: [rowId]);
    await db.delete('table_rows', where: 'id = ?', whereArgs: [rowId]);
  }

  Future<void> deleteItem(int itemId) async {
    final db = await _database.database;
    await db.transaction((txn) async => _deleteItemRecursive(txn, itemId));
  }

  Future<void> _deleteItemRecursive(DatabaseExecutor db, int itemId) async {
    final children = await db.query('tree_items', columns: ['id'], where: 'parent_id = ?', whereArgs: [itemId]);
    for (final child in children) {
      await _deleteItemRecursive(db, child['id'] as int);
    }
    final rows = await db.query('table_rows', columns: ['id'], where: 'table_item_id = ?', whereArgs: [itemId]);
    for (final row in rows) {
      await _deleteRowRecursive(db, row['id'] as int);
    }
    await db.delete('table_columns', where: 'table_item_id = ?', whereArgs: [itemId]);
    await db.delete('tree_items', where: 'id = ?', whereArgs: [itemId]);
  }

  Future<String> _encryptValue(String value) async {
    if (!_securityManager.isUnlocked) throw StateError('Security manager is locked.');
    final key = _securityManager.encryptionKey;
    try {
      return await _securityManager.cryptoService.encrypt(
        plainText: value,
        key: SecretKey(key),
      );
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  Future<String> _decryptValue(String encryptedValue) async {
    if (!_securityManager.isUnlocked) throw StateError('Security manager is locked.');
    final key = _securityManager.encryptionKey;
    try {
      return await _securityManager.cryptoService.decrypt(
        encryptedText: encryptedValue,
        key: SecretKey(key),
      );
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  Future<List<Map<String, dynamic>>> getCompleteTree() async => _loadTreeLevel(null);

  Future<List<Map<String, dynamic>>> _loadTreeLevel(int? parentId) async {
    final items = await getItems(parentId: parentId);
    final result = <Map<String, dynamic>>[];
    for (final item in items) {
      final id = item['id'] as int;
      final type = item['type'] as String;
      final node = <String, dynamic>{
        'id': id,
        'name': item['name'],
        'type': type,
        'created_at': item['created_at'],
        'updated_at': item['updated_at'],
        'children': <Map<String, dynamic>>[],
      };
      if (type == 'folder') {
        node['children'] = await _loadTreeLevel(id);
      } else {
        node['columns'] = await getColumns(id);
        node['rows'] = await _loadTableForExport(id);
      }
      result.add(node);
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _loadTableForExport(int tableId) async {
    final rows = await getRows(tableId);
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final rowId = row['id'] as int;
      await ensureRowMatchesSchema(rowId);
      final fields = await getFields(rowId);
      final values = <String, dynamic>{};
      final exportFields = <Map<String, dynamic>>[];
      for (final field in fields) {
        final fieldId = field['id'] as int;
        final name = field['name'] as String;
        final valueRecords = await getValues(fieldId);
        values[name] = valueRecords.isEmpty ? '' : valueRecords.first['value'];
        exportFields.add({'id': fieldId, 'name': name, 'position': field['position']});
      }
      result.add({'id': rowId, 'created_at': row['created_at'], 'updated_at': row['updated_at'], 'fields': exportFields, 'values': values});
    }
    return result;
  }

  Future<Map<String, dynamic>?> getCompleteTreeItem(int itemId) async {
    final db = await _database.database;
    final records = await db.query('tree_items', where: 'id = ?', whereArgs: [itemId], limit: 1);
    if (records.isEmpty) return null;
    final item = records.first;
    final id = item['id'] as int;
    final type = item['type'] as String;
    final node = <String, dynamic>{
      'id': id,
      'name': item['name'],
      'type': type,
      'created_at': item['created_at'],
      'updated_at': item['updated_at'],
      'children': <Map<String, dynamic>>[],
    };
    if (type == 'folder') {
      node['children'] = await _loadTreeLevel(id);
    } else {
      node['columns'] = await getColumns(id);
      node['rows'] = await _loadTableForExport(id);
    }
    return node;
  }

  Future<void> replaceFromBackup(List<Map<String, dynamic>> roots) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.delete('table_values');
      await txn.delete('table_fields');
      await txn.delete('table_rows');
      await txn.delete('table_columns');
      await txn.delete('tree_items');
      for (final root in roots) {
        await _restoreNode(txn, root, parentId: null);
      }
    });
  }

  Future<void> _restoreNode(DatabaseExecutor db, Map<String, dynamic> node, {required int? parentId}) async {
    final name = node['name']?.toString().trim() ?? '';
    final type = node['type']?.toString() ?? '';
    if (name.isEmpty || (type != 'folder' && type != 'table')) return;
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
          if (child is Map) await _restoreNode(db, Map<String, dynamic>.from(child), parentId: itemId);
        }
      }
      return;
    }

    final rawColumns = node['columns'];
    final rows = node['rows'];
    final columns = <String>[];
    if (rawColumns is List) {
      for (final raw in rawColumns) {
        if (raw is Map) {
          final columnName = raw['name']?.toString() ?? '';
          if (columnName.isNotEmpty && !columns.any((x) => x.toLowerCase() == columnName.toLowerCase())) columns.add(columnName);
        }
      }
    }
    if (columns.isEmpty) columns.addAll(AppDatabase.defaultTableColumns);
    for (var i = 0; i < columns.length; i++) {
      await db.insert('table_columns', {'table_item_id': itemId, 'name': columns[i], 'position': i, 'created_at': now, 'updated_at': now});
    }

    if (rows is! List) return;
    for (final rawRow in rows) {
      if (rawRow is! Map) continue;
      final row = Map<String, dynamic>.from(rawRow);
      final rowId = await db.insert('table_rows', {
        'table_item_id': itemId,
        'created_at': row['created_at'] is int ? row['created_at'] : now,
        'updated_at': row['updated_at'] is int ? row['updated_at'] : now,
      });
      final fields = row['fields'];
      final values = row['values'];
      if (fields is List) {
        for (final rawField in fields) {
          if (rawField is! Map) continue;
          final field = Map<String, dynamic>.from(rawField);
          final fieldName = field['name']?.toString() ?? '';
          if (fieldName.isEmpty) continue;
          final position = field['position'] is int ? field['position'] as int : 0;
          final fieldId = await db.insert('table_fields', {
            'row_id': rowId,
            'name': fieldName,
            'position': position,
            'created_at': now,
            'updated_at': now,
          });
          var value = '';
          if (values is Map && values[fieldName] != null) value = values[fieldName].toString();
          await db.insert('table_values', {'field_id': fieldId, 'value': await _encryptValue(value)});
        }
      }
      await ensureRowMatchesSchema(rowId);
    }
  }
}
