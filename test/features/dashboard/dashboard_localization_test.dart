import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jbd_battery_monitor/core/ble/ble_client.dart';
import 'package:jbd_battery_monitor/core/protocol/jbd_telemetry_parser.dart';
import 'package:jbd_battery_monitor/core/providers/settings_provider.dart';
import 'package:jbd_battery_monitor/features/dashboard/presentation/dashboard_screen.dart';
import 'package:jbd_battery_monitor/features/dashboard/presentation/providers/live_telemetry_provider.dart';
import 'package:jbd_battery_monitor/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DashboardScreen English Localization Tests', () {
    testWidgets('renders all status and detail toggle text in English', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsRepo = SettingsRepository(prefs);

      final snapshot = BatterySnapshot(
        basicInfo: const JbdBasicInfo(
          voltage: 13.32,
          current: 2.5,
          power: 33.3,
          remainingCapacityAh: 85,
          nominalCapacityAh: 100,
          cycleCount: 12,
          soc: 85,
          chargeFetEnabled: true,
          dischargeFetEnabled: true,
          cellCount: 4,
          temperatures: [23.0, 22.0],
          tempBms: 23.0,
          tempCells: 22.0,
          protectionStatus: 0,
          balanceStatusLow: 0,
          balanceStatusHigh: 0,
          softwareVersion: 16,
        ),
        cellVoltages: const [3.33, 3.33, 3.33, 3.33],
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesRepositoryProvider.overrideWithValue(settingsRepo),
            liveTelemetryProvider.overrideWith((ref) => Stream.value(snapshot)),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check charging state text
      expect(find.text('Charging'), findsOneWidget);
      expect(find.text('Laden'), findsNothing);

      // Check details expansion button text
      expect(find.text('Show Details (Cells & Diagnostics)'), findsOneWidget);
      expect(find.textContaining('anzeigen'), findsNothing);

      // Tap to expand
      await tester.tap(find.text('Show Details (Cells & Diagnostics)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check collapse button text
      expect(find.text('Show Less'), findsOneWidget);
      expect(find.text('Weniger anzeigen'), findsNothing);
    });
  });
}
