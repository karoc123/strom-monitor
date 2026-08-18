import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/models/battery_reading.dart';
import '../../../../core/providers/database_provider.dart';
import '../../data/downsampler.dart';
import '../../domain/time_window.dart';

enum HistoryMetric { soc, voltage, current, power }

extension HistoryMetricExtension on HistoryMetric {
  String get label {
    switch (this) {
      case HistoryMetric.soc:
        return 'SoC (%)';
      case HistoryMetric.voltage:
        return 'Voltage (V)';
      case HistoryMetric.current:
        return 'Current (A)';
      case HistoryMetric.power:
        return 'Power (W)';
    }
  }

  String get unit {
    switch (this) {
      case HistoryMetric.soc:
        return '%';
      case HistoryMetric.voltage:
        return 'V';
      case HistoryMetric.current:
        return 'A';
      case HistoryMetric.power:
        return 'W';
    }
  }
}

final selectedTimeWindowProvider = StateProvider<TimeWindow>(
  (ref) => TimeWindow.hours24,
);

final selectedMetricProvider = StateProvider<HistoryMetric>(
  (ref) => HistoryMetric.soc,
);

final historyReadingsProvider =
    FutureProvider.autoDispose<List<BatteryReading>>((ref) async {
      final dao = ref.watch(readingDaoProvider);
      final timeWindow = ref.watch(selectedTimeWindowProvider);

      final startMs = timeWindow.getStartTimestampMs();
      final endMs = DateTime.now().millisecondsSinceEpoch;

      final rawReadings = await dao.getReadingsBetween(startMs, endMs);
      // Downsample to max 120 points for smooth charting
      return Downsampler.downsampleByBuckets(rawReadings, targetCount: 120);
    });
