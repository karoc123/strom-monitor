import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Database Manager handling SQLite creation, indexes, and connection lifecycle.
class AppDatabase {
  static const String dbName = 'jbd_battery_monitor.db';
  static const int dbVersion = 1;

  static final AppDatabase instance = AppDatabase._internal();

  final bool _isInMemory;
  Database? _db;

  AppDatabase({bool inMemory = false}) : _isInMemory = inMemory;

  AppDatabase._internal({bool inMemory = false}) : _isInMemory = inMemory;

  factory AppDatabase.inMemory() => AppDatabase._internal(inMemory: true);

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    if (_isInMemory) {
      return openDatabase(
        inMemoryDatabasePath,
        version: dbVersion,
        onCreate: _onCreate,
      );
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbName);

    return openDatabase(path, version: dbVersion, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS readings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL UNIQUE,
        soc INTEGER NOT NULL,
        voltage REAL NOT NULL,
        current REAL NOT NULL,
        power REAL NOT NULL,
        cell_voltage_1 REAL,
        cell_voltage_2 REAL,
        cell_voltage_3 REAL,
        cell_voltage_4 REAL,
        temp_bms REAL,
        temp_cells REAL,
        cycles INTEGER
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_readings_timestamp ON readings(timestamp);
    ''');
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
