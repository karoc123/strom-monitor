import 'package:flutter/material.dart';

import '../../../../core/protocol/victron/victron_mppt_data.dart';

/// Card widget displaying real-time measured telemetry from a Victron SmartSolar MPPT.
class SolarCard extends StatelessWidget {
  final VictronMpptData? solarData;
  final String? deviceName;
  final bool isConfigured;
  final VoidCallback? onConfigure;

  const SolarCard({
    super.key,
    required this.solarData,
    this.deviceName,
    required this.isConfigured,
    this.onConfigure,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!isConfigured) {
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
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.solar_power_outlined,
                size: 40,
                color: Colors.grey.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 10),
              const Text(
                'No Solar Charger Paired',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                'Pair your Victron SmartSolar MPPT in Settings to see live solar yield & power.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (onConfigure != null) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: onConfigure,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Pair Victron MPPT'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final data = solarData;
    final state = data?.deviceState ?? VictronDeviceState.unknown;
    final stateColor = _getStateColor(state);

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Title & State Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.solar_power,
                      color: Color(0xFFF59E0B),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      deviceName ?? 'Solar (Victron MPPT)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: stateColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: stateColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: stateColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        data != null ? state.displayName : 'Waiting...',
                        style: TextStyle(
                          color: stateColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Main Highlights: Solar Power (W) and Yield Today (Wh/kWh)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Solar Power',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              data != null
                                  ? data.solarPower.toStringAsFixed(0)
                                  : '--',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD97706),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'W',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yield Today',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              data != null
                                  ? _formatYieldValue(data.yieldTodayWh)
                                  : '--',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF059669),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              data != null && data.yieldTodayWh >= 1000
                                  ? 'kWh'
                                  : 'Wh',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Secondary Metrics Row: Voltage and Current
            if (data != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSubMetric(
                    'Solar Voltage',
                    '${data.batteryVoltage.toStringAsFixed(2)} V',
                    theme,
                  ),
                  _buildSubMetric(
                    'Charge Current',
                    '${data.batteryCurrent.toStringAsFixed(1)} A',
                    theme,
                  ),
                  if (data.loadCurrent != null)
                    _buildSubMetric(
                      'Load Current',
                      '${data.loadCurrent!.toStringAsFixed(1)} A',
                      theme,
                    ),
                ],
              ),

            // Charger Error Alert (if present)
            if (data != null &&
                data.chargerError != VictronChargerError.noError) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        data.chargerError.description,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubMetric(String label, String value, ThemeData theme) {
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

  String _formatYieldValue(double yieldWh) {
    if (yieldWh >= 1000) {
      return (yieldWh / 1000.0).toStringAsFixed(2);
    }
    return yieldWh.toStringAsFixed(0);
  }

  Color _getStateColor(VictronDeviceState state) {
    switch (state) {
      case VictronDeviceState.bulk:
      case VictronDeviceState.absorption:
      case VictronDeviceState.floatState:
      case VictronDeviceState.storage:
      case VictronDeviceState.equalize:
        return const Color(0xFF10B981); // Green
      case VictronDeviceState.lowPower:
      case VictronDeviceState.startingUp:
      case VictronDeviceState.autoEqualize:
      case VictronDeviceState.externalControl:
        return const Color(0xFFF59E0B); // Amber
      case VictronDeviceState.fault:
        return const Color(0xFFEF4444); // Red
      case VictronDeviceState.off:
      case VictronDeviceState.unknown:
        return Colors.grey;
    }
  }
}
