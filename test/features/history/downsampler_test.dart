import 'package:flutter_test/flutter_test.dart';
import 'package:jbd_battery_monitor/core/database/models/battery_reading.dart';
import 'package:jbd_battery_monitor/features/history/data/downsampler.dart';

void main() {
  group('Downsampler', () {
    test('returns original list if size is below or equal target count', () {
      final list = [
        BatteryReading(
          timestamp: 100,
          soc: 50,
          voltage: 13.0,
          current: 0,
          power: 0,
        ),
        BatteryReading(
          timestamp: 200,
          soc: 60,
          voltage: 13.2,
          current: 1,
          power: 13.2,
        ),
      ];

      final downsampled = Downsampler.downsampleByBuckets(
        list,
        targetCount: 10,
      );
      expect(downsampled.length, equals(2));
      expect(downsampled, equals(list));
    });

    test('averages readings into target number of uniform buckets', () {
      final list = <BatteryReading>[];
      // Create 100 points
      for (int i = 0; i < 100; i++) {
        list.add(
          BatteryReading(
            timestamp: i * 1000,
            soc: i,
            voltage: 12.0 + (i * 0.02),
            current: (i % 2 == 0) ? 2.0 : -2.0,
            power: (12.0 + (i * 0.02)) * ((i % 2 == 0) ? 2.0 : -2.0),
          ),
        );
      }

      final downsampled = Downsampler.downsampleByBuckets(
        list,
        targetCount: 10,
      );
      expect(downsampled.length, equals(10));

      // Check first bucket average (i: 0..9) -> avg soc = 4.5 -> 5, avg voltage = 12.09
      expect(downsampled.first.soc, inInclusiveRange(4, 5));
      expect(downsampled.first.voltage, closeTo(12.09, 0.01));
    });

    test('handles empty list gracefully', () {
      final downsampled = Downsampler.downsampleByBuckets([], targetCount: 10);
      expect(downsampled, isEmpty);
    });
  });
}
