import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ble/ble_client.dart';
import '../ble/ble_connection_state.dart';
import '../ble/ble_device_info.dart';

final bleClientProvider = Provider<BleClient>((ref) {
  final client = BleClient();
  ref.onDispose(() => client.dispose());
  return client;
});

final bleStateStreamProvider = StreamProvider<BleState>((ref) {
  final client = ref.watch(bleClientProvider);
  return client.stateStream;
});

final bleScanResultsProvider = StreamProvider.autoDispose<List<BleDeviceInfo>>((
  ref,
) {
  final client = ref.watch(bleClientProvider);
  return client.scanDevices(timeout: const Duration(seconds: 8));
});
