import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/database_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../background/background_service_manager.dart';
import '../../history/presentation/providers/history_provider.dart';
import 'widgets/device_scanner_dialog.dart';
import 'widgets/gpl_license_dialog.dart';
import 'widgets/victron_scanner_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final dao = ref.watch(readingDaoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings & Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildSectionHeader('Target Battery BMS (JBD)', theme),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.battery_charging_full,
                color: Color(0xFF3B82F6),
              ),
              title: Text(
                settings.targetDeviceName ?? 'No BMS Paired',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                settings.targetDeviceMac ?? 'Tap to scan and pair your JBD BMS',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (settings.hasBmsDevice)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.grey,
                      ),
                      tooltip: 'Disconnect BMS',
                      onPressed: () {
                        ref
                            .read(settingsProvider.notifier)
                            .removeTargetDevice();
                      },
                    ),
                  FilledButton.tonal(
                    onPressed: () => _openDeviceScanner(context),
                    child: Text(
                      settings.targetDeviceMac == null ? 'Pair' : 'Change',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionHeader('Target Solar Charger (Victron MPPT)', theme),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: const Icon(Icons.solar_power, color: Color(0xFFF59E0B)),
              title: Text(
                settings.victronDeviceName ?? 'No Solar Charger Paired',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                settings.victronDeviceMac != null
                    ? '${settings.victronDeviceMac}\nKey: ••••••••••••••••${settings.victronEncryptionKey?.substring(settings.victronEncryptionKey!.length - 4) ?? ""}'
                    : 'Tap to scan and configure encryption key',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (settings.hasVictronDevice)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.grey,
                      ),
                      tooltip: 'Disconnect Solar',
                      onPressed: () {
                        ref
                            .read(settingsProvider.notifier)
                            .removeVictronDevice();
                      },
                    ),
                  FilledButton.tonal(
                    onPressed: () => _openVictronScanner(context),
                    child: Text(
                      settings.victronDeviceMac == null ? 'Pair' : 'Change',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          _buildSectionHeader('Background Telemetry Logging', theme),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'WorkManager Interval',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      DropdownButton<int>(
                        value: settings.backgroundIntervalMinutes,
                        underline: const SizedBox.shrink(),
                        borderRadius: BorderRadius.circular(12),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('Disabled')),
                          DropdownMenuItem(
                            value: 15,
                            child: Text('Every 15 min'),
                          ),
                          DropdownMenuItem(
                            value: 30,
                            child: Text('Every 30 min'),
                          ),
                          DropdownMenuItem(
                            value: 60,
                            child: Text('Every 60 min'),
                          ),
                          DropdownMenuItem(
                            value: 120,
                            child: Text('Every 2 hours'),
                          ),
                        ],
                        onChanged: (val) async {
                          if (val != null) {
                            await ref
                                .read(settingsProvider.notifier)
                                .setBackgroundInterval(val);
                            await BackgroundServiceManager.updateSchedule(val);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Periodic background measurements log battery metrics to SQLite without keeping the app active in the foreground.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionHeader('Foreground Recording Rate', theme),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              title: const Text('Live Write Interval'),
              subtitle: const Text(
                'Minimum interval between SQLite commits during live view',
              ),
              trailing: DropdownButton<int>(
                value: settings.foregroundWriteIntervalSeconds,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(12),
                items: const [
                  DropdownMenuItem(value: 15, child: Text('15 sec')),
                  DropdownMenuItem(value: 30, child: Text('30 sec')),
                  DropdownMenuItem(value: 60, child: Text('60 sec')),
                  DropdownMenuItem(value: 120, child: Text('120 sec')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    ref
                        .read(settingsProvider.notifier)
                        .setForegroundWriteInterval(val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionHeader('Storage & Maintenance', theme),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                FutureBuilder<int>(
                  future: dao.countReadings(),
                  builder: (ctx, snapshot) {
                    final count = snapshot.data ?? 0;
                    return ListTile(
                      leading: const Icon(Icons.storage_outlined),
                      title: const Text('Stored Data Points'),
                      trailing: Text(
                        '$count records',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined),
                  title: const Text('Prune Old Records'),
                  subtitle: const Text(
                    'Delete data older than 30, 90, or 365 days',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showPruneDialog(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_outlined,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'Clear All Data',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () => _showClearAllDialog(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionHeader('About & Licensing', theme),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('GNU General Public License (GPLv3)'),
              subtitle: const Text('Open-Source LiFePO4 BMS Telemetry Monitor'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLicenseDialog(context),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _openDeviceScanner(BuildContext context) {
    showDialog(context: context, builder: (_) => const DeviceScannerDialog());
  }

  void _openVictronScanner(BuildContext context) {
    showDialog(context: context, builder: (_) => const VictronScannerDialog());
  }

  void _showLicenseDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const GplLicenseDialog());
  }

  void _showPruneDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('Prune Historical Records'),
          children: [
            SimpleDialogOption(
              child: const Text('Older than 30 days'),
              onPressed: () {
                Navigator.pop(ctx);
                _executePrune(context, ref, 30);
              },
            ),
            SimpleDialogOption(
              child: const Text('Older than 90 days'),
              onPressed: () {
                Navigator.pop(ctx);
                _executePrune(context, ref, 90);
              },
            ),
            SimpleDialogOption(
              child: const Text('Older than 365 days'),
              onPressed: () {
                Navigator.pop(ctx);
                _executePrune(context, ref, 365);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _executePrune(
    BuildContext context,
    WidgetRef ref,
    int days,
  ) async {
    final dao = ref.read(readingDaoProvider);
    final threshold = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;
    final count = await dao.pruneOlderThan(threshold);
    ref.invalidate(historyReadingsProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pruned $count historical records.')),
      );
    }
  }

  void _showClearAllDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Clear All Records?'),
          content: const Text(
            'This will permanently delete all stored battery telemetry data. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(ctx);
                final dao = ref.read(readingDaoProvider);
                await dao.clearAll();
                ref.invalidate(historyReadingsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Database cleared successfully.'),
                    ),
                  );
                }
              },
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );
  }
}
