import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers/settings_provider.dart';
import 'features/background/background_service_manager.dart';
import 'features/settings/data/settings_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Settings
  final settingsRepo = await SettingsRepository.create();
  final settings = settingsRepo.loadSettings();

  // Initialize WorkManager background worker
  await BackgroundServiceManager.initialize();
  if (settings.backgroundIntervalMinutes > 0) {
    await BackgroundServiceManager.updateSchedule(
      settings.backgroundIntervalMinutes,
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesRepositoryProvider.overrideWithValue(settingsRepo),
      ],
      child: const JbdBatteryMonitorApp(),
    ),
  );
}
