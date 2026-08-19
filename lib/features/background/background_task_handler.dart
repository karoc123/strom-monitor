import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import '../../core/ble/ble_client.dart';
import '../../core/ble/victron_ble_client.dart';
import '../../core/database/app_database.dart';
import '../../core/database/models/battery_reading.dart';
import '../../core/database/reading_dao.dart';
import '../../core/protocol/victron/victron_mppt_data.dart';
import '../settings/data/settings_repository.dart';

const String kBackgroundFetchTask = 'de.karoc.strommonitor.fetch_telemetry';
const String kBackgroundPeriodicTaskTag = 'strommonitor_periodic_telemetry';

/// Top-level callback dispatcher required by Android WorkManager.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      final settingsRepo = await SettingsRepository.create();
      final settings = settingsRepo.loadSettings();

      if (!settings.hasBmsDevice && !settings.hasVictronDevice) {
        // No devices configured
        return Future.value(true);
      }

      // Query BLE telemetry for both BMS and Victron in parallel
      Future<BatterySnapshot?> bmsFuture = settings.hasBmsDevice
          ? BleClient.fetchOneShotTelemetry(
              deviceId: settings.targetDeviceMac!,
              timeout: const Duration(seconds: 10),
            )
          : Future.value(null);

      Future<VictronMpptData?> solarFuture = settings.hasVictronDevice
          ? VictronBleClient.fetchOneShotSolarTelemetry(
              targetMac: settings.victronDeviceMac!,
              encryptionKey: settings.victronEncryptionKey!,
              timeout: const Duration(seconds: 5),
            )
          : Future.value(null);

      final results = await Future.wait([bmsFuture, solarFuture]);
      final bmsSnapshot = results[0] as BatterySnapshot?;
      final solarData = results[1] as VictronMpptData?;

      // If BMS is configured, but query failed (bmsSnapshot == null),
      // skip recording to prevent recording fake/stale 0% SoC readings.
      if (settings.hasBmsDevice && bmsSnapshot == null) {
        return Future.value(true);
      }

      if (bmsSnapshot != null || solarData != null) {
        final appDb = AppDatabase.instance;
        final dao = ReadingDao(appDb);

        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final info = bmsSnapshot?.basicInfo;
        final cells = bmsSnapshot?.cellVoltages ?? const [];

        final reading = BatteryReading(
          timestamp:
              bmsSnapshot?.timestamp.millisecondsSinceEpoch ??
              solarData?.timestamp.millisecondsSinceEpoch ??
              nowMs,
          soc: info?.soc ?? 0,
          voltage: info?.voltage ?? (solarData?.batteryVoltage ?? 0.0),
          current: info?.current ?? 0.0,
          power: info?.power ?? 0.0,
          cellVoltage1: cells.isNotEmpty ? cells[0] : null,
          cellVoltage2: cells.length > 1 ? cells[1] : null,
          cellVoltage3: cells.length > 2 ? cells[2] : null,
          cellVoltage4: cells.length > 3 ? cells[3] : null,
          tempBms: info?.tempBms,
          tempCells: info?.tempCells,
          cycles: info?.cycleCount,
          solarPower: solarData?.solarPower,
          solarYieldToday: solarData?.yieldTodayWh,
          solarVoltage: solarData?.batteryVoltage,
          solarCurrent: solarData?.batteryCurrent,
          solarState: solarData?.rawState,
        );

        await dao.insertReading(reading);

        // Optional auto-prune
        if (settings.autoPruneDays > 0) {
          final pruneThreshold = DateTime.now()
              .subtract(Duration(days: settings.autoPruneDays))
              .millisecondsSinceEpoch;
          await dao.pruneOlderThan(pruneThreshold);
        }
      }

      return Future.value(true);
    } catch (_) {
      // Abort silently on failure or out of range, next cycle will re-attempt
      return Future.value(true);
    }
  });
}
