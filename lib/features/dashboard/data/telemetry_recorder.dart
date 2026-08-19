import '../../../core/ble/ble_client.dart';
import '../../../core/database/models/battery_reading.dart';
import '../../../core/database/reading_dao.dart';
import '../../../core/protocol/victron/victron_mppt_data.dart';

/// Handles throttled recording of live BLE telemetry snapshots to SQLite.
class TelemetryRecorder {
  final ReadingDao readingDao;
  final int minIntervalSeconds;
  final int socDeltaThreshold;
  final double voltageDeltaThreshold;
  final double solarPowerDeltaThreshold;
  final Duration maxStaleDuration;

  BatteryReading? _lastRecordedReading;

  TelemetryRecorder({
    required this.readingDao,
    this.minIntervalSeconds = 60,
    this.socDeltaThreshold = 1,
    this.voltageDeltaThreshold = 0.2,
    this.solarPowerDeltaThreshold = 15.0,
    this.maxStaleDuration = const Duration(seconds: 30),
  });

  /// Evaluates whether the incoming telemetry should be recorded to SQLite.
  /// Returns `true` if inserted, `false` if throttled or stale.
  Future<bool> processTelemetry({
    BatterySnapshot? batterySnapshot,
    VictronMpptData? solarData,
    DateTime? referenceTime,
  }) async {
    final now = referenceTime ?? DateTime.now();

    // Check battery snapshot staleness against reference time
    final isBatteryStale =
        batterySnapshot != null &&
        now.difference(batterySnapshot.timestamp).abs() > maxStaleDuration;
    final validSnapshot = isBatteryStale ? null : batterySnapshot;

    // Check solar data staleness against battery snapshot (or reference time / now)
    final solarRefTime = validSnapshot?.timestamp ?? now;
    final isSolarStale =
        solarData != null &&
        solarRefTime.difference(solarData.timestamp).abs() > maxStaleDuration;
    final validSolar = isSolarStale ? null : solarData;

    if (validSnapshot == null && validSolar == null) return false;

    final timestamp = (validSnapshot?.timestamp ?? validSolar?.timestamp ?? now)
        .millisecondsSinceEpoch;

    final info = validSnapshot?.basicInfo;
    final cells = validSnapshot?.cellVoltages ?? const [];

    final candidate = BatteryReading(
      timestamp: timestamp,
      soc: info?.soc ?? 0,
      voltage: info?.voltage ?? (validSolar?.batteryVoltage ?? 0.0),
      current: info?.current ?? 0.0,
      power: info?.power ?? 0.0,
      cellVoltage1: cells.isNotEmpty ? cells[0] : null,
      cellVoltage2: cells.length > 1 ? cells[1] : null,
      cellVoltage3: cells.length > 2 ? cells[2] : null,
      cellVoltage4: cells.length > 3 ? cells[3] : null,
      tempBms: info?.tempBms,
      tempCells: info?.tempCells,
      cycles: info?.cycleCount,
      solarPower: validSolar?.solarPower,
      solarYieldToday: validSolar?.yieldTodayWh,
      solarVoltage: validSolar?.batteryVoltage,
      solarCurrent: validSolar?.batteryCurrent,
      solarState: validSolar?.rawState,
    );

    if (_shouldRecord(candidate)) {
      await readingDao.insertReading(candidate);
      _lastRecordedReading = candidate;
      return true;
    }

    return false;
  }

  /// Helper for battery snapshot processing
  Future<bool> processSnapshot(
    BatterySnapshot snapshot, {
    VictronMpptData? solarData,
    DateTime? referenceTime,
  }) {
    return processTelemetry(
      batterySnapshot: snapshot,
      solarData: solarData,
      referenceTime: referenceTime ?? snapshot.timestamp,
    );
  }

  bool _shouldRecord(BatteryReading reading) {
    if (_lastRecordedReading == null) {
      return true;
    }

    final last = _lastRecordedReading!;
    final elapsedSec = (reading.timestamp - last.timestamp) / 1000.0;

    // Time elapsed threshold
    if (elapsedSec >= minIntervalSeconds) {
      return true;
    }

    // Significant SoC change
    if ((reading.soc - last.soc).abs() >= socDeltaThreshold) {
      return true;
    }

    // Significant Voltage change
    if ((reading.voltage - last.voltage).abs() >= voltageDeltaThreshold) {
      return true;
    }

    // Significant Solar Power change
    if (reading.solarPower != null && last.solarPower != null) {
      if ((reading.solarPower! - last.solarPower!).abs() >=
          solarPowerDeltaThreshold) {
        return true;
      }
    } else if (reading.solarPower != null && last.solarPower == null) {
      return true;
    }

    return false;
  }
}
