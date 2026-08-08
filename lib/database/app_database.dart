import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase instance =
      AppDatabase._internal();

  AppDatabase._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();

    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();

    final path = '$databasesPath/pass_managers.db';

    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(
    Database db,
    int version,
  ) async {
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

    await db.execute('''
      CREATE INDEX idx_tree_items_parent
      ON tree_items(parent_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_table_rows_table
      ON table_rows(table_item_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_table_fields_row
      ON table_fields(row_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_table_values_field
      ON table_values(field_id)
    ''');
  }

  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      // Future migration.
    }
  }

  Future<void> close() async {
    final db = _database;

    if (db == null) {
      return;
    }

    await db.close();

    _database = null;
  }
}
