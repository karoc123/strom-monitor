import 'package:flutter_test/flutter_test.dart';
import 'package:jbd_battery_monitor/core/database/models/battery_reading.dart';
import 'package:jbd_battery_monitor/features/history/data/daily_yield_aggregator.dart';

void main() {
  group('DailyYieldAggregator Tests', () {
    test('returns empty list for empty readings', () {
      final result = DailyYieldAggregator.aggregateByDay([]);
      expect(result, isEmpty);
    });

    test('ignores readings where solarYieldToday is null', () {
      final readings = [
        BatteryReading(
          timestamp: DateTime(2026, 8, 18, 10, 0).millisecondsSinceEpoch,
          soc: 80,
          voltage: 13.3,
          current: 0,
          power: 0,
          solarYieldToday: null,
        ),
      ];

      final result = DailyYieldAggregator.aggregateByDay(readings);
      expect(result, isEmpty);
    });

    test('correctly extracts maximum yield per day across multiple days', () {
      final day1 = DateTime(2026, 8, 18);
      final day2 = DateTime(2026, 8, 19);

      final readings = [
        // Day 1 readings (accumulating from 100Wh to 850Wh)
        BatteryReading(
          timestamp: DateTime(2026, 8, 18, 8, 0).millisecondsSinceEpoch,
          soc: 70,
          voltage: 13.2,
          current: 2,
          power: 26.4,
          solarYieldToday: 100.0,
        ),
        BatteryReading(
          timestamp: DateTime(2026, 8, 18, 14, 0).millisecondsSinceEpoch,
          soc: 85,
          voltage: 13.5,
          current: 5,
          power: 67.5,
          solarYieldToday: 850.0,
        ),
        BatteryReading(
          timestamp: DateTime(2026, 8, 18, 19, 0).millisecondsSinceEpoch,
          soc: 90,
          voltage: 13.4,
          current: 0,
          power: 0,
          solarYieldToday: 850.0,
        ),

        // Day 2 readings (accumulating to 1250Wh)
        BatteryReading(
          timestamp: DateTime(2026, 8, 19, 9, 0).millisecondsSinceEpoch,
          soc: 88,
          voltage: 13.3,
          current: 3,
          power: 39.9,
          solarYieldToday: 300.0,
        ),
        BatteryReading(
          timestamp: DateTime(2026, 8, 19, 16, 0).millisecondsSinceEpoch,
          soc: 100,
          voltage: 13.6,
          current: 8,
          power: 108.8,
          solarYieldToday: 1250.0,
        ),
      ];

      final result = DailyYieldAggregator.aggregateByDay(readings);

      expect(result.length, equals(2));

      expect(result[0].date, equals(day1));
      expect(result[0].yieldWh, equals(850.0));
      expect(result[0].yieldKwh, closeTo(0.85, 0.001));

      expect(result[1].date, equals(day2));
      expect(result[1].yieldWh, equals(1250.0));
      expect(result[1].yieldKwh, closeTo(1.25, 0.001));
    });
  });
}
