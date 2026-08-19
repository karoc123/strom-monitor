import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/settings/data/settings_repository.dart';
import '../../features/settings/domain/app_settings.dart';

final sharedPreferencesRepositoryProvider = Provider<SettingsRepository>((ref) {
  throw UnimplementedError(
    'Initialize sharedPreferencesRepositoryProvider in main()',
  );
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsRepository _repository;

  SettingsNotifier(this._repository) : super(_repository.loadSettings());

  Future<void> setTargetDevice({
    required String mac,
    required String name,
  }) async {
    await _repository.saveTargetDevice(mac: mac, name: name);
    state = state.copyWith(targetDeviceMac: mac, targetDeviceName: name);
  }

  Future<void> removeTargetDevice() async {
    await _repository.removeTargetDevice();
    state = state.copyWith(clearBmsDevice: true);
  }

  Future<void> setVictronDevice({
    required String mac,
    required String name,
    required String encryptionKey,
  }) async {
    await _repository.saveVictronDevice(
      mac: mac,
      name: name,
      encryptionKey: encryptionKey,
    );
    state = state.copyWith(
      victronDeviceMac: mac,
      victronDeviceName: name,
      victronEncryptionKey: encryptionKey,
    );
  }

  Future<void> removeVictronDevice() async {
    await _repository.removeVictronDevice();
    state = state.copyWith(clearVictronDevice: true);
  }

  Future<void> setBackgroundInterval(int minutes) async {
    await _repository.saveBackgroundInterval(minutes);
    state = state.copyWith(backgroundIntervalMinutes: minutes);
  }

  Future<void> setForegroundWriteInterval(int seconds) async {
    await _repository.saveForegroundWriteInterval(seconds);
    state = state.copyWith(foregroundWriteIntervalSeconds: seconds);
  }

  Future<void> setAutoPruneDays(int days) async {
    await _repository.saveAutoPruneDays(days);
    state = state.copyWith(autoPruneDays: days);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  final repo = ref.watch(sharedPreferencesRepositoryProvider);
  return SettingsNotifier(repo);
});
