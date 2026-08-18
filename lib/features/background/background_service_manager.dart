import 'package:workmanager/workmanager.dart';
import 'background_task_handler.dart';

/// Manager for scheduling and updating Android WorkManager periodic tasks.
class BackgroundServiceManager {
  const BackgroundServiceManager._();

  /// Initializes the WorkManager plugin with the callback dispatcher.
  static Future<void> initialize() async {
    try {
      await Workmanager().initialize(callbackDispatcher);
    } catch (_) {
      // Graceful fallback on non-Android platforms (e.g. Linux desktop test run)
    }
  }

  /// Schedules periodic background telemetry logging.
  /// [intervalMinutes] must be at least 15 (Android OS WorkManager minimum).
  /// If [intervalMinutes] <= 0, cancels the periodic task.
  static Future<void> updateSchedule(int intervalMinutes) async {
    try {
      await cancelAll();

      if (intervalMinutes > 0) {
        final clampedMinutes = intervalMinutes < 15 ? 15 : intervalMinutes;
        await Workmanager().registerPeriodicTask(
          kBackgroundPeriodicTaskTag,
          kBackgroundFetchTask,
          frequency: Duration(minutes: clampedMinutes),
          initialDelay: const Duration(minutes: 1),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
          constraints: Constraints(
            networkType: NetworkType.notRequired,
            requiresBatteryNotLow: false,
            requiresCharging: false,
            requiresDeviceIdle: false,
            requiresStorageNotLow: false,
          ),
        );
      }
    } catch (_) {
      // Graceful ignore on unsupported platforms
    }
  }

  /// Cancels all scheduled WorkManager tasks.
  static Future<void> cancelAll() async {
    try {
      await Workmanager().cancelByUniqueName(kBackgroundPeriodicTaskTag);
    } catch (_) {}
  }
}
