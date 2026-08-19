import 'package:flutter_test/flutter_test.dart';
import 'package:jbd_battery_monitor/core/database/models/battery_reading.dart';
import 'package:jbd_battery_monitor/features/history/data/data_exporter.dart';

void main() {
  group('DataExporter & Importer Tests', () {
    final sampleReadings = [
      const BatteryReading(
        timestamp: 1700000000000,
        soc: 90,
        voltage: 13.35,
        current: 2.50,
        power: 33.375,
        cellVoltage1: 3.338,
        cellVoltage2: 3.337,
        cellVoltage3: 3.338,
        cellVoltage4: 3.337,
        tempBms: 22.0,
        tempCells: 21.5,
        cycles: 10,
        solarPower: 85.0,
        solarYieldToday: 1200.0,
        solarVoltage: 19.5,
        solarCurrent: 4.3,
        solarState: 3,
      ),
      const BatteryReading(
        timestamp: 1700000060000,
        soc: 89,
        voltage: 13.30,
        current: -1.20,
        power: -15.96,
        cellVoltage1: 3.325,
        cellVoltage2: 3.325,
        cellVoltage3: 3.325,
        cellVoltage4: 3.325,
        tempBms: 22.2,
        tempCells: 21.8,
        cycles: 10,
        solarPower: 110.0,
        solarYieldToday: 1250.0,
        solarVoltage: 19.8,
        solarCurrent: 5.5,
        solarState: 3,
      ),
    ];

    test('exports to CSV and imports back without loss', () {
      final csvString = DataExporter.exportToCsv(sampleReadings);
      expect(csvString.contains('timestamp_ms'), isTrue);
      expect(csvString.contains('1700000000000'), isTrue);
      expect(csvString.contains('1700000060000'), isTrue);

      final imported = DataExporter.importFromCsv(csvString);
      expect(imported.length, equals(2));
      expect(imported[0].timestamp, equals(1700000000000));
      expect(imported[0].soc, equals(90));
      expect(imported[0].voltage, closeTo(13.35, 0.001));
      expect(imported[0].current, closeTo(2.50, 0.001));
      expect(imported[0].power, closeTo(33.375, 0.001));
      expect(imported[0].cellVoltage1, closeTo(3.338, 0.001));
      expect(imported[0].tempBms, closeTo(22.0, 0.001));
      expect(imported[0].cycles, equals(10));
      expect(imported[0].solarPower, closeTo(85.0, 0.001));
      expect(imported[0].solarYieldToday, closeTo(1200.0, 0.001));
      expect(imported[0].solarVoltage, closeTo(19.5, 0.001));
      expect(imported[0].solarCurrent, closeTo(4.3, 0.001));
      expect(imported[0].solarState, equals(3));

      expect(imported[1].timestamp, equals(1700000060000));
      expect(imported[1].current, closeTo(-1.20, 0.001));
      expect(imported[1].solarPower, closeTo(110.0, 0.001));
    });

    test('exports to JSON and imports back without loss', () {
      final jsonString = DataExporter.exportToJson(sampleReadings);
      expect(jsonString.contains('"soc": 90'), isTrue);
      expect(jsonString.contains('"solar_power": 85.0'), isTrue);

      final imported = DataExporter.importFromJson(jsonString);
      expect(imported.length, equals(2));
      expect(imported[0].timestamp, equals(1700000000000));
      expect(imported[0].soc, equals(90));
      expect(imported[0].solarPower, closeTo(85.0, 0.001));
      expect(imported[1].current, closeTo(-1.20, 0.001));
      expect(imported[1].solarPower, closeTo(110.0, 0.001));
    });

    test('handles corrupt CSV/JSON gracefully during import', () {
      expect(DataExporter.importFromCsv('invalid,header,row'), isEmpty);
      expect(DataExporter.importFromJson('not a json'), isEmpty);
    });
  });
}
