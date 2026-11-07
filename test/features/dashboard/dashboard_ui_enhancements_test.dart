import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jbd_battery_monitor/features/dashboard/presentation/widgets/cell_voltage_card.dart';
import 'package:jbd_battery_monitor/features/dashboard/presentation/widgets/metric_card.dart';
import 'package:jbd_battery_monitor/features/dashboard/presentation/widgets/soc_gauge.dart';

void main() {
  group('SocGauge Voltage & Signed Power Tests', () {
    testWidgets('renders voltage, signed power and invokes onVoltageTap', (
      tester,
    ) async {
      bool voltageTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocGauge(
              soc: 85,
              voltage: 13.32,
              current: 12.5,
              power: 166.5,
              isCharging: true,
              isDischarging: false,
              onVoltageTap: () {
                voltageTapped = true;
              },
            ),
          ),
        ),
      );

      // Verify voltage is rendered
      expect(find.text('13.32 V'), findsOneWidget);

      // Verify signed charging power is rendered (+166.5 W)
      expect(find.text('+166.5 W'), findsOneWidget);

      // Tap on voltage text
      await tester.tap(find.text('13.32 V'));
      await tester.pump();

      expect(voltageTapped, isTrue);
    });

    testWidgets('renders signed discharging power with minus sign', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SocGauge(
              soc: 45,
              voltage: 12.88,
              current: -8.0,
              power: -103.0,
              isCharging: false,
              isDischarging: true,
            ),
          ),
        ),
      );

      expect(find.text('12.88 V'), findsOneWidget);
      expect(find.text('-103.0 W'), findsOneWidget);
      expect(find.text('Discharging (-8.0 A)'), findsOneWidget);
    });
  });

  group('MetricCard Color & Sign Tests', () {
    testWidgets('renders valueColor and signed value properly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetricCard(
              label: 'Current',
              value: '+15.20',
              unit: 'A',
              icon: Icons.arrow_downward,
              accentColor: Color(0xFF10B981),
              valueColor: Color(0xFF10B981),
            ),
          ),
        ),
      );

      expect(find.text('Current'), findsOneWidget);
      expect(find.text('+15.20'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text('+15.20'));
      expect(textWidget.style?.color, const Color(0xFF10B981));
    });
  });

  group('CellVoltageCard Balancing Indicator Tests', () {
    testWidgets('displays balancing badges when balanceStatus is active', (
      tester,
    ) async {
      // Bit 1 (1 << 1 = 2) means Cell 2 is balancing
      const balanceLow = 2; // binary 0000 0010 -> Cell 2
      const balanceHigh = 0;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CellVoltageCard(
                cellVoltages: [3.330, 3.335, 3.328, 3.329],
                balanceStatusLow: balanceLow,
                balanceStatusHigh: balanceHigh,
              ),
            ),
          ),
        ),
      );

      // Verify cell count title
      expect(find.text('Cell Voltages (4S)'), findsOneWidget);

      // Verify header "Balancing" badge and cell-specific "Balancing" pill (2 total)
      expect(find.text('Balancing'), findsNWidgets(2));
      expect(find.byIcon(Icons.balance), findsNWidgets(2));

      // Verify delta badge
      expect(find.text('Δ 7 mV'), findsOneWidget);
    });

    testWidgets('does not show balancing badges when balance status is 0', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CellVoltageCard(
                cellVoltages: [3.330, 3.330, 3.330, 3.330],
                balanceStatusLow: 0,
                balanceStatusHigh: 0,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Balancing'), findsNothing);
      expect(find.byIcon(Icons.balance), findsNothing);
    });
  });
}
