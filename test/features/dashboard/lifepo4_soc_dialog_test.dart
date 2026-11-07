import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jbd_battery_monitor/core/ble/ble_client.dart';
import 'package:jbd_battery_monitor/core/protocol/jbd_telemetry_parser.dart';
import 'package:jbd_battery_monitor/core/providers/settings_provider.dart';
import 'package:jbd_battery_monitor/features/dashboard/presentation/dashboard_screen.dart';
import 'package:jbd_battery_monitor/features/dashboard/presentation/providers/live_telemetry_provider.dart';
import 'package:jbd_battery_monitor/features/dashboard/presentation/widgets/lifepo4_soc_dialog.dart';
import 'package:jbd_battery_monitor/features/dashboard/presentation/widgets/metric_card.dart';
import 'package:jbd_battery_monitor/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Lifepo4SocDialog Tests', () {
    testWidgets('renders all reference table rows and header info correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Lifepo4SocDialog(currentVoltage: 13.32, cellCount: 4),
          ),
        ),
      );

      // Verify title and subtitle
      expect(find.text('LiFePO4 SoC Reference'), findsOneWidget);
      expect(
        find.text('Cell & Pack Voltage Chart (OCV / Ruhespannung)'),
        findsOneWidget,
      );

      // Verify live telemetry banner
      expect(
        find.textContaining('Live: 13.32 V (3.330 V/Cell • 4S)'),
        findsOneWidget,
      );

      // Verify charging parameters card
      expect(find.text('Lade- & Systemgrenzen (4S)'), findsOneWidget);
      expect(find.text('14.60 V'), findsWidgets);

      // Verify table column headers
      expect(find.text('SoC'), findsOneWidget);
      expect(find.text('Cell (V)'), findsOneWidget);
      expect(find.text('Pack (4S)'), findsOneWidget);
      expect(find.text('Zustand'), findsOneWidget);

      // Verify representative SoC table entries (100% Charge & Rest, 90%, 50%, 20%, 0%)
      expect(find.text('100%'), findsNWidgets(2));
      expect(find.text('Charge'), findsOneWidget);
      expect(find.text('Rest'), findsOneWidget);
      expect(find.text('90%'), findsWidgets);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);

      // Verify 4S pack voltages (13.40 V for 90%, 13.28 V for 80%, 10.00 V for 0%)
      expect(find.text('13.40 V'), findsOneWidget);
      expect(find.text('13.28 V'), findsOneWidget);
      expect(find.text('10.0 V'), findsWidgets); // Cutoff in card / table

      // Verify close button pops dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(Lifepo4SocDialog), findsNothing);
    });

    testWidgets('switching configuration updates pack voltages dynamically', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Lifepo4SocDialog(currentVoltage: 13.32, cellCount: 4),
          ),
        ),
      );

      // Default is 4S (12V)
      expect(find.text('Pack (4S)'), findsOneWidget);

      // Switch to 8S (24V)
      await tester.tap(find.text('8S (24V)'));
      await tester.pumpAndSettle();

      expect(find.text('Pack (8S)'), findsOneWidget);
      // 0% cell voltage 2.50V * 8 = 20.00V
      expect(find.text('20.00 V'), findsOneWidget);

      // Switch to 1S
      await tester.tap(find.text('1S'));
      await tester.pumpAndSettle();

      expect(find.text('Pack (1S)'), findsOneWidget);
      // 0% cell voltage 2.50V * 1 = 2.50V
      expect(find.text('2.50 V'), findsWidgets);
    });

    testWidgets(
      'renders gracefully on narrow 320px mobile viewport without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Lifepo4SocDialog(currentVoltage: 13.15, cellCount: 4),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('LiFePO4 SoC Reference'), findsOneWidget);
      },
    );
  });

  group('MetricCard Interaction Tests', () {
    testWidgets('triggers onTap callback when tapped and displays info icon', (
      tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 160,
                height: 100,
                child: MetricCard(
                  label: 'Pack Voltage',
                  value: '13.32',
                  unit: 'V',
                  icon: Icons.electric_bolt_outlined,
                  onTap: () {
                    tapped = true;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      // Should show info icon when onTap is provided
      expect(find.byIcon(Icons.info_outline), findsOneWidget);

      // Tap card
      await tester.tap(find.byType(MetricCard));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('DashboardScreen Pack Voltage Tap Integration Tests', () {
    testWidgets(
      'tapping Pack Voltage MetricCard opens Lifepo4SocDialog in dashboard',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final settingsRepo = SettingsRepository(prefs);

        final snapshot = BatterySnapshot(
          basicInfo: const JbdBasicInfo(
            voltage: 13.32,
            current: 0.0,
            power: 0.0,
            remainingCapacityAh: 80,
            nominalCapacityAh: 100,
            cycleCount: 5,
            soc: 80,
            chargeFetEnabled: true,
            dischargeFetEnabled: true,
            cellCount: 4,
            temperatures: [22.0],
            tempBms: 22.0,
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
              sharedPreferencesRepositoryProvider.overrideWithValue(
                settingsRepo,
              ),
              liveTelemetryProvider.overrideWith(
                (ref) => Stream.value(snapshot),
              ),
            ],
            child: const MaterialApp(home: DashboardScreen()),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify Pack Voltage metric card is visible directly (always visible)
        expect(find.text('Pack Voltage'), findsOneWidget);

        // Tap on Pack Voltage card
        await tester.tap(find.text('Pack Voltage'));
        await tester.pumpAndSettle();

        // Verify that Lifepo4SocDialog opened
        expect(find.byType(Lifepo4SocDialog), findsOneWidget);
        expect(find.text('LiFePO4 SoC Reference'), findsOneWidget);

        // Close dialog
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        expect(find.byType(Lifepo4SocDialog), findsNothing);
      },
    );
  });
}
