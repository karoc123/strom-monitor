import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'models/battery_reading.dart';

/// Data Access Object for battery telemetry readings.
class ReadingDao {
  final AppDatabase? _appDatabase;
  final Database? _directDb;

  ReadingDao(AppDatabase appDatabase)
    : _appDatabase = appDatabase,
      _directDb = null;

  /// Creates a [ReadingDao] bound directly to a [Database] instance.
  ReadingDao.fromDatabase(Database db) : _directDb = db, _appDatabase = null;

  static const String table = 'readings';

  Future<Database> _getDb() async {
    final direct = _directDb;
    if (direct != null) {
      return direct;
    }
    return _appDatabase!.database;
  }

  /// Inserts a single [BatteryReading].
  Future<int> insertReading(BatteryReading reading) async {
    final db = await _getDb();
    return db.insert(
      table,
      reading.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Inserts a batch of [BatteryReading] items, ignoring duplicate timestamps.
  Future<void> insertReadingsBatch(List<BatteryReading> readings) async {
    if (readings.isEmpty) return;

    final db = await _getDb();
    final batch = db.batch();
    for (final reading in readings) {
      batch.insert(
        table,
        reading.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Retrieves the latest saved [BatteryReading].
  Future<BatteryReading?> getLatestReading() async {
    final db = await _getDb();
    final maps = await db.query(table, orderBy: 'timestamp DESC', limit: 1);
    if (maps.isEmpty) return null;
    return BatteryReading.fromMap(maps.first);
  }

  /// Retrieves all readings between [startTimestampMs] and [endTimestampMs] inclusive.
  Future<List<BatteryReading>> getReadingsBetween(
    int startTimestampMs,
    int endTimestampMs,
  ) async {
    final db = await _getDb();
    final maps = await db.query(
      table,
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [startTimestampMs, endTimestampMs],
      orderBy: 'timestamp ASC',
    );
    return maps.map(BatteryReading.fromMap).toList();
  }

  /// Retrieves all readings (optionally limited by [limit]).
  Future<List<BatteryReading>> getAllReadings({int? limit}) async {
    final db = await _getDb();
    final maps = await db.query(table, orderBy: 'timestamp ASC', limit: limit);
    return maps.map(BatteryReading.fromMap).toList();
  }

  /// Returns the total count of stored records.
  Future<int> countReadings() async {
    final db = await _getDb();
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Deletes readings older than [olderThanMs] timestamp.
  /// Returns the number of deleted records.
  Future<int> pruneOlderThan(int olderThanMs) async {
    final db = await _getDb();
    return db.delete(table, where: 'timestamp < ?', whereArgs: [olderThanMs]);
  }

  /// Clears all stored readings.
  Future<void> clearAll() async {
    final db = await _getDb();
    await db.delete(table);
  }
}
