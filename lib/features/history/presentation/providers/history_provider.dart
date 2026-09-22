import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/models/battery_reading.dart';
import '../../../../core/providers/database_provider.dart';
import '../../data/downsampler.dart';
import '../../domain/time_window.dart';

enum HistoryMetric { soc, current, power, voltage, solarPower, solarYield }

extension HistoryMetricExtension on HistoryMetric {
  String get label {
    switch (this) {
      case HistoryMetric.soc:
        return 'SoC (%)';
      case HistoryMetric.current:
        return 'Current (A)';
      case HistoryMetric.power:
        return 'Power (W)';
      case HistoryMetric.voltage:
        return 'Voltage (V)';
      case HistoryMetric.solarPower:
        return 'Solar (W)';
      case HistoryMetric.solarYield:
        return 'Yield (Wh)';
    }
  }

  String get unit {
    switch (this) {
      case HistoryMetric.soc:
        return '%';
      case HistoryMetric.current:
        return 'A';
      case HistoryMetric.power:
      case HistoryMetric.solarPower:
        return 'W';
      case HistoryMetric.voltage:
        return 'V';
      case HistoryMetric.solarYield:
        return 'Wh';
    }
  }
}

class SelectedTimeWindowNotifier extends Notifier<TimeWindow> {
  @override
  TimeWindow build() => TimeWindow.hours24;

  @override
  set state(TimeWindow value) => super.state = value;
}

final selectedTimeWindowProvider =
    NotifierProvider<SelectedTimeWindowNotifier, TimeWindow>(
      SelectedTimeWindowNotifier.new,
    );

class SelectedMetricNotifier extends Notifier<HistoryMetric> {
  @override
  HistoryMetric build() => HistoryMetric.soc;

  @override
  set state(HistoryMetric value) => super.state = value;
}

final selectedMetricProvider =
    NotifierProvider<SelectedMetricNotifier, HistoryMetric>(
      SelectedMetricNotifier.new,
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
