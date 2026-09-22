import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jbd_battery_monitor/core/database/app_database.dart';
import 'package:jbd_battery_monitor/core/database/models/battery_reading.dart';
import 'package:jbd_battery_monitor/core/database/reading_dao.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Database Closed Reproduction & Fix Tests', () {
    test('ReadingDao with direct Database reference throws database_closed when db is closed', () async {
      final appDb = AppDatabase.inMemory();
      final db = await appDb.database;
      final legacyDao = ReadingDao.fromDatabase(db);

      await legacyDao.insertReading(
        const BatteryReading(
          timestamp: 1000,
          soc: 80,
          voltage: 13.3,
          current: 0,
          power: 0,
        ),
      );

      // Close the database
      await appDb.close();

      // Legacy direct DAO call fails with database_closed
      try {
        await legacyDao.getReadingsBetween(0, 2000);
        fail('Expected database_closed error');
      } catch (e) {
        expect(e.toString().toLowerCase(), contains('database_closed'));
      }
    });

    test('ReadingDao using AppDatabase getter automatically recovers and re-opens connection without throwing database_closed', () async {
      final tempDir = await Directory.systemTemp.createTemp('jbd_db_test_');
      final dbFile = p.join(tempDir.path, 'test_resilient.db');

      final db = await openDatabase(
        dbFile,
        version: 2,
        onCreate: (db, version) async {
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
                cycles INTEGER,
                solar_power REAL,
                solar_yield_today REAL,
                solar_voltage REAL,
                solar_current REAL,
                solar_state INTEGER
              );
            ''');
        },
      );

      final appDb = AppDatabase();
      // Set up resilient dao with open connection
      final resilientDao = ReadingDao.fromDatabase(db);

      await resilientDao.insertReading(
        const BatteryReading(
          timestamp: 1000,
          soc: 80,
          voltage: 13.3,
          current: 0,
          power: 0,
        ),
      );

      await db.close();

      // With AppDatabase resilient manager
      final autoReopenDao = ReadingDao(appDb);
      // The query succeeds and does not throw database_closed
      final readings = await autoReopenDao.getReadingsBetween(0, 2000);
      expect(readings, isA<List<BatteryReading>>());

      await tempDir.delete(recursive: true);
    });
  });
}
