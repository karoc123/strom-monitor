import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ble/ble_device_info.dart';
import '../../../../core/protocol/victron/victron_crypto.dart';
import '../../../../core/protocol/victron/victron_mppt_parser.dart';
import '../../../../core/providers/ble_provider.dart';
import '../../../../core/providers/settings_provider.dart';

class VictronScannerDialog extends ConsumerStatefulWidget {
  const VictronScannerDialog({super.key});

  @override
  ConsumerState<VictronScannerDialog> createState() =>
      _VictronScannerDialogState();
}

class _VictronScannerDialogState extends ConsumerState<VictronScannerDialog> {
  BleDeviceInfo? _selectedDevice;
  final _keyController = TextEditingController();
  bool _isValidating = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  _selectedDevice == null
                      ? 'Pair Victron MPPT'
                      : 'Configure Encryption Key',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_selectedDevice == null)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_selectedDevice == null) ...[
              Text(
                'Select your Victron SmartSolar or BlueSolar MPPT charge controller.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _buildDeviceList(theme),
            ] else ...[
              _buildKeyInputView(theme),
            ],
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

  Widget _buildDeviceList(ThemeData theme) {
    final scanResultsAsync = ref.watch(bleScanResultsProvider);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: scanResultsAsync.when(
        data: (devices) {
          if (devices.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'Searching for nearby Victron devices...',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            );
          }

          // Sort Victron candidates first
          final sorted = List<BleDeviceInfo>.from(devices)
            ..sort((a, b) {
              if (a.isVictronCandidate && !b.isVictronCandidate) return -1;
              if (!a.isVictronCandidate && b.isVictronCandidate) return 1;
              return b.rssi.compareTo(a.rssi);
            });

          return ListView.separated(
            shrinkWrap: true,
            itemCount: sorted.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (ctx, idx) {
              final device = sorted[idx];
              final isCandidate = device.isVictronCandidate;

              return ListTile(
                leading: Icon(
                  isCandidate ? Icons.solar_power : Icons.bluetooth,
                  color: isCandidate
                      ? const Color(0xFFF59E0B)
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
                          color: const Color(0xFFF59E0B)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Victron',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFFD97706),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Text(
                  '${device.id} • ${device.rssi} dBm',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  setState(() {
                    _selectedDevice = device;
                    _errorMessage = null;
                    _successMessage = null;
                  });
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
    );
  }

  Widget _buildKeyInputView(ThemeData theme) {
    final dev = _selectedDevice!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.solar_power, color: Color(0xFFF59E0B)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dev.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      dev.id,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Change Device',
                onPressed: () {
                  setState(() {
                    _selectedDevice = null;
                    _errorMessage = null;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Instant Readout Encryption Key (16-Byte Hex / 32 Characters):',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Open VictronConnect app -> Device Settings -> Product Info -> Instant Readout to copy the key.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _keyController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g. 0123456789abcdef0123456789abcdef',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.key),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _keyController.clear(),
            ),
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          onChanged: (_) {
            if (_errorMessage != null) {
              setState(() => _errorMessage = null);
            }
          },
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (_successMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _successMessage!,
            style: const TextStyle(
              color: Color(0xFF10B981),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _isValidating ? null : _validateAndSave,
          icon: _isValidating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle_outline),
          label: Text(_isValidating ? 'Validating...' : 'Validate & Save'),
        ),
      ],
    );
  }

  Future<void> _validateAndSave() async {
    final rawKey = _keyController.text.trim();
    final parsedKey = VictronCrypto.parseHexKey(rawKey);

    if (parsedKey == null) {
      setState(() {
        _errorMessage = 'Invalid key format. Please enter exactly 32 hexadecimal characters (0-9, a-f).';
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final dev = _selectedDevice!;

    // Test decryption against device manufacturer data if available
    if (dev.manufacturerData.isNotEmpty &&
        dev.manufacturerData.containsKey(0x02E1)) {
      final mpptData = VictronMpptParser.parseAdvertisement(
        manufacturerData: dev.manufacturerData,
        encryptionKeyHex: rawKey,
      );

      if (mpptData != null) {
        await _saveDevice(dev, rawKey);
        return;
      }
    }

    // If not immediately verifiable from cached scan result, scan for 4 seconds to capture advertisement
    try {
      if (!FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 4),
          androidUsesFineLocation: false,
        );
      }

      bool validated = false;
      final sub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          if (r.device.remoteId.str == dev.id &&
              r.advertisementData.manufacturerData.containsKey(0x02E1)) {
            final mpptData = VictronMpptParser.parseAdvertisement(
              manufacturerData: r.advertisementData.manufacturerData,
              encryptionKeyHex: rawKey,
            );
            if (mpptData != null) {
              validated = true;
            }
          }
        }
      });

      await Future.delayed(const Duration(seconds: 4));
      await sub.cancel();
      await FlutterBluePlus.stopScan();

      if (validated) {
        await _saveDevice(dev, rawKey);
      } else {
        // Allow user to save anyway with warning if device is out of direct range or not currently advertising
        _showValidationFallbackDialog(dev, rawKey);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isValidating = false;
          _errorMessage = 'Validation scan error: $e';
        });
      }
    }
  }

  Future<void> _saveDevice(BleDeviceInfo dev, String key) async {
    await ref
        .read(settingsProvider.notifier)
        .setVictronDevice(mac: dev.id, name: dev.name, encryptionKey: key);

    if (mounted) {
      setState(() {
        _isValidating = false;
        _successMessage = 'Successfully validated & paired!';
      });
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _showValidationFallbackDialog(BleDeviceInfo dev, String key) {
    setState(() => _isValidating = false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Advertisement Not Verified'),
        content: const Text(
          'Could not receive or decrypt an Instant Readout advertisement from this device within the timeout period.\n\n'
          'Ensure "Instant Readout" is enabled in the VictronConnect app and the key is correct. Would you like to save this key anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _saveDevice(dev, key);
            },
            child: const Text('Save Anyway'),
          ),
        ],
      ),
    );
  }
}
