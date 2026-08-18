import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import '../../core/ble/ble_client.dart';
import '../../core/database/app_database.dart';
import '../../core/database/models/battery_reading.dart';
import '../../core/database/reading_dao.dart';
import '../settings/data/settings_repository.dart';

const String kBackgroundFetchTask =
    'de.karoc.jbd_battery_monitor.fetch_telemetry';
const String kBackgroundPeriodicTaskTag = 'jbd_periodic_telemetry';

/// Top-level callback dispatcher required by Android WorkManager.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      final settingsRepo = await SettingsRepository.create();
      final settings = settingsRepo.loadSettings();

      final targetMac = settings.targetDeviceMac;
      if (targetMac == null || targetMac.isEmpty) {
        // No target device configured
        return Future.value(true);
      }

      // Query BLE telemetry with a strict 10s timeout
      final snapshot = await BleClient.fetchOneShotTelemetry(
        deviceId: targetMac,
        timeout: const Duration(seconds: 10),
      );

      if (snapshot != null) {
        final appDb = AppDatabase.instance;
        final dao = ReadingDao(appDb);

        final info = snapshot.basicInfo;
        final cells = snapshot.cellVoltages;

        final reading = BatteryReading(
          timestamp: snapshot.timestamp.millisecondsSinceEpoch,
          soc: info.soc,
          voltage: info.voltage,
          current: info.current,
          power: info.power,
          cellVoltage1: cells.isNotEmpty ? cells[0] : null,
          cellVoltage2: cells.length > 1 ? cells[1] : null,
          cellVoltage3: cells.length > 2 ? cells[2] : null,
          cellVoltage4: cells.length > 3 ? cells[3] : null,
          tempBms: info.tempBms,
          tempCells: info.tempCells,
          cycles: info.cycleCount,
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
