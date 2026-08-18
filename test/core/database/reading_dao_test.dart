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
  });
}
