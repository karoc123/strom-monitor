import 'package:flutter_test/flutter_test.dart';
import 'package:jbd_battery_monitor/core/database/models/battery_reading.dart';
import 'package:jbd_battery_monitor/core/database/reading_dao.dart';
import 'package:jbd_battery_monitor/features/history/data/data_exporter.dart';
import 'package:jbd_battery_monitor/features/history/data/downsampler.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('DataExporter & Importer Tests', () {
    final sampleReadings = [
      const BatteryReading(
        timestamp: 1700000000000,
        soc: 70,
        voltage: 13.35,
        current: 2.50,
        power: 33.375,
        cellVoltage1: 3.338,
        cellVoltage2: 3.337,
        cellVoltage3: 3.338,
        cellVoltage4: 3.337,
        tempBms: 22.0,
        tempCells: 21.5,
        cycles: 10,
        solarPower: 85.0,
        solarYieldToday: 1200.0,
        solarVoltage: 19.5,
        solarCurrent: 4.3,
        solarState: 3,
      ),
      const BatteryReading(
        timestamp: 1700000060000,
        soc: 71,
        voltage: 13.30,
        current: -1.20,
        power: -15.96,
        cellVoltage1: 3.325,
        cellVoltage2: 3.325,
        cellVoltage3: 3.325,
        cellVoltage4: 3.325,
        tempBms: 22.2,
        tempCells: 21.8,
        cycles: 10,
        solarPower: 110.0,
        solarYieldToday: 1250.0,
        solarVoltage: 19.8,
        solarCurrent: 5.5,
        solarState: 3,
      ),
    ];

    test('exports to CSV and imports back without loss', () {
      final csvString = DataExporter.exportToCsv(sampleReadings);
      expect(csvString.contains('timestamp_ms'), isTrue);
      expect(csvString.contains('1700000000000'), isTrue);
      expect(csvString.contains('1700000060000'), isTrue);

      final imported = DataExporter.importFromCsv(csvString);
      expect(imported.length, equals(2));
      expect(imported[0].timestamp, equals(1700000000000));
      expect(imported[0].soc, equals(70));
      expect(imported[0].voltage, closeTo(13.35, 0.001));
      expect(imported[0].current, closeTo(2.50, 0.001));
      expect(imported[0].power, closeTo(33.375, 0.001));
      expect(imported[0].cellVoltage1, closeTo(3.338, 0.001));
      expect(imported[0].tempBms, closeTo(22.0, 0.001));
      expect(imported[0].cycles, equals(10));
      expect(imported[0].solarPower, closeTo(85.0, 0.001));
      expect(imported[0].solarYieldToday, closeTo(1200.0, 0.001));
      expect(imported[0].solarVoltage, closeTo(19.5, 0.001));
      expect(imported[0].solarCurrent, closeTo(4.3, 0.001));
      expect(imported[0].solarState, equals(3));

      expect(imported[1].timestamp, equals(1700000060000));
      expect(imported[1].soc, equals(71));
      expect(imported[1].current, closeTo(-1.20, 0.001));
      expect(imported[1].solarPower, closeTo(110.0, 0.001));
    });

    test('exports to JSON and imports back without loss', () {
      final jsonString = DataExporter.exportToJson(sampleReadings);
      expect(jsonString.contains('"soc": 70'), isTrue);
      expect(jsonString.contains('"solar_power": 85.0'), isTrue);

      final imported = DataExporter.importFromJson(jsonString);
      expect(imported.length, equals(2));
      expect(imported[0].timestamp, equals(1700000000000));
      expect(imported[0].soc, equals(70));
      expect(imported[0].solarPower, closeTo(85.0, 0.001));
      expect(imported[1].current, closeTo(-1.20, 0.001));
      expect(imported[1].solarPower, closeTo(110.0, 0.001));
    });

    test('importFromText auto-detects both JSON and CSV correctly', () {
      final csvString = DataExporter.exportToCsv(sampleReadings);
      final jsonString = DataExporter.exportToJson(sampleReadings);

      final fromCsv = DataExporter.importFromText(csvString);
      final fromJson = DataExporter.importFromText(jsonString);

      expect(fromCsv.length, equals(2));
      expect(fromCsv[0].soc, equals(70));
      expect(fromJson.length, equals(2));
      expect(fromJson[0].soc, equals(70));
    });

    test('parses CSV with German semicolon delimiters and decimal commas', () {
      const germanCsv =
          'timestamp_ms;iso_time;soc_percent;voltage_v;current_a;power_w;cell1_v;cell2_v;cell3_v;cell4_v;temp_bms_c;temp_cells_c;cycles;solar_power_w;solar_yield_wh;solar_v;solar_a;solar_state\n'
          '1700000000000;2023-11-14T22:13:20.000;70;13,35;2,50;33,375;3,338;3,337;3,338;3,337;22,0;21,5;10;85,0;1200,0;19,5;4,3;3\n';

      final imported = DataExporter.importFromCsv(germanCsv);
      expect(imported.length, equals(1));
      expect(imported.first.soc, equals(70));
      expect(imported.first.voltage, closeTo(13.35, 0.001));
      expect(imported.first.current, closeTo(2.50, 0.001));
      expect(imported.first.cellVoltage1, closeTo(3.338, 0.001));
      expect(imported.first.solarPower, closeTo(85.0, 0.001));
    });

    test('parses CSV with quotes and float SoC values without crashing', () {
      const quotedCsv =
          '"timestamp_ms","iso_time","soc_percent","voltage_v","current_a","power_w","cell1_v"\n'
          '"1700000000000","2023-11-14T22:13:20.000","72.4","13.35","2.5","33.375","3.338"\n';

      final imported = DataExporter.importFromCsv(quotedCsv);
      expect(imported.length, equals(1));
      expect(imported.first.soc, equals(72));
      expect(imported.first.voltage, closeTo(13.35, 0.001));
    });

    test('handles corrupt CSV/JSON gracefully during import', () {
      expect(DataExporter.importFromCsv('invalid,header,row'), isEmpty);
      expect(DataExporter.importFromJson('not a json'), isEmpty);
      expect(DataExporter.importFromText(''), isEmpty);
    });
  });

  group('End-to-End Backup Lifecycle & Downsampling Tests', () {
    late Database db;
    late ReadingDao dao;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE readings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp INTEGER UNIQUE NOT NULL,
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
        )
      ''');
      dao = ReadingDao.fromDatabase(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'Full cycle: insert readings -> export -> clear DB -> import back -> downsample preserves ~70% SoC',
      () async {
        // 1. Create a series of realistic telemetry points (BMS ~70% SoC mixed with standalone solar points)
        final initialReadings = <BatteryReading>[];

        for (int i = 0; i < 30; i++) {
          final isSolarOnly =
              (i % 3 != 0); // 2 out of 3 readings are solar-only
          initialReadings.add(
            BatteryReading(
              timestamp: 1700000000000 + (i * 60000),
              // BMS points have ~70% SoC; pure solar points have soc 0
              soc: isSolarOnly ? 0 : 70 + (i ~/ 10),
              voltage: isSolarOnly ? 13.5 : 13.35,
              current: isSolarOnly ? 0.0 : 2.5,
              power: isSolarOnly ? 0.0 : 33.375,
              cellVoltage1: isSolarOnly ? null : 3.338,
              cellVoltage2: isSolarOnly ? null : 3.337,
              cellVoltage3: isSolarOnly ? null : 3.338,
              cellVoltage4: isSolarOnly ? null : 3.337,
              tempBms: isSolarOnly ? null : 22.0,
              tempCells: isSolarOnly ? null : 21.5,
              cycles: isSolarOnly ? null : 10,
              solarPower: 85.0 + i,
              solarYieldToday: 1200.0 + (i * 10),
              solarVoltage: 19.5,
              solarCurrent: 4.3,
              solarState: 3,
            ),
          );
        }

        // 2. Insert into database
        await dao.insertReadingsBatch(initialReadings);
        expect(await dao.countReadings(), equals(30));

        // 3. Export to CSV
        final allDbReadings = await dao.getAllReadings();
        final csvExport = DataExporter.exportToCsv(allDbReadings);

        // 4. Clear Database (User deletes data)
        await dao.clearAll();
        expect(await dao.countReadings(), equals(0));

        // 5. Re-Import Backup
        final importedReadings = DataExporter.importFromText(csvExport);
        expect(importedReadings.length, equals(30));
        await dao.insertReadingsBatch(importedReadings);
        expect(await dao.countReadings(), equals(30));

        // 6. Query from DB and verify downsampling
        final retrieved = await dao.getReadingsBetween(
          1700000000000,
          1700000000000 + (30 * 60000),
        );
        expect(retrieved.length, equals(30));

        // Downsample for charts (target 5 points)
        final downsampled = Downsampler.downsampleByBuckets(
          retrieved,
          targetCount: 5,
        );
        expect(downsampled.length, equals(5));

        // CRITICAL CHECK: SoC must NOT be diluted to 23% or 33% by solar-only 0s!
        for (final bucket in downsampled) {
          expect(
            bucket.soc,
            inInclusiveRange(69, 73),
            reason: 'SoC should remain ~70% and not drop to ~23% or ~33%',
          );
          expect(bucket.solarPower, isNotNull);
        }
      },
    );
  });
}
