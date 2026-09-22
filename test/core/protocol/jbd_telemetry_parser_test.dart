import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jbd_battery_monitor/core/protocol/jbd_telemetry_parser.dart';

void main() {
  group('JbdTelemetryParser', () {
    test(
      'parses basic info payload with charging current and temperatures',
      () {
        // 31-byte standard payload
        final payload = Uint8List.fromList([
          0x05, 0x34, // 0-1: Voltage = 1332 -> 13.32 V
          0x00, 0xC8, // 2-3: Current = +200 -> +2.00 A
          0x1F, 0x40, // 4-5: Residual Capacity = 8000 -> 80.00 Ah
          0x27, 0x10, // 6-7: Nominal Capacity = 10000 -> 100.00 Ah
          0x00, 0x2A, // 8-9: Cycles = 42
          0x2E, 0x32, // 10-11: Production Date
          0x00, 0x01, // 12-13: Balance Low
          0x00, 0x00, // 14-15: Balance High
          0x00, 0x00, // 16-17: Protection Status = 0
          0x10, // 18: Software Version = 16 (v1.0)
          0x50, // 19: SoC = 80 %
          0x03, // 20: FET Status (both charge & discharge active)
          0x04, // 21: Number of cells = 4
          0x02, // 22: Number of NTC sensors = 2
          0x0B, 0x85, // 23-24: NTC 1 = 2949 K -> (2949 - 2731) / 10 = 21.8 °C
          0x0B, 0x72, // 25-26: NTC 2 = 2930 K -> (2930 - 2731) / 10 = 19.9 °C
          0x00, 0x00, 0x00, 0x00, // Remaining optional bytes
        ]);

        final info = JbdTelemetryParser.parseBasicInfo(payload);
        expect(info, isNotNull);
        expect(info!.voltage, closeTo(13.32, 0.001));
        expect(info.current, closeTo(2.00, 0.001));
        expect(info.power, closeTo(26.64, 0.01));
        expect(info.soc, equals(80));
        expect(info.remainingCapacityAh, closeTo(80.0, 0.01));
        expect(info.nominalCapacityAh, closeTo(100.0, 0.01));
        expect(info.cycleCount, equals(42));
        expect(info.cellCount, equals(4));
        expect(info.chargeFetEnabled, isTrue);
        expect(info.dischargeFetEnabled, isTrue);
        expect(info.temperatures.length, equals(2));
        expect(info.temperatures[0], closeTo(21.8, 0.05));
        expect(info.temperatures[1], closeTo(19.9, 0.05));
        expect(info.tempBms, closeTo(21.8, 0.05));
        expect(info.tempCells, closeTo(19.9, 0.05));
      },
    );

    test('parses basic info payload with negative (discharging) current', () {
      final payload = Uint8List.fromList([
        0x05, 0x14, // 0-1: Voltage = 1300 -> 13.00 V
        0xFF, 0x9C, // 2-3: Current = -100 -> -1.00 A (2's complement)
        0x13, 0x88, // 4-5: Residual Capacity = 5000 -> 50.00 Ah
        0x27, 0x10, // 6-7: Nominal Capacity = 10000 -> 100.00 Ah
        0x00, 0x0A, // 8-9: Cycles = 10
        0x00, 0x00, // 10-11
        0x00, 0x00, // 12-13
        0x00, 0x00, // 14-15
        0x00, 0x00, // 16-17
        0x10, // 18
        0x32, // 19: SoC = 50 %
        0x02, // 20: FET (Discharge only)
        0x04, // 21: 4 cells
        0x01, // 22: 1 NTC
        0x0B, 0x90, // 23-24: 2960 K -> 22.9 °C
      ]);

      final info = JbdTelemetryParser.parseBasicInfo(payload);
      expect(info, isNotNull);
      expect(info!.voltage, closeTo(13.00, 0.001));
      expect(info.current, closeTo(-1.00, 0.001));
      expect(info.power, closeTo(-13.00, 0.01));
      expect(info.soc, equals(50));
      expect(info.chargeFetEnabled, isFalse);
      expect(info.dischargeFetEnabled, isTrue);
      expect(info.temperatures.length, equals(1));
    });

    test('parses cell voltages (0x04) for 4S battery pack', () {
      final payload = Uint8List.fromList([
        0x0D, 0x04, // Cell 1: 3332 mV -> 3.332 V
        0x0D, 0x09, // Cell 2: 3337 mV -> 3.337 V
        0x0D, 0x05, // Cell 3: 3333 mV -> 3.333 V
        0x0D, 0x02, // Cell 4: 3330 mV -> 3.330 V
      ]);

      final cellVoltages = JbdTelemetryParser.parseCellVoltages(payload);
      expect(cellVoltages.length, equals(4));
      expect(cellVoltages[0], closeTo(3.332, 0.001));
      expect(cellVoltages[1], closeTo(3.337, 0.001));
      expect(cellVoltages[2], closeTo(3.333, 0.001));
      expect(cellVoltages[3], closeTo(3.330, 0.001));
    });

    test('returns empty list or null on truncated payload', () {
      expect(JbdTelemetryParser.parseBasicInfo(Uint8List(10)), isNull);
      expect(JbdTelemetryParser.parseCellVoltages(Uint8List(1)), isEmpty);
    });
  });
}
