import 'dart:convert';
import '../../../core/database/models/battery_reading.dart';

/// Service responsible for serializing and deserializing historical readings
/// to CSV and JSON formats.
class DataExporter {
  const DataExporter._();

  /// Serializes a list of [BatteryReading] to a standardized CSV format string.
  static String exportToCsv(List<BatteryReading> readings) {
    final buffer = StringBuffer();
    buffer.writeln(BatteryReading.csvHeader);
    for (final reading in readings) {
      buffer.writeln(reading.toCsvRow());
    }
    return buffer.toString();
  }

  /// Parses CSV format text into a list of [BatteryReading].
  static List<BatteryReading> importFromCsv(String csvText) {
    final lines = const LineSplitter().convert(csvText);
    if (lines.isEmpty) return const [];

    final readings = <BatteryReading>[];
    // Skip header line
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final reading = BatteryReading.fromCsvRow(line);
      if (reading != null) {
        readings.add(reading);
      }
    }
    return readings;
  }

  /// Serializes a list of [BatteryReading] to formatted JSON string.
  static String exportToJson(List<BatteryReading> readings) {
    final list = readings.map((r) => r.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  /// Parses JSON string into a list of [BatteryReading].
  static List<BatteryReading> importFromJson(String jsonText) {
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! List) return const [];

      final readings = <BatteryReading>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          readings.add(BatteryReading.fromJson(item));
        }
      }
      return readings;
    } catch (_) {
      return const [];
    }
  }

  /// Parses CSV or JSON string into a list of [BatteryReading], automatically
  /// detecting the underlying format.
  static List<BatteryReading> importFromText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];

    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      final jsonReadings = importFromJson(trimmed);
      if (jsonReadings.isNotEmpty) {
        return jsonReadings;
      }
    }
    return importFromCsv(trimmed);
  }
}
