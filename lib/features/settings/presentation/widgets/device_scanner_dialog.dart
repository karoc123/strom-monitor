import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ble/ble_device_info.dart';
import '../../../../core/providers/ble_provider.dart';
import '../../../../core/providers/settings_provider.dart';

class DeviceScannerDialog extends ConsumerWidget {
  const DeviceScannerDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanResultsAsync = ref.watch(bleScanResultsProvider);
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Scan BLE Devices',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Select your JBD / Xiaoxiang LiFePO4 BMS to pair.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: scanResultsAsync.when(
                data: (devices) {
                  if (devices.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'Searching for nearby BLE devices...',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }

                  // Sort candidates first, then by RSSI
                  final sorted = List<BleDeviceInfo>.from(devices)
                    ..sort((a, b) {
                      if (a.isJbdCandidate && !b.isJbdCandidate) return -1;
                      if (!a.isJbdCandidate && b.isJbdCandidate) return 1;
                      return b.rssi.compareTo(a.rssi);
                    });

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: sorted.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final device = sorted[idx];
                      final isCandidate = device.isJbdCandidate;

                      return ListTile(
                        leading: Icon(
                          isCandidate
                              ? Icons.battery_charging_full
                              : Icons.bluetooth,
                          color: isCandidate
                              ? const Color(0xFF10B981)
                              : theme.colorScheme.primary,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                device.name,
                                style: TextStyle(
                                  fontWeight: isCandidate
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCandidate)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'JBD BMS',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '${device.id} • ${device.rssi} dBm',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          ref
                              .read(settingsProvider.notifier)
                              .setTargetDevice(
                                mac: device.id,
                                name: device.name,
                              );
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text('Scan error: $err'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
