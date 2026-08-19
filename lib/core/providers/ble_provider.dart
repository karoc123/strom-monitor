import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ble/ble_client.dart';
import '../ble/ble_connection_state.dart';
import '../ble/ble_device_info.dart';
import '../ble/victron_ble_client.dart';
import '../protocol/victron/victron_mppt_data.dart';

final bleClientProvider = Provider<BleClient>((ref) {
  final client = BleClient();
  ref.onDispose(() => client.dispose());
  return client;
});

final victronBleClientProvider = Provider<VictronBleClient>((ref) {
  final client = VictronBleClient();
  ref.onDispose(() => client.dispose());
  return client;
});

final bleStateStreamProvider = StreamProvider<BleState>((ref) {
  final client = ref.watch(bleClientProvider);
  return client.stateStream;
});

final solarTelemetryStreamProvider = StreamProvider<VictronMpptData>((ref) {
  final client = ref.watch(victronBleClientProvider);
  return client.solarStream;
});

final bleScanResultsProvider = StreamProvider.autoDispose<List<BleDeviceInfo>>((
  ref,
) {
  final client = ref.watch(bleClientProvider);
  return client.scanDevices(timeout: const Duration(seconds: 8));
});
