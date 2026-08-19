import '../../../core/database/models/battery_reading.dart';

/// Aggregated solar yield statistics for a single calendar day.
class DailyYield {
  final DateTime date;
  final double yieldWh;

  const DailyYield({required this.date, required this.yieldWh});

  double get yieldKwh => yieldWh / 1000.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyYield &&
          runtimeType == other.runtimeType &&
          date.year == other.date.year &&
          date.month == other.date.month &&
          date.day == other.date.day &&
          (yieldWh - other.yieldWh).abs() < 0.001;

  @override
  int get hashCode => Object.hash(date.year, date.month, date.day, yieldWh);

  @override
  String toString() => 'DailyYield(date: $date, yieldWh: $yieldWh)';
}

/// Aggregates downsampled or raw battery readings into daily maximum solar yield totals.
class DailyYieldAggregator {
  const DailyYieldAggregator._();

  /// Groups readings by calendar day and computes the maximum [solarYieldToday]
  /// recorded on each day. Days without solar yield data are excluded.
  static List<DailyYield> aggregateByDay(List<BatteryReading> readings) {
    if (readings.isEmpty) return const [];

    final dayMap = <DateTime, double>{};

    for (final r in readings) {
      if (r.solarYieldToday == null) continue;
      final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      final normalizedDate = DateTime(dt.year, dt.month, dt.day);

      final currentMax = dayMap[normalizedDate] ?? 0.0;
      if (r.solarYieldToday! > currentMax) {
        dayMap[normalizedDate] = r.solarYieldToday!;
      }
    }

    final sortedDates = dayMap.keys.toList()..sort();
    return sortedDates.map((date) {
      return DailyYield(date: date, yieldWh: dayMap[date]!);
    }).toList();
  }
}
