import 'package:flutter_test/flutter_test.dart';
import 'package:jbd_battery_monitor/core/ble/ble_client.dart';
import 'package:jbd_battery_monitor/core/database/app_database.dart';
import 'package:jbd_battery_monitor/core/database/reading_dao.dart';
import 'package:jbd_battery_monitor/core/protocol/jbd_telemetry_parser.dart';
import 'package:jbd_battery_monitor/core/protocol/victron/victron_mppt_data.dart';
import 'package:jbd_battery_monitor/features/dashboard/data/telemetry_recorder.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('TelemetryRecorder Throttling Tests', () {
    late AppDatabase appDatabase;
    late ReadingDao readingDao;
    late TelemetryRecorder recorder;

    setUp(() async {
      appDatabase = AppDatabase.inMemory();
      readingDao = ReadingDao(appDatabase);
      recorder = TelemetryRecorder(
        readingDao: readingDao,
        minIntervalSeconds: 60,
        socDeltaThreshold: 1,
        voltageDeltaThreshold: 0.2,
      );
    });

    tearDown(() async {
      await appDatabase.close();
    });

    BatterySnapshot createSnapshot({
      required double voltage,
      required double current,
      required int soc,
      required DateTime time,
    }) {
      return BatterySnapshot(
        basicInfo: JbdBasicInfo(
          voltage: voltage,
          current: current,
          power: voltage * current,
          remainingCapacityAh: 50,
          nominalCapacityAh: 100,
          cycleCount: 5,
          soc: soc,
          chargeFetEnabled: true,
          dischargeFetEnabled: true,
          cellCount: 4,
          temperatures: [22.0, 21.0],
          tempBms: 22.0,
          tempCells: 21.0,
          protectionStatus: 0,
          balanceStatusLow: 0,
          balanceStatusHigh: 0,
          softwareVersion: 16,
        ),
        cellVoltages: [3.3, 3.3, 3.3, 3.3],
        timestamp: time,
      );
    }

    test('always records first reading', () async {
      final s1 = createSnapshot(
        voltage: 13.3,
        current: 0.0,
        soc: 80,
        time: DateTime.fromMillisecondsSinceEpoch(100000),
      );

      final didRecord = await recorder.processSnapshot(s1);
      expect(didRecord, isTrue);
      expect(await readingDao.countReadings(), equals(1));
    });

    test('throttles small changes within time window', () async {
      final s1 = createSnapshot(
        voltage: 13.3,
        current: 0.0,
        soc: 80,
        time: DateTime.fromMillisecondsSinceEpoch(100000),
      );
      await recorder.processSnapshot(s1);

      // 5 seconds later with identical/tiny delta
      final s2 = createSnapshot(
        voltage: 13.31,
        current: 0.05,
        soc: 80,
        time: DateTime.fromMillisecondsSinceEpoch(105000),
      );
      final didRecord = await recorder.processSnapshot(s2);
      expect(didRecord, isFalse);
      expect(await readingDao.countReadings(), equals(1));
    });

    test('records immediately when SoC delta threshold is reached', () async {
      final s1 = createSnapshot(
        voltage: 13.3,
        current: 0.0,
        soc: 80,
        time: DateTime.fromMillisecondsSinceEpoch(100000),
      );
      await recorder.processSnapshot(s1);

      // 5 seconds later, SoC changed by 1%
      final s2 = createSnapshot(
        voltage: 13.3,
        current: -2.0,
        soc: 79,
        time: DateTime.fromMillisecondsSinceEpoch(105000),
      );
      final didRecord = await recorder.processSnapshot(s2);
      expect(didRecord, isTrue);
      expect(await readingDao.countReadings(), equals(2));
    });

    test(
      'records immediately when Voltage delta threshold is reached',
      () async {
        final s1 = createSnapshot(
          voltage: 13.3,
          current: 0.0,
          soc: 80,
          time: DateTime.fromMillisecondsSinceEpoch(100000),
        );
        await recorder.processSnapshot(s1);

        // 5 seconds later, Voltage dropped from 13.3 to 13.0 (>0.2V delta)
        final s2 = createSnapshot(
          voltage: 13.0,
          current: -5.0,
          soc: 80,
          time: DateTime.fromMillisecondsSinceEpoch(105000),
        );
        final didRecord = await recorder.processSnapshot(s2);
        expect(didRecord, isTrue);
        expect(await readingDao.countReadings(), equals(2));
      },
    );

    test('records when timer expires even with small change', () async {
      final s1 = createSnapshot(
        voltage: 13.3,
        current: 0.0,
        soc: 80,
        time: DateTime.fromMillisecondsSinceEpoch(100000),
      );
      await recorder.processSnapshot(s1);

      // 61 seconds later
      final s2 = createSnapshot(
        voltage: 13.3,
        current: 0.0,
        soc: 80,
        time: DateTime.fromMillisecondsSinceEpoch(161000),
      );
      final didRecord = await recorder.processSnapshot(s2);
      expect(didRecord, isTrue);
      expect(await readingDao.countReadings(), equals(2));
    });

    test('records when solar power delta threshold is exceeded', () async {
      final s1 = createSnapshot(
        voltage: 13.3,
        current: 0.0,
        soc: 80,
        time: DateTime.fromMillisecondsSinceEpoch(100000),
      );
      await recorder.processSnapshot(s1);

      // 5 seconds later with solar power jump from null to 50W
      final s2 = createSnapshot(
        voltage: 13.3,
        current: 0.0,
        soc: 80,
        time: DateTime.fromMillisecondsSinceEpoch(105000),
      );
      final didRecord = await recorder.processTelemetry(
        batterySnapshot: s2,
        solarData: VictronMpptData(
          deviceState: VictronDeviceState.bulk,
          chargerError: VictronChargerError.noError,
          batteryVoltage: 13.3,
          batteryCurrent: 3.5,
          solarPower: 50.0,
          yieldTodayWh: 200.0,
          timestamp: DateTime.fromMillisecondsSinceEpoch(105000),
          rawState: 3,
          rawError: 0,
        ),
        referenceTime: s2.timestamp,
      );
      expect(didRecord, isTrue);
      expect(await readingDao.countReadings(), equals(2));
    });

    test(
      'rejects stale battery snapshot older than maxStaleDuration',
      () async {
        final oldSnapshot = createSnapshot(
          voltage: 13.3,
          current: 0.0,
          soc: 80,
          time: DateTime.fromMillisecondsSinceEpoch(100000),
        );

        // Current time is 100 seconds later (> 30s maxStaleDuration)
        final didRecord = await recorder.processTelemetry(
          batterySnapshot: oldSnapshot,
          referenceTime: DateTime.fromMillisecondsSinceEpoch(200000),
        );

        expect(didRecord, isFalse);
        expect(await readingDao.countReadings(), equals(0));
      },
    );

    test(
      'discards stale solar data when recording fresh battery snapshot',
      () async {
        final freshSnapshot = createSnapshot(
          voltage: 13.3,
          current: 2.0,
          soc: 80,
          time: DateTime.fromMillisecondsSinceEpoch(200000),
        );

        // Solar data is 120 seconds old (> 30s maxStaleDuration)
        final staleSolar = VictronMpptData(
          deviceState: VictronDeviceState.bulk,
          chargerError: VictronChargerError.noError,
          batteryVoltage: 13.3,
          batteryCurrent: 10.0,
          solarPower: 150.0,
          yieldTodayWh: 900.0,
          timestamp: DateTime.fromMillisecondsSinceEpoch(80000),
          rawState: 3,
          rawError: 0,
        );

        final didRecord = await recorder.processTelemetry(
          batterySnapshot: freshSnapshot,
          solarData: staleSolar,
          referenceTime: DateTime.fromMillisecondsSinceEpoch(200000),
        );

        expect(didRecord, isTrue);
        expect(await readingDao.countReadings(), equals(1));

        final latest = await readingDao.getLatestReading();
        expect(latest, isNotNull);
        expect(latest!.soc, equals(80));
        expect(latest.voltage, equals(13.3));
        // Solar data must NOT be attached because it was stale!
        expect(latest.solarPower, isNull);
        expect(latest.solarYieldToday, isNull);
      },
    );
  });
}
