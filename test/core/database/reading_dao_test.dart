import 'package:flutter_test/flutter_test.dart';
import 'package:jbd_battery_monitor/core/database/app_database.dart';
import 'package:jbd_battery_monitor/core/database/models/battery_reading.dart';
import 'package:jbd_battery_monitor/core/database/reading_dao.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Initialize FFI for headless desktop unit tests
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('ReadingDao & AppDatabase Tests', () {
    late AppDatabase appDatabase;
    late ReadingDao readingDao;

    setUp(() async {
      // In-memory SQLite database for testing
      appDatabase = AppDatabase.inMemory();
      readingDao = ReadingDao(appDatabase);
    });

    tearDown(() async {
      await appDatabase.close();
    });

    test('inserts and retrieves single battery reading', () async {
      final reading = BatteryReading(
        timestamp: 1700000000000,
        soc: 85,
        voltage: 13.32,
        current: 1.50,
        power: 19.98,
        cellVoltage1: 3.330,
        cellVoltage2: 3.332,
        cellVoltage3: 3.331,
        cellVoltage4: 3.327,
        tempBms: 22.5,
        tempCells: 21.0,
        cycles: 15,
        solarPower: 120.5,
        solarYieldToday: 1500.0,
        solarVoltage: 18.2,
        solarCurrent: 6.6,
        solarState: 3,
      );

      final id = await readingDao.insertReading(reading);
      expect(id, isPositive);

      final count = await readingDao.countReadings();
      expect(count, equals(1));

      final latest = await readingDao.getLatestReading();
      expect(latest, isNotNull);
      expect(latest!.soc, equals(85));
      expect(latest.voltage, closeTo(13.32, 0.001));
      expect(latest.current, closeTo(1.50, 0.001));
      expect(latest.power, closeTo(19.98, 0.001));
      expect(latest.cellVoltage1, closeTo(3.330, 0.001));
      expect(latest.tempBms, closeTo(22.5, 0.001));
      expect(latest.cycles, equals(15));
      expect(latest.solarPower, closeTo(120.5, 0.001));
      expect(latest.solarYieldToday, closeTo(1500.0, 0.001));
      expect(latest.solarVoltage, closeTo(18.2, 0.001));
      expect(latest.solarCurrent, closeTo(6.6, 0.001));
      expect(latest.solarState, equals(3));
    });

    test(
      'inserts batch with conflict ignore for duplicate timestamps',
      () async {
        final r1 = BatteryReading(
          timestamp: 1000,
          soc: 50,
          voltage: 13.0,
          current: 0.0,
          power: 0.0,
        );
        final r2 = BatteryReading(
          timestamp: 2000,
          soc: 51,
          voltage: 13.1,
          current: 1.0,
          power: 13.1,
        );
        final r3Duplicate = BatteryReading(
          timestamp: 1000,
          soc: 99,
          voltage: 14.0,
          current: 5.0,
          power: 70.0,
        );

        await readingDao.insertReadingsBatch([r1, r2, r3Duplicate]);

        final count = await readingDao.countReadings();
        expect(count, equals(2)); // Duplicate timestamp was ignored

        final all = await readingDao.getAllReadings();
        expect(all.length, equals(2));
        expect(all[0].timestamp, equals(1000));
        expect(all[0].soc, equals(50)); // original preserved
        expect(all[1].timestamp, equals(2000));
      },
    );

    test('queries readings within specific time window', () async {
      for (int i = 1; i <= 5; i++) {
        await readingDao.insertReading(
          BatteryReading(
            timestamp: i * 1000,
            soc: 50 + i,
            voltage: 13.0 + (i * 0.05),
            current: i * 0.5,
            power: (13.0 + (i * 0.05)) * (i * 0.5),
          ),
        );
      }

      final windowReadings = await readingDao.getReadingsBetween(2000, 4000);
      expect(windowReadings.length, equals(3));
      expect(windowReadings.first.timestamp, equals(2000));
      expect(windowReadings.last.timestamp, equals(4000));
    });

    test('prunes readings older than specified threshold', () async {
      await readingDao.insertReading(
        BatteryReading(
          timestamp: 1000,
          soc: 20,
          voltage: 12.5,
          current: 0.0,
          power: 0.0,
        ),
      );
      await readingDao.insertReading(
        BatteryReading(
          timestamp: 5000,
          soc: 80,
          voltage: 13.3,
          current: 0.0,
          power: 0.0,
        ),
      );

      final deleted = await readingDao.pruneOlderThan(3000);
      expect(deleted, equals(1));

      final remaining = await readingDao.getAllReadings();
      expect(remaining.length, equals(1));
      expect(remaining.first.timestamp, equals(5000));
    });

    test('clears entire readings table', () async {
      await readingDao.insertReading(
        BatteryReading(
          timestamp: 1000,
          soc: 50,
          voltage: 13.0,
          current: 0.0,
          power: 0.0,
        ),
      );
      expect(await readingDao.countReadings(), equals(1));

      await readingDao.clearAll();
      expect(await readingDao.countReadings(), equals(0));
    });

    test('migrates database from V1 to V2 preserving existing data', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
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
              cycles INTEGER
            );
          ''');
        },
      );

      final daoV1 = ReadingDao.fromDatabase(db);
      await daoV1.insertReading(
        const BatteryReading(
          timestamp: 5000,
          soc: 75,
          voltage: 13.2,
          current: 1.0,
          power: 13.2,
        ),
      );

      // Perform V1 -> V2 upgrade
      await db.execute('ALTER TABLE readings ADD COLUMN solar_power REAL;');
      await db.execute(
        'ALTER TABLE readings ADD COLUMN solar_yield_today REAL;',
      );
      await db.execute('ALTER TABLE readings ADD COLUMN solar_voltage REAL;');
      await db.execute('ALTER TABLE readings ADD COLUMN solar_current REAL;');
      await db.execute('ALTER TABLE readings ADD COLUMN solar_state INTEGER;');

      final daoV2 = ReadingDao.fromDatabase(db);
      // Retrieve existing legacy reading
      final legacy = await daoV2.getLatestReading();
      expect(legacy, isNotNull);
      expect(legacy!.timestamp, equals(5000));
      expect(legacy.soc, equals(75));
      expect(legacy.solarPower, isNull);

      // Insert new V2 reading with solar telemetry
      await daoV2.insertReading(
        const BatteryReading(
          timestamp: 6000,
          soc: 76,
          voltage: 13.25,
          current: 2.0,
          power: 26.5,
          solarPower: 150.0,
          solarYieldToday: 800.0,
        ),
      );

      final updatedLatest = await daoV2.getLatestReading();
      expect(updatedLatest, isNotNull);
      expect(updatedLatest!.timestamp, equals(6000));
      expect(updatedLatest.solarPower, closeTo(150.0, 0.001));
      expect(updatedLatest.solarYieldToday, closeTo(800.0, 0.001));

      await db.close();
    });
  });
}
