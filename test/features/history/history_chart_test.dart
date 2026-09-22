import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jbd_battery_monitor/core/database/models/battery_reading.dart';
import 'package:jbd_battery_monitor/features/history/domain/time_window.dart';
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

    testWidgets(
      'renders dedicated solar empty state when readings have no solar data',
      (tester) async {
        final bmsOnlyReadings = [
          BatteryReading(
            timestamp: DateTime(2026, 8, 18, 12, 0).millisecondsSinceEpoch,
            soc: 80,
            voltage: 13.3,
            current: 5.0,
            power: 66.5,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HistoryChart(
                readings: bmsOnlyReadings,
                metric: HistoryMetric.solarPower,
              ),
            ),
          ),
        );

        expect(
          find.text('No solar power recorded for this time range'),
          findsOneWidget,
        );
        expect(find.byType(LineChart), findsNothing);
      },
    );

    testWidgets(
      'renders LineChart with timeWindow for 24h and 7d and handles gaps',
      (tester) async {
        final readingsWithGap = [
          BatteryReading(
            timestamp: DateTime(2026, 8, 18, 10, 0).millisecondsSinceEpoch,
            soc: 80,
            voltage: 13.3,
            current: 5.0,
            power: 66.5,
            solarPower: 50.0,
          ),
          // 4 hours gap (> 20 min threshold)
          BatteryReading(
            timestamp: DateTime(2026, 8, 18, 14, 0).millisecondsSinceEpoch,
            soc: 85,
            voltage: 13.4,
            current: 5.5,
            power: 73.7,
            solarPower: 150.0,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HistoryChart(
                readings: readingsWithGap,
                metric: HistoryMetric.solarPower,
                timeWindow: TimeWindow.hours24,
              ),
            ),
          ),
        );

        expect(find.byType(LineChart), findsOneWidget);

        // Verify LineChartBarData contains a nullSpot to represent the gap
        final lineChart = tester.widget<LineChart>(find.byType(LineChart));
        final spots = lineChart.data.lineBarsData.first.spots;
        expect(spots.any((s) => s.isNull()), isTrue);

        // Test 7-day window
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HistoryChart(
                readings: readingsWithGap,
                metric: HistoryMetric.solarPower,
                timeWindow: TimeWindow.days7,
              ),
            ),
          ),
        );

        expect(find.byType(LineChart), findsOneWidget);
      },
    );
  });
}
