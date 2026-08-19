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
      int socCount = 0;
      double sumVoltage = 0;
      int voltageCount = 0;
      double sumCurrent = 0;
      int currentCount = 0;
      double sumPower = 0;
      int powerCount = 0;
      double? sumC1, sumC2, sumC3, sumC4;
      int c1Count = 0, c2Count = 0, c3Count = 0, c4Count = 0;
      double? sumTempBms, sumTempCells;
      int tempBmsCount = 0, tempCellsCount = 0;
      double? sumSolarPower, sumSolarV, sumSolarI;
      int solarPowerCount = 0, solarVCount = 0, solarICount = 0;
      int count = bucket.length;

      for (final r in bucket) {
        sumTimestamp += r.timestamp;

        final isBmsReading =
            r.cellVoltage1 != null ||
            r.cellVoltage2 != null ||
            r.cellVoltage3 != null ||
            r.cellVoltage4 != null ||
            r.tempBms != null ||
            r.tempCells != null ||
            r.cycles != null ||
            r.soc > 0;

        if (isBmsReading) {
          sumSoc += r.soc;
          socCount++;
        }

        sumVoltage += r.voltage;
        voltageCount++;

        sumCurrent += r.current;
        currentCount++;

        sumPower += r.power;
        powerCount++;

        if (r.cellVoltage1 != null) {
          sumC1 = (sumC1 ?? 0) + r.cellVoltage1!;
          c1Count++;
        }
        if (r.cellVoltage2 != null) {
          sumC2 = (sumC2 ?? 0) + r.cellVoltage2!;
          c2Count++;
        }
        if (r.cellVoltage3 != null) {
          sumC3 = (sumC3 ?? 0) + r.cellVoltage3!;
          c3Count++;
        }
        if (r.cellVoltage4 != null) {
          sumC4 = (sumC4 ?? 0) + r.cellVoltage4!;
          c4Count++;
        }
        if (r.tempBms != null) {
          sumTempBms = (sumTempBms ?? 0) + r.tempBms!;
          tempBmsCount++;
        }
        if (r.tempCells != null) {
          sumTempCells = (sumTempCells ?? 0) + r.tempCells!;
          tempCellsCount++;
        }
        if (r.solarPower != null) {
          sumSolarPower = (sumSolarPower ?? 0) + r.solarPower!;
          solarPowerCount++;
        }
        if (r.solarVoltage != null) {
          sumSolarV = (sumSolarV ?? 0) + r.solarVoltage!;
          solarVCount++;
        }
        if (r.solarCurrent != null) {
          sumSolarI = (sumSolarI ?? 0) + r.solarCurrent!;
          solarICount++;
        }
      }

      final avgSoc = socCount > 0
          ? (sumSoc / socCount).round().clamp(0, 100)
          : bucket.last.soc.clamp(0, 100);

      result.add(
        BatteryReading(
          timestamp: sumTimestamp ~/ count,
          soc: avgSoc,
          voltage: voltageCount > 0 ? sumVoltage / voltageCount : 0.0,
          current: currentCount > 0 ? sumCurrent / currentCount : 0.0,
          power: powerCount > 0 ? sumPower / powerCount : 0.0,
          cellVoltage1: c1Count > 0 ? sumC1! / c1Count : null,
          cellVoltage2: c2Count > 0 ? sumC2! / c2Count : null,
          cellVoltage3: c3Count > 0 ? sumC3! / c3Count : null,
          cellVoltage4: c4Count > 0 ? sumC4! / c4Count : null,
          tempBms: tempBmsCount > 0 ? sumTempBms! / tempBmsCount : null,
          tempCells: tempCellsCount > 0 ? sumTempCells! / tempCellsCount : null,
          cycles: bucket.last.cycles,
          solarPower: solarPowerCount > 0
              ? sumSolarPower! / solarPowerCount
              : null,
          solarYieldToday:
              bucket.last.solarYieldToday, // Max yield of the bucket
          solarVoltage: solarVCount > 0 ? sumSolarV! / solarVCount : null,
          solarCurrent: solarICount > 0 ? sumSolarI! / solarICount : null,
          solarState: bucket.last.solarState,
        ),
      );
    }

    return result;
  }
}
