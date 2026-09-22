import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../features/settings/domain/app_settings.dart';
import 'ble_client.dart';
import 'victron_ble_client.dart';

/// Coordinates Bluetooth Low Energy foreground connection lifecycles based on
/// application lifecycle events (resumed, paused).
///
/// Ensures battery-saving behaviour in background while maintaining immediate,
/// self-healing re-connections when the user returns to the app.
class BleLifecycleCoordinator {
  final BleClient bleClient;
  final VictronBleClient victronClient;
  final AppSettings Function() getSettings;

  BleLifecycleCoordinator({
    required this.bleClient,
    required this.victronClient,
    required this.getSettings,
  });

  /// Called when the application enters foreground ([AppLifecycleState.resumed]).
  /// Re-establishes stale or stopped connections to configured devices.
  Future<void> onAppResumed() async {
    final settings = getSettings();

    // 1. Victron Solar Charger (Instant Readout scan)
    if (settings.hasVictronDevice) {
      await victronClient.startListening(
        targetMac: settings.victronDeviceMac!,
        encryptionKey: settings.victronEncryptionKey!,
        forceRestart: true,
      );
    }

    // 2. JBD BMS Battery
    if (settings.hasBmsDevice) {
      final isConnected = bleClient.currentState.isConnected;
      final isStale = bleClient.isStale;

      if (isConnected && !isStale) {
        bleClient.startPolling();
      } else {
        if (isConnected && isStale) {
          await bleClient.disconnect();
        }
        final success = await bleClient.connect(settings.targetDeviceMac!);
        if (success) {
          bleClient.startPolling();
        }
      }
    }
  }

  /// Called when the application enters background ([AppLifecycleState.paused] / [AppLifecycleState.inactive]).
  /// Pauses polling and continuous scanning to save battery.
  Future<void> onAppPaused() async {
    bleClient.stopPolling();
    await victronClient.stopListening();
  }
}
