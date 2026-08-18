/// Application settings entity.
class AppSettings {
  final String? targetDeviceMac;
  final String? targetDeviceName;
  final int backgroundIntervalMinutes; // 0 = disabled, 15, 30, 60, 120
  final int foregroundWriteIntervalSeconds;
  final int autoPruneDays; // 0 = disabled, 30, 90, 365

  const AppSettings({
    this.targetDeviceMac,
    this.targetDeviceName,
    this.backgroundIntervalMinutes = 15,
    this.foregroundWriteIntervalSeconds = 60,
    this.autoPruneDays = 0,
  });

  bool get isBackgroundLoggingEnabled => backgroundIntervalMinutes > 0;

  AppSettings copyWith({
    String? targetDeviceMac,
    String? targetDeviceName,
    int? backgroundIntervalMinutes,
    int? foregroundWriteIntervalSeconds,
    int? autoPruneDays,
  }) {
    return AppSettings(
      targetDeviceMac: targetDeviceMac ?? this.targetDeviceMac,
      targetDeviceName: targetDeviceName ?? this.targetDeviceName,
      backgroundIntervalMinutes:
          backgroundIntervalMinutes ?? this.backgroundIntervalMinutes,
      foregroundWriteIntervalSeconds:
          foregroundWriteIntervalSeconds ?? this.foregroundWriteIntervalSeconds,
      autoPruneDays: autoPruneDays ?? this.autoPruneDays,
    );
  }
}
