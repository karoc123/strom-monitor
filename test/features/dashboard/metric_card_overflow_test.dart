import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jbd_battery_monitor/features/dashboard/presentation/widgets/metric_card.dart';

void main() {
  group('MetricCard Layout & Overflow Tests', () {
    testWidgets(
      'MetricCard with "136.9 / 200 Ah" fits without RenderFlex overflow',
      (tester) async {
        // Set typical mobile screen size (width 360)
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // In a 2-column grid on a 360px screen with padding (16*2) and spacing (12):
        // Available width for each card is (360 - 32 - 12) / 2 = 158.0 px.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 158,
                  height: 158 / 1.6,
                  child: const MetricCard(
                    label: 'Capacity',
                    value: '136.9 / 200',
                    unit: 'Ah',
                    icon: Icons.battery_charging_full_outlined,
                    accentColor: Color(0xFF06B6D4),
                  ),
                ),
              ),
            ),
          ),
        );

        // Verify no RenderFlex overflow exception was thrown during layout
        expect(tester.takeException(), isNull);
        expect(find.text('Capacity'), findsOneWidget);
        expect(find.text('136.9 / 200'), findsOneWidget);
        expect(find.text('Ah'), findsOneWidget);
      },
    );

    testWidgets(
      'MetricCard with high values scales gracefully in tight grid constraints',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 140,
                  height: 90,
                  child: const MetricCard(
                    label: 'Extremely Long Metric Label',
                    value: '9999.99 / 9999.99',
                    unit: 'mAh',
                    icon: Icons.speed,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );
  });
}
