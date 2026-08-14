import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();

  AppDatabase._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _openDatabase();
    return _database!;
  }

  static const List<String> defaultTableColumns = [
    'Name',
    'IP',
    'Username',
    'Password',
    'Version',
    'Description',
  ];

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = '$databasesPath/pass_managers.db';

    return openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tree_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_id INTEGER,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE table_columns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_item_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        position INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE table_rows (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_item_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE table_fields (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        row_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        position INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE table_values (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        field_id INTEGER NOT NULL,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_tree_items_parent ON tree_items(parent_id)');
    await db.execute('CREATE INDEX idx_table_columns_table ON table_columns(table_item_id)');
    await db.execute('CREATE INDEX idx_table_rows_table ON table_rows(table_item_id)');
    await db.execute('CREATE INDEX idx_table_fields_row ON table_fields(row_id)');
    await db.execute('CREATE INDEX idx_table_values_field ON table_values(field_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Version 2 reserved the migration slot.
    }

    if (oldVersion < 3) {
      await _migrateToTableColumns(db);
    }
  }

  Future<void> _migrateToTableColumns(Database db) async {
    await db.execute('''
      CREATE TABLE table_columns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_item_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        position INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_table_columns_table ON table_columns(table_item_id)');

    final tables = await db.query(
      'tree_items',
      columns: ['id'],
      where: 'type = ?',
      whereArgs: ['table'],
      orderBy: 'id ASC',
    );

    for (final table in tables) {
      final tableId = table['id'] as int;
      final fields = await db.rawQuery('''
        SELECT tf.name, tf.position
        FROM table_fields tf
        INNER JOIN table_rows tr ON tr.id = tf.row_id
        WHERE tr.table_item_id = ?
        ORDER BY tr.id ASC, tf.position ASC
      ''', [tableId]);

      final names = <String>[];
      final seen = <String>{};

      for (final field in fields) {
        final name = (field['name'] as String).trim();
        final key = name.toLowerCase();
        if (name.isEmpty || !seen.add(key)) continue;
        names.add(name);
      }

      if (names.isEmpty) {
        names.addAll(defaultTableColumns);
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < names.length; i++) {
        await db.insert('table_columns', {
          'table_item_id': tableId,
          'name': names[i],
          'position': i,
          'created_at': now,
          'updated_at': now,
        });
      }
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db == null) return;
    await db.close();
    _database = null;
  }
}
