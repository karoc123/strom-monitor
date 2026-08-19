/// Application settings entity.
class AppSettings {
  final String? targetDeviceMac;
  final String? targetDeviceName;
  final String? victronDeviceMac;
  final String? victronDeviceName;
  final String? victronEncryptionKey; // 32-character Hex key
  final int backgroundIntervalMinutes; // 0 = disabled, 15, 30, 60, 120
  final int foregroundWriteIntervalSeconds;
  final int autoPruneDays; // 0 = disabled, 30, 90, 365

  const AppSettings({
    this.targetDeviceMac,
    this.targetDeviceName,
    this.victronDeviceMac,
    this.victronDeviceName,
    this.victronEncryptionKey,
    this.backgroundIntervalMinutes = 15,
    this.foregroundWriteIntervalSeconds = 60,
    this.autoPruneDays = 0,
  });

  bool get isBackgroundLoggingEnabled => backgroundIntervalMinutes > 0;
  bool get hasBmsDevice =>
      targetDeviceMac != null && targetDeviceMac!.isNotEmpty;
  bool get hasVictronDevice =>
      victronDeviceMac != null &&
      victronDeviceMac!.isNotEmpty &&
      victronEncryptionKey != null &&
      victronEncryptionKey!.isNotEmpty;

  AppSettings copyWith({
    String? targetDeviceMac,
    String? targetDeviceName,
    String? victronDeviceMac,
    String? victronDeviceName,
    String? victronEncryptionKey,
    int? backgroundIntervalMinutes,
    int? foregroundWriteIntervalSeconds,
    int? autoPruneDays,
    bool clearVictronDevice = false,
    bool clearBmsDevice = false,
  }) {
    return AppSettings(
      targetDeviceMac: clearBmsDevice
          ? null
          : (targetDeviceMac ?? this.targetDeviceMac),
      targetDeviceName: clearBmsDevice
          ? null
          : (targetDeviceName ?? this.targetDeviceName),
      victronDeviceMac: clearVictronDevice
          ? null
          : (victronDeviceMac ?? this.victronDeviceMac),
      victronDeviceName: clearVictronDevice
          ? null
          : (victronDeviceName ?? this.victronDeviceName),
      victronEncryptionKey: clearVictronDevice
          ? null
          : (victronEncryptionKey ?? this.victronEncryptionKey),
      backgroundIntervalMinutes:
          backgroundIntervalMinutes ?? this.backgroundIntervalMinutes,
      foregroundWriteIntervalSeconds:
          foregroundWriteIntervalSeconds ?? this.foregroundWriteIntervalSeconds,
      autoPruneDays: autoPruneDays ?? this.autoPruneDays,
    );
  }
}
