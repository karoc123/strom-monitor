import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jbd_battery_monitor/core/database/models/battery_reading.dart';
import 'package:jbd_battery_monitor/features/history/presentation/providers/history_provider.dart';
import 'package:jbd_battery_monitor/features/history/presentation/widgets/history_chart.dart';

void main() {
  group('HistoryChart Widget Tests', () {
    final sampleReadings = [
      BatteryReading(
        timestamp: DateTime(2026, 8, 18, 12, 0).millisecondsSinceEpoch,
        soc: 80,
        voltage: 13.3,
        current: 5.0,
        power: 66.5,
        solarPower: 80.0,
        solarYieldToday: 500.0,
      ),
      BatteryReading(
        timestamp: DateTime(2026, 8, 19, 12, 0).millisecondsSinceEpoch,
        soc: 90,
        voltage: 13.5,
        current: 6.0,
        power: 81.0,
        solarPower: 120.0,
        solarYieldToday: 950.0,
      ),
    ];

    testWidgets('renders LineChart for battery and solar power metrics', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryChart(
              readings: sampleReadings,
              metric: HistoryMetric.soc,
            ),
          ),
        ),
      );

      expect(find.byType(LineChart), findsOneWidget);
      expect(find.byType(BarChart), findsNothing);

      // Also test solar power (instantaneous W -> line chart)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryChart(
              readings: sampleReadings,
              metric: HistoryMetric.solarPower,
            ),
          ),
        ),
      );

      expect(find.byType(LineChart), findsOneWidget);
      expect(find.byType(BarChart), findsNothing);
    });

    testWidgets('renders BarChart for solar yield metric (daily bar chart)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryChart(
              readings: sampleReadings,
              metric: HistoryMetric.solarYield,
            ),
          ),
        ),
      );

      expect(find.byType(BarChart), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('renders empty state message when no data is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HistoryChart(readings: [], metric: HistoryMetric.soc),
          ),
        ),
      );

      expect(find.text('No data recorded for this time range'), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
      expect(find.byType(BarChart), findsNothing);
    });
  });
}
