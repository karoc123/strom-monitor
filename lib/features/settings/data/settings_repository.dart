import 'package:shared_preferences/shared_preferences.dart';
import '../domain/app_settings.dart';

/// Repository managing persistence of user settings in SharedPreferences.
class SettingsRepository {
  static const String _keyTargetMac = 'target_device_mac';
  static const String _keyTargetName = 'target_device_name';
  static const String _keyVictronMac = 'victron_device_mac';
  static const String _keyVictronName = 'victron_device_name';
  static const String _keyVictronKey = 'victron_encryption_key';
  static const String _keyBgInterval = 'bg_interval_minutes';
  static const String _keyFgWriteInterval = 'fg_write_interval_seconds';
  static const String _keyAutoPrune = 'auto_prune_days';

  final SharedPreferences _prefs;

  SettingsRepository(this._prefs);

  static Future<SettingsRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsRepository(prefs);
  }

  AppSettings loadSettings() {
    return AppSettings(
      targetDeviceMac: _prefs.getString(_keyTargetMac),
      targetDeviceName: _prefs.getString(_keyTargetName),
      victronDeviceMac: _prefs.getString(_keyVictronMac),
      victronDeviceName: _prefs.getString(_keyVictronName),
      victronEncryptionKey: _prefs.getString(_keyVictronKey),
      backgroundIntervalMinutes: _prefs.getInt(_keyBgInterval) ?? 15,
      foregroundWriteIntervalSeconds: _prefs.getInt(_keyFgWriteInterval) ?? 60,
      autoPruneDays: _prefs.getInt(_keyAutoPrune) ?? 0,
    );
  }

  Future<void> saveTargetDevice({
    required String mac,
    required String name,
  }) async {
    await _prefs.setString(_keyTargetMac, mac);
    await _prefs.setString(_keyTargetName, name);
  }

  Future<void> removeTargetDevice() async {
    await _prefs.remove(_keyTargetMac);
    await _prefs.remove(_keyTargetName);
  }

  Future<void> saveVictronDevice({
    required String mac,
    required String name,
    required String encryptionKey,
  }) async {
    await _prefs.setString(_keyVictronMac, mac);
    await _prefs.setString(_keyVictronName, name);
    await _prefs.setString(_keyVictronKey, encryptionKey);
  }

  Future<void> removeVictronDevice() async {
    await _prefs.remove(_keyVictronMac);
    await _prefs.remove(_keyVictronName);
    await _prefs.remove(_keyVictronKey);
  }

  Future<void> saveBackgroundInterval(int minutes) async {
    await _prefs.setInt(_keyBgInterval, minutes);
  }

  Future<void> saveForegroundWriteInterval(int seconds) async {
    await _prefs.setInt(_keyFgWriteInterval, seconds);
  }

  Future<void> saveAutoPruneDays(int days) async {
    await _prefs.setInt(_keyAutoPrune, days);
  }
}
