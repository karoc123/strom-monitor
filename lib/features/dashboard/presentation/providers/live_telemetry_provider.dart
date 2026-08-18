import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/ble/ble_client.dart';
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
  final recorder = ref.watch(telemetryRecorderProvider);

  await for (final snapshot in client.telemetryStream) {
    // Throttled persistence in background
    unawaited(recorder.processSnapshot(snapshot));
    yield snapshot;
  }
});
