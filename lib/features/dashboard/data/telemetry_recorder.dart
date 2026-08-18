import '../../../core/ble/ble_client.dart';
import '../../../core/database/models/battery_reading.dart';
import '../../../core/database/reading_dao.dart';

/// Handles throttled recording of live BLE telemetry snapshots to SQLite.
class TelemetryRecorder {
  final ReadingDao readingDao;
  final int minIntervalSeconds;
  final int socDeltaThreshold;
  final double voltageDeltaThreshold;

  BatteryReading? _lastRecordedReading;

  TelemetryRecorder({
    required this.readingDao,
    this.minIntervalSeconds = 60,
    this.socDeltaThreshold = 1,
    this.voltageDeltaThreshold = 0.2,
  });

  /// Evaluates whether the incoming [snapshot] should be recorded to SQLite.
  /// Returns `true` if inserted, `false` if throttled.
  Future<bool> processSnapshot(BatterySnapshot snapshot) async {
    final info = snapshot.basicInfo;
    final cells = snapshot.cellVoltages;

    final candidate = BatteryReading(
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

    if (_shouldRecord(candidate)) {
      await readingDao.insertReading(candidate);
      _lastRecordedReading = candidate;
      return true;
    }

    return false;
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

    return false;
  }
}
