import 'package:flutter_test/flutter_test.dart';
import 'package:jbd_battery_monitor/core/ble/ble_client.dart';
import 'package:jbd_battery_monitor/core/ble/ble_connection_state.dart';
import 'package:jbd_battery_monitor/core/ble/ble_lifecycle_coordinator.dart';
import 'package:jbd_battery_monitor/core/ble/victron_ble_client.dart';
import 'package:jbd_battery_monitor/features/settings/domain/app_settings.dart';

class FakeBleClient extends BleClient {
  bool connectCalled = false;
  String? connectedMac;
  bool disconnectCalled = false;
  bool startPollingCalled = false;
  bool stopPollingCalled = false;
  bool mockConnectSuccess = true;
  BleState _mockState = const BleState();
  bool _mockIsStale = false;

  @override
  BleState get currentState => _mockState;

  @override
  bool get isStale => _mockIsStale;

  void setMockState(BleState state) => _mockState = state;
  void setMockIsStale(bool stale) => _mockIsStale = stale;

  @override
  Future<bool> connect(String deviceId) async {
    connectCalled = true;
    connectedMac = deviceId;
    return mockConnectSuccess;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalled = true;
    _mockState = const BleState(status: BleConnectionStatus.disconnected);
  }

  @override
  void startPolling({Duration interval = const Duration(seconds: 1)}) {
    startPollingCalled = true;
  }

  @override
  void stopPolling() {
    stopPollingCalled = true;
  }
}

class FakeVictronBleClient extends VictronBleClient {
  bool startListeningCalled = false;
  String? targetMac;
  String? encryptionKey;
  bool? forceRestart;
  bool stopListeningCalled = false;

  @override
  Future<void> startListening({
    required String targetMac,
    required String encryptionKey,
    bool forceRestart = false,
  }) async {
    startListeningCalled = true;
    this.targetMac = targetMac;
    this.encryptionKey = encryptionKey;
    this.forceRestart = forceRestart;
  }

  @override
  Future<void> stopListening() async {
    stopListeningCalled = true;
  }
}

void main() {
  group('BleLifecycleCoordinator Tests', () {
    late FakeBleClient fakeBleClient;
    late FakeVictronBleClient fakeVictronClient;
    late AppSettings currentSettings;

    setUp(() {
      fakeBleClient = FakeBleClient();
      fakeVictronClient = FakeVictronBleClient();
      currentSettings = const AppSettings(
        targetDeviceMac: 'AA:BB:CC:DD:EE:FF',
        victronDeviceMac: '11:22:33:44:55:66',
        victronEncryptionKey: '0123456789abcdef0123456789abcdef',
      );
    });

    test(
      'onAppPaused stops BMS polling and Victron listening to save battery',
      () async {
        final coordinator = BleLifecycleCoordinator(
          bleClient: fakeBleClient,
          victronClient: fakeVictronClient,
          getSettings: () => currentSettings,
        );

        await coordinator.onAppPaused();

        expect(fakeBleClient.stopPollingCalled, isTrue);
        expect(fakeVictronClient.stopListeningCalled, isTrue);
      },
    );

    test('onAppResumed re-connects BMS and restarts Victron scan with forceRestart', () async {
      final coordinator = BleLifecycleCoordinator(
        bleClient: fakeBleClient,
        victronClient: fakeVictronClient,
        getSettings: () => currentSettings,
      );

      await coordinator.onAppResumed();

      // Victron scan restarted fresh
      expect(fakeVictronClient.startListeningCalled, isTrue);
      expect(fakeVictronClient.targetMac, '11:22:33:44:55:66');
      expect(
        fakeVictronClient.encryptionKey,
        '0123456789abcdef0123456789abcdef',
      );
      expect(fakeVictronClient.forceRestart, isTrue);

      // BMS connection established and polling started
      expect(fakeBleClient.connectCalled, isTrue);
      expect(fakeBleClient.connectedMac, 'AA:BB:CC:DD:EE:FF');
      expect(fakeBleClient.startPollingCalled, isTrue);
    });

    test('onAppResumed resumes polling without reconnecting if BMS is healthy and not stale', () async {
      fakeBleClient.setMockState(
        const BleState(status: BleConnectionStatus.connected),
      );
      fakeBleClient.setMockIsStale(false);

      final coordinator = BleLifecycleCoordinator(
        bleClient: fakeBleClient,
        victronClient: fakeVictronClient,
        getSettings: () => currentSettings,
      );

      await coordinator.onAppResumed();

      // Did not disconnect or reconnect
      expect(fakeBleClient.disconnectCalled, isFalse);
      expect(fakeBleClient.connectCalled, isFalse);
      // Directly resumed polling
      expect(fakeBleClient.startPollingCalled, isTrue);
    });

    test(
      'onAppResumed disconnects and reconnects when BMS connection is stale',
      () async {
        fakeBleClient.setMockState(
          const BleState(status: BleConnectionStatus.connected),
        );
        // Connection is marked stale (no heartbeat for > 8s)
        fakeBleClient.setMockIsStale(true);

        final coordinator = BleLifecycleCoordinator(
          bleClient: fakeBleClient,
          victronClient: fakeVictronClient,
          getSettings: () => currentSettings,
        );

        await coordinator.onAppResumed();

        // Disconnected stale zombie connection first
        expect(fakeBleClient.disconnectCalled, isTrue);
        // Then reconnected and resumed polling
        expect(fakeBleClient.connectCalled, isTrue);
        expect(fakeBleClient.startPollingCalled, isTrue);
      },
    );

    test('does nothing when no devices are configured in settings', () async {
      final coordinator = BleLifecycleCoordinator(
        bleClient: fakeBleClient,
        victronClient: fakeVictronClient,
        getSettings: () => const AppSettings(),
      );

      await coordinator.onAppResumed();

      expect(fakeVictronClient.startListeningCalled, isFalse);
      expect(fakeBleClient.connectCalled, isFalse);
      expect(fakeBleClient.startPollingCalled, isFalse);
    });
  });
}
