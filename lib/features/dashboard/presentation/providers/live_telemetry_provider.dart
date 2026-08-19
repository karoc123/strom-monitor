import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/ble/ble_client.dart';
import '../../../../core/protocol/victron/victron_mppt_data.dart';
import '../../../../core/providers/ble_provider.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../data/telemetry_recorder.dart';

final telemetryRecorderProvider = Provider<TelemetryRecorder>((ref) {
  final readingDao = ref.watch(readingDaoProvider);
  final settings = ref.watch(settingsProvider);

  return TelemetryRecorder(
    readingDao: readingDao,
    minIntervalSeconds: settings.foregroundWriteIntervalSeconds,
    socDeltaThreshold: 1,
    voltageDeltaThreshold: 0.2,
  );
});

final liveTelemetryProvider = StreamProvider<BatterySnapshot>((ref) async* {
  final client = ref.watch(bleClientProvider);
  final victronClient = ref.watch(victronBleClientProvider);
  final recorder = ref.watch(telemetryRecorderProvider);

  await for (final snapshot in client.telemetryStream) {
    // Throttled persistence in background (with latest solar data if present)
    unawaited(
      recorder.processTelemetry(
        batterySnapshot: snapshot,
        solarData: victronClient.latestData,
      ),
    );
    yield snapshot;
  }
});

final liveSolarTelemetryProvider = StreamProvider<VictronMpptData>((
  ref,
) async* {
  final victronClient = ref.watch(victronBleClientProvider);
  final settings = ref.watch(settingsProvider);
  final recorder = ref.watch(telemetryRecorderProvider);

  await for (final solarData in victronClient.solarStream) {
    // Only record standalone solar telemetry if no BMS is configured
    if (!settings.hasBmsDevice) {
      unawaited(recorder.processTelemetry(solarData: solarData));
    }
    yield solarData;
  }
});
