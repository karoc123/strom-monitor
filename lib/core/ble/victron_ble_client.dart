import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../protocol/victron/victron_mppt_data.dart';
import '../protocol/victron/victron_mppt_parser.dart';

/// BLE Client dedicated to capturing and decoding Victron BLE Instant Readout advertisements.
class VictronBleClient {
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  final _solarController = StreamController<VictronMpptData>.broadcast();
  Stream<VictronMpptData> get solarStream => _solarController.stream;

  VictronMpptData? _latestData;
  VictronMpptData? get latestData {
    if (_latestData == null) return null;
    if (DateTime.now().difference(_latestData!.timestamp) >
        const Duration(seconds: 30)) {
      return null;
    }
    return _latestData;
  }

  String? _targetMac;
  String? _encryptionKey;
  bool _isListening = false;
  bool get isListening => _isListening;

  bool get isStale {
    if (_latestData == null) return true;
    return DateTime.now().difference(_latestData!.timestamp) >
        const Duration(seconds: 15);
  }

  /// Starts listening for BLE advertisements from the configured Victron device.
  Future<void> startListening({
    required String targetMac,
    required String encryptionKey,
    bool forceRestart = false,
  }) async {
    _targetMac = targetMac;
    _encryptionKey = encryptionKey;

    if (_isListening && !forceRestart) {
      // If we intended to be listening, but the scan stopped (e.g. Android scan limits/timeout),
      // restart the scan!
      if (!FlutterBluePlus.isScanningNow) {
        try {
          await FlutterBluePlus.startScan(
            timeout: const Duration(minutes: 60),
            androidUsesFineLocation: false,
            continuousUpdates: true,
          );
        } catch (_) {}
      }
      return;
    }

    if (forceRestart) {
      await stopListening();
    }

    _isListening = true;

    // Check adapter state
    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        return;
      }

      // Listen to scan results stream
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _processScanResults(results);
      });

      // Start continuous low-latency scan if not already scanning
      if (!FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.startScan(
          timeout: const Duration(minutes: 60),
          androidUsesFineLocation: false,
          continuousUpdates: true,
        );
      }
    } catch (_) {
      // Ignored for transient scan start errors
    }
  }

  void _processScanResults(List<ScanResult> results) {
    if (_targetMac == null || _encryptionKey == null) return;

    for (final r in results) {
      if (r.device.remoteId.str.toLowerCase() == _targetMac!.toLowerCase()) {
        final manufacturerData = r.advertisementData.manufacturerData;
        if (manufacturerData.containsKey(
          VictronMpptParser.victronManufacturerId,
        )) {
          final data = VictronMpptParser.parseAdvertisement(
            manufacturerData: manufacturerData,
            encryptionKeyHex: _encryptionKey!,
          );

          if (data != null) {
            _latestData = data;
            if (!_solarController.isClosed) {
              _solarController.add(data);
            }
          }
        }
      }
    }
  }

  /// Stops the active advertisement listener and cancels active BLE scan.
  Future<void> stopListening() async {
    _isListening = false;
    _latestData = null;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {}
  }

  /// One-shot BLE scan query designed for the WorkManager background task.
  static Future<VictronMpptData?> fetchOneShotSolarTelemetry({
    required String targetMac,
    required String encryptionKey,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    StreamSubscription<List<ScanResult>>? sub;
    try {
      final completer = Completer<VictronMpptData?>();

      sub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          if (r.device.remoteId.str.toLowerCase() == targetMac.toLowerCase()) {
            final manufacturerData = r.advertisementData.manufacturerData;
            if (manufacturerData.containsKey(
              VictronMpptParser.victronManufacturerId,
            )) {
              final data = VictronMpptParser.parseAdvertisement(
                manufacturerData: manufacturerData,
                encryptionKeyHex: encryptionKey,
              );
              if (data != null && !completer.isCompleted) {
                completer.complete(data);
              }
            }
          }
        }
      });

      if (!FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.startScan(
          timeout: timeout,
          androidUsesFineLocation: false,
        );
      }

      final result = await completer.future.timeout(
        timeout,
        onTimeout: () => null,
      );

      return result;
    } catch (_) {
      return null;
    } finally {
      await sub?.cancel();
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    }
  }

  void dispose() {
    stopListening();
    _solarController.close();
  }
}
