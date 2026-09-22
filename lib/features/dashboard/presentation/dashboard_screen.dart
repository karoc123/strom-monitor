import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ble/ble_connection_state.dart';
import '../../../core/providers/ble_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../settings/domain/app_settings.dart';
import 'providers/live_telemetry_provider.dart';
import 'widgets/cell_voltage_card.dart';
import 'widgets/metric_card.dart';
import 'widgets/soc_gauge.dart';
import 'widgets/solar_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  bool _isBatteryDetailsExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Auto-connect to target devices if configured
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bleLifecycleCoordinatorProvider).onAppResumed();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(bleLifecycleCoordinatorProvider).onAppResumed();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ref.read(bleLifecycleCoordinatorProvider).onAppPaused();
    }
  }

  Future<void> _connectToTarget(String mac) async {
    final bleClient = ref.read(bleClientProvider);
    final success = await bleClient.connect(mac);
    if (success) {
      bleClient.startPolling(interval: const Duration(seconds: 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bleState =
        ref.watch(bleStateStreamProvider).value ??
        ref.read(bleClientProvider).currentState;
    final liveDataAsync = ref.watch(liveTelemetryProvider);
    final solarDataAsync = ref.watch(liveSolarTelemetryProvider);
    final settings = ref.watch(settingsProvider);

    final snapshot = liveDataAsync.value;
    final solarData =
        solarDataAsync.value ?? ref.read(victronBleClientProvider).latestData;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              settings.targetDeviceName ??
                  (settings.victronDeviceName ?? 'Ström Monitor'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (settings.targetDeviceMac != null ||
                settings.victronDeviceMac != null)
              Text(
                [
                  if (settings.targetDeviceMac != null)
                    'BMS: ${settings.targetDeviceMac}',
                  if (settings.victronDeviceMac != null)
                    'Solar: ${settings.victronDeviceMac}',
                ].join(' • '),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                  fontSize: 10,
                ),
              ),
          ],
        ),
        actions: [
          _buildConnectionAction(bleState, settings.targetDeviceMac),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(bleLifecycleCoordinatorProvider).onAppResumed();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusBar(bleState, settings),
              const SizedBox(height: 16),

              // ==================== KACHEL 1: BATTERIE (JBD BMS) ====================
              if (snapshot != null) ...[
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.battery_charging_full,
                                  color: Color(0xFF3B82F6),
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  settings.targetDeviceName ??
                                      'Battery (JBD BMS)',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (snapshot.basicInfo.isCharging
                                            ? const Color(0xFF10B981)
                                            : snapshot.basicInfo.isDischarging
                                            ? const Color(0xFFF59E0B)
                                            : Colors.grey)
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                snapshot.basicInfo.isCharging
                                    ? 'Charging'
                                    : snapshot.basicInfo.isDischarging
                                    ? 'Discharging'
                                    : 'Standby',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: snapshot.basicInfo.isCharging
                                      ? const Color(0xFF10B981)
                                      : snapshot.basicInfo.isDischarging
                                      ? const Color(0xFFF59E0B)
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SocGauge(
                          soc: snapshot.basicInfo.soc,
                          voltage: snapshot.basicInfo.voltage,
                          current: snapshot.basicInfo.current,
                          power: snapshot.basicInfo.power,
                          isCharging: snapshot.basicInfo.isCharging,
                          isDischarging: snapshot.basicInfo.isDischarging,
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            setState(() {
                              _isBatteryDetailsExpanded =
                                  !_isBatteryDetailsExpanded;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isBatteryDetailsExpanded
                                      ? 'Show Less'
                                      : 'Show Details (Cells & Diagnostics)',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _isBatteryDetailsExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_isBatteryDetailsExpanded) ...[
                          const SizedBox(height: 12),
                          // Metric Grid
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.6,
                            children: [
                              MetricCard(
                                label: 'Pack Voltage',
                                value: snapshot.basicInfo.voltage
                                    .toStringAsFixed(2),
                                unit: 'V',
                                icon: Icons.electric_bolt_outlined,
                                accentColor: const Color(0xFF3B82F6),
                              ),
                              MetricCard(
                                label: 'Current',
                                value: snapshot.basicInfo.current
                                    .abs()
                                    .toStringAsFixed(2),
                                unit: 'A',
                                icon: snapshot.basicInfo.isCharging
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                accentColor: snapshot.basicInfo.isCharging
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF59E0B),
                              ),
                              MetricCard(
                                label: 'Power',
                                value: snapshot.basicInfo.power
                                    .abs()
                                    .toStringAsFixed(1),
                                unit: 'W',
                                icon: Icons.speed_outlined,
                                accentColor: const Color(0xFF8B5CF6),
                              ),
                              MetricCard(
                                label: 'Capacity',
                                value:
                                    '${snapshot.basicInfo.remainingCapacityAh.toStringAsFixed(1)} / ${snapshot.basicInfo.nominalCapacityAh.toStringAsFixed(0)}',
                                unit: 'Ah',
                                icon: Icons.battery_charging_full_outlined,
                                accentColor: const Color(0xFF06B6D4),
                              ),
                            ],
                          ),
                          if (snapshot.cellVoltages.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            CellVoltageCard(
                              cellVoltages: snapshot.cellVoltages,
                            ),
                          ],
                          const SizedBox(height: 12),
                          _buildTemperatureAndInfoCard(
                            snapshot.basicInfo,
                            theme,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ] else ...[
                _buildNoBmsPlaceholder(bleState, settings.targetDeviceMac),
              ],

              const SizedBox(height: 16),

              // ==================== KACHEL 2: SOLAR (VICTRON MPPT) ====================
              SolarCard(
                solarData: solarData,
                deviceName: settings.victronDeviceName,
                isConfigured: settings.hasVictronDevice,
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar(BleState bleState, AppSettings settings) {
    Color bmsColor;
    String bmsText;
    IconData bmsIcon;

    switch (bleState.status) {
      case BleConnectionStatus.connected:
      case BleConnectionStatus.polling:
        bmsColor = const Color(0xFF10B981);
        bmsText = 'BMS: Live (1 Hz)';
        bmsIcon = Icons.check_circle_outline;
        break;
      case BleConnectionStatus.connecting:
        bmsColor = const Color(0xFF3B82F6);
        bmsText = 'BMS: Connecting...';
        bmsIcon = Icons.bluetooth_searching;
        break;
      case BleConnectionStatus.scanning:
        bmsColor = const Color(0xFF3B82F6);
        bmsText = 'BLE: Scanning...';
        bmsIcon = Icons.bluetooth_searching;
        break;
      case BleConnectionStatus.error:
        bmsColor = const Color(0xFFEF4444);
        bmsText = bleState.errorMessage ?? 'BMS Error';
        bmsIcon = Icons.error_outline;
        break;
      case BleConnectionStatus.disconnected:
        bmsColor = Colors.grey;
        bmsText = settings.hasBmsDevice
            ? 'BMS: Disconnected'
            : 'BMS: Not Paired';
        bmsIcon = Icons.bluetooth_disabled;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bmsColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bmsColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(bmsIcon, size: 16, color: bmsColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              bmsText,
              style: TextStyle(
                color: bmsColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (settings.hasVictronDevice) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Solar: Active',
              style: TextStyle(
                color: Color(0xFFD97706),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionAction(BleState bleState, String? targetMac) {
    if (targetMac == null || targetMac.isEmpty) {
      return const SizedBox.shrink();
    }

    if (bleState.isConnected) {
      return IconButton(
        icon: const Icon(Icons.bluetooth_connected, color: Color(0xFF10B981)),
        tooltip: 'Disconnect',
        onPressed: () {
          ref.read(bleClientProvider).disconnect();
        },
      );
    }

    if (bleState.status == BleConnectionStatus.connecting) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return IconButton(
      icon: const Icon(Icons.bluetooth),
      tooltip: 'Connect',
      onPressed: () => _connectToTarget(targetMac),
    );
  }

  Widget _buildTemperatureAndInfoCard(dynamic info, ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildInfoTile(
              'BMS Temp',
              '${info.tempBms?.toStringAsFixed(1) ?? "--"} °C',
              theme,
            ),
            _buildInfoTile(
              'Cells Temp',
              '${info.tempCells?.toStringAsFixed(1) ?? "--"} °C',
              theme,
            ),
            _buildInfoTile('Cycles', '${info.cycleCount}', theme),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildNoBmsPlaceholder(BleState bleState, String? targetMac) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant
              .withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          children: [
            Icon(
              Icons.battery_unknown_outlined,
              size: 44,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 10),
            Text(
              targetMac == null
                  ? 'No JBD BMS Paired'
                  : 'Waiting for BMS Telemetry...',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              targetMac == null
                  ? 'Go to Settings to scan and pair your JBD BMS.'
                  : 'Ensure Bluetooth is active and battery is in range.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
