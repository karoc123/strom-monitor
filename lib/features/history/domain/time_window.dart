/// Predefined time spans for historical telemetry queries.
enum TimeWindow { hours24, days7, days30, all }

extension TimeWindowExtension on TimeWindow {
  String get label {
    switch (this) {
      case TimeWindow.hours24:
        return '24 Hours';
      case TimeWindow.days7:
        return '7 Days';
      case TimeWindow.days30:
        return '30 Days';
      case TimeWindow.all:
        return 'All Time';
    }
  }

  int getStartTimestampMs() {
    final now = DateTime.now();
    switch (this) {
      case TimeWindow.hours24:
        return now.subtract(const Duration(hours: 24)).millisecondsSinceEpoch;
      case TimeWindow.days7:
        return now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
      case TimeWindow.days30:
        return now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
      case TimeWindow.all:
        return 0;
    }
  }
}
