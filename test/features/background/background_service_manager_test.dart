import 'package:flutter_test/flutter_test.dart';
import 'package:jbd_battery_monitor/features/background/background_service_manager.dart';
import 'package:jbd_battery_monitor/features/background/background_task_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackgroundServiceManager Tests', () {
    test(
      'task constants are defined and match background registration contract',
      () {
        expect(
          kBackgroundFetchTask,
          equals('de.karoc.strommonitor.fetch_telemetry'),
        );
        expect(
          kBackgroundPeriodicTaskTag,
          equals('strommonitor_periodic_telemetry'),
        );
      },
    );

    test(
      'initialize runs and handles unsupported platforms gracefully',
      () async {
        await expectLater(BackgroundServiceManager.initialize(), completes);
      },
    );

    test('cancelAll completes without throwing', () async {
      await expectLater(BackgroundServiceManager.cancelAll(), completes);
    });

    test('updateSchedule with non-positive intervals calls cancellation path gracefully', () async {
      await expectLater(BackgroundServiceManager.updateSchedule(0), completes);
      await expectLater(BackgroundServiceManager.updateSchedule(-5), completes);
    });

    test('updateSchedule with positive intervals executes and handles platform gracefully', () async {
      // Below 15 min (should clamp to 15 without throwing)
      await expectLater(BackgroundServiceManager.updateSchedule(5), completes);
      // Above 15 min
      await expectLater(BackgroundServiceManager.updateSchedule(30), completes);
    });
  });
}
