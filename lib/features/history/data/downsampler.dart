import '../../../core/database/models/battery_reading.dart';

/// Utility to downsample time-series battery readings for smooth charting performance.
class Downsampler {
  const Downsampler._();

  /// Downsamples a list of [readings] to approximately [targetCount] points using
  /// bucket time-averaging.
  static List<BatteryReading> downsampleByBuckets(
    List<BatteryReading> readings, {
    int targetCount = 120,
  }) {
    if (readings.length <= targetCount || readings.isEmpty) {
      return readings;
    }

    final result = <BatteryReading>[];
    final chunkSize = readings.length / targetCount;

    for (int i = 0; i < targetCount; i++) {
      final startIndex = (i * chunkSize).floor();
      final endIndex = ((i + 1) * chunkSize).floor().clamp(0, readings.length);

      if (startIndex >= endIndex) {
        continue;
      }

      final bucket = readings.sublist(startIndex, endIndex);

      // Aggregate bucket
      int sumTimestamp = 0;
      double sumSoc = 0;
      double sumVoltage = 0;
      double sumCurrent = 0;
      double sumPower = 0;
      double? sumC1, sumC2, sumC3, sumC4;
      double? sumTempBms, sumTempCells;
      int count = bucket.length;

      for (final r in bucket) {
        sumTimestamp += r.timestamp;
        sumSoc += r.soc;
        sumVoltage += r.voltage;
        sumCurrent += r.current;
        sumPower += r.power;

        if (r.cellVoltage1 != null) {
          sumC1 = (sumC1 ?? 0) + r.cellVoltage1!;
        }
        if (r.cellVoltage2 != null) {
          sumC2 = (sumC2 ?? 0) + r.cellVoltage2!;
        }
        if (r.cellVoltage3 != null) {
          sumC3 = (sumC3 ?? 0) + r.cellVoltage3!;
        }
        if (r.cellVoltage4 != null) {
          sumC4 = (sumC4 ?? 0) + r.cellVoltage4!;
        }
        if (r.tempBms != null) {
          sumTempBms = (sumTempBms ?? 0) + r.tempBms!;
        }
        if (r.tempCells != null) {
          sumTempCells = (sumTempCells ?? 0) + r.tempCells!;
        }
      }

      result.add(
        BatteryReading(
          timestamp: sumTimestamp ~/ count,
          soc: (sumSoc / count).round().clamp(0, 100),
          voltage: sumVoltage / count,
          current: sumCurrent / count,
          power: sumPower / count,
          cellVoltage1: sumC1 != null ? sumC1 / count : null,
          cellVoltage2: sumC2 != null ? sumC2 / count : null,
          cellVoltage3: sumC3 != null ? sumC3 / count : null,
          cellVoltage4: sumC4 != null ? sumC4 / count : null,
          tempBms: sumTempBms != null ? sumTempBms / count : null,
          tempCells: sumTempCells != null ? sumTempCells / count : null,
          cycles: bucket.last.cycles,
        ),
      );
    }

    return result;
  }
}
