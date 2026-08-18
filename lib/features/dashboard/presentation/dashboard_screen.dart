import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ble/ble_connection_state.dart';
import '../../../core/providers/ble_provider.dart';
import '../../../core/providers/settings_provider.dart';
import 'providers/live_telemetry_provider.dart';
import 'widgets/cell_voltage_card.dart';
import 'widgets/metric_card.dart';
import 'widgets/soc_gauge.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-connect to target device if configured and disconnected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoConnectIfConfigured();
    });
  }

  void _autoConnectIfConfigured() {
    final settings = ref.read(settingsProvider);
    final bleClient = ref.read(bleClientProvider);
    if (settings.targetDeviceMac != null &&
        settings.targetDeviceMac!.isNotEmpty &&
        !bleClient.currentState.isConnected &&
        bleClient.currentState.status != BleConnectionStatus.connecting) {
      _connectToTarget(settings.targetDeviceMac!);
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
    final settings = ref.watch(settingsProvider);

    final snapshot = liveDataAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              settings.targetDeviceName ?? 'Ström Monitor',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (settings.targetDeviceMac != null)
              Text(
                settings.targetDeviceMac!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
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
          if (settings.targetDeviceMac != null) {
            await _connectToTarget(settings.targetDeviceMac!);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusBar(bleState),
              const SizedBox(height: 16),
              if (snapshot != null) ...[
                SocGauge(
                  soc: snapshot.basicInfo.soc,
                  voltage: snapshot.basicInfo.voltage,
                  current: snapshot.basicInfo.current,
                  power: snapshot.basicInfo.power,
                  isCharging: snapshot.basicInfo.isCharging,
                  isDischarging: snapshot.basicInfo.isDischarging,
                ),
                const SizedBox(height: 20),
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
                      value: snapshot.basicInfo.voltage.toStringAsFixed(2),
                      unit: 'V',
                      icon: Icons.electric_bolt_outlined,
                      accentColor: const Color(0xFF3B82F6),
                    ),
                    MetricCard(
                      label: 'Current',
                      value: snapshot.basicInfo.current.abs().toStringAsFixed(
                        2,
                      ),
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
                      value: snapshot.basicInfo.power.abs().toStringAsFixed(1),
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
                const SizedBox(height: 16),
                CellVoltageCard(cellVoltages: snapshot.cellVoltages),
                const SizedBox(height: 16),
                _buildTemperatureAndInfoCard(snapshot.basicInfo, theme),
              ] else ...[
                _buildNoDataPlaceholder(bleState, settings.targetDeviceMac),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar(BleState bleState) {
    Color color;
    String text;
    IconData icon;

    switch (bleState.status) {
      case BleConnectionStatus.connected:
      case BleConnectionStatus.polling:
        color = const Color(0xFF10B981);
        text = 'Live Polling (1 Hz)';
        icon = Icons.check_circle_outline;
        break;
      case BleConnectionStatus.connecting:
        color = const Color(0xFF3B82F6);
        text = 'Connecting to BMS...';
        icon = Icons.bluetooth_searching;
        break;
      case BleConnectionStatus.scanning:
        color = const Color(0xFF3B82F6);
        text = 'Scanning BLE...';
        icon = Icons.bluetooth_searching;
        break;
      case BleConnectionStatus.error:
        color = const Color(0xFFEF4444);
        text = bleState.errorMessage ?? 'Connection Error';
        icon = Icons.error_outline;
        break;
      case BleConnectionStatus.disconnected:
        color = Colors.grey;
        text = 'Disconnected';
        icon = Icons.bluetooth_disabled;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Diagnostics',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
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
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildNoDataPlaceholder(BleState bleState, String? targetMac) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: Column(
          children: [
            Icon(
              Icons.battery_unknown_outlined,
              size: 64,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              targetMac == null
                  ? 'No Target BMS Paired'
                  : 'Waiting for BMS Telemetry...',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              targetMac == null
                  ? 'Go to Settings to scan and pair your JBD BMS.'
                  : 'Ensure Bluetooth is active and the battery is in range.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
