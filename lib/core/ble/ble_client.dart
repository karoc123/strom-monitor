import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../protocol/jbd_command.dart';
import '../protocol/jbd_frame_builder.dart';
import '../protocol/jbd_frame_reassembler.dart';
import '../protocol/jbd_telemetry_parser.dart';
import 'ble_connection_state.dart';
import 'ble_device_info.dart';

/// Telemetry snapshot containing both basic info and cell voltages.
class BatterySnapshot {
  final JbdBasicInfo basicInfo;
  final List<double> cellVoltages;
  final DateTime timestamp;

  const BatterySnapshot({
    required this.basicInfo,
    required this.cellVoltages,
    required this.timestamp,
  });

  @override
  String toString() =>
      'BatterySnapshot(time: $timestamp, soc: ${basicInfo.soc}%, voltage: ${basicInfo.voltage}V, current: ${basicInfo.current}A, cells: $cellVoltages)';
}

/// BLE Client managing GATT connections, characteristic subscriptions,
/// and JBD protocol polling.
class BleClient {
  static const String writeCharUuid = '0000ff02-0000-1000-8000-00805f9b34fb';
  static const String notifyCharUuid = '0000ff01-0000-1000-8000-00805f9b34fb';

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;

  StreamSubscription<List<int>>? _notifySubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  Timer? _pollingTimer;

  final JbdFrameReassembler _reassembler = JbdFrameReassembler();

  final _stateController = StreamController<BleState>.broadcast();
  Stream<BleState> get stateStream => _stateController.stream;
  BleState _currentState = const BleState();
  BleState get currentState => _currentState;

  final _telemetryController = StreamController<BatterySnapshot>.broadcast();
  Stream<BatterySnapshot> get telemetryStream => _telemetryController.stream;

  JbdBasicInfo? _latestBasicInfo;
  List<double> _latestCellVoltages = const [];

  void _updateState(BleState newState) {
    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  /// Scans for BLE devices and yields an updated list of [BleDeviceInfo].
  Stream<List<BleDeviceInfo>> scanDevices({
    Duration timeout = const Duration(seconds: 6),
  }) async* {
    final devicesMap = <String, BleDeviceInfo>{};

    // Check adapter state
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      _updateState(
        _currentState.copyWith(
          status: BleConnectionStatus.error,
          errorMessage: 'Bluetooth is turned off.',
        ),
      );
      yield [];
      return;
    }

    _updateState(_currentState.copyWith(status: BleConnectionStatus.scanning));

    try {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: false,
      );

      await for (final results in FlutterBluePlus.scanResults) {
        for (final r in results) {
          final name = r.device.platformName.isNotEmpty
              ? r.device.platformName
              : r.advertisementData.advName;
          final id = r.device.remoteId.str;
          devicesMap[id] = BleDeviceInfo(
            id: id,
            name: name.isNotEmpty ? name : 'Unknown Device',
            rssi: r.rssi,
            manufacturerData: r.advertisementData.manufacturerData,
          );
        }
        yield devicesMap.values.toList();
      }
    } catch (e) {
      _updateState(
        _currentState.copyWith(
          status: BleConnectionStatus.error,
          errorMessage: 'Scan failed: $e',
        ),
      );
    } finally {
      await FlutterBluePlus.stopScan();
      if (_currentState.status == BleConnectionStatus.scanning) {
        _updateState(
          _currentState.copyWith(status: BleConnectionStatus.disconnected),
        );
      }
    }
  }

  /// Connects to a specific BLE device by [deviceId].
  Future<bool> connect(String deviceId) async {
    await disconnect();

    _updateState(
      _currentState.copyWith(
        status: BleConnectionStatus.connecting,
        connectedDeviceId: deviceId,
        errorMessage: null,
      ),
    );

    try {
      final device = BluetoothDevice.fromId(deviceId);
      _connectedDevice = device;

      // Monitor connection state
      _connectionStateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _updateState(
            const BleState(status: BleConnectionStatus.disconnected),
          );
          _cleanupConnectionResources();
        }
      });

      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );

      // Discover GATT services
      final services = await device.discoverServices();
      for (final service in services) {
        for (final characteristic in service.characteristics) {
          final charUuidStr = characteristic.uuid.str128.toLowerCase();
          if (charUuidStr == notifyCharUuid ||
              charUuidStr.contains('ff01') ||
              characteristic.uuid.str.toLowerCase() == 'ff01') {
            _notifyCharacteristic = characteristic;
          }
          if (charUuidStr == writeCharUuid ||
              charUuidStr.contains('ff02') ||
              characteristic.uuid.str.toLowerCase() == 'ff02') {
            _writeCharacteristic = characteristic;
          }
        }
      }

      if (_notifyCharacteristic == null || _writeCharacteristic == null) {
        throw Exception(
          'JBD GATT characteristics (0xFF01 / 0xFF02) not found.',
        );
      }

      // Subscribe to notifications
      await _notifyCharacteristic!.setNotifyValue(true);
      _reassembler.reset();

      _notifySubscription = _notifyCharacteristic!.onValueReceived.listen((
        data,
      ) {
        _handleIncomingBytes(data);
      });

      _updateState(
        BleState(
          status: BleConnectionStatus.connected,
          connectedDeviceId: deviceId,
          connectedDeviceName: device.platformName,
        ),
      );

      return true;
    } catch (e) {
      _updateState(
        BleState(
          status: BleConnectionStatus.error,
          errorMessage: 'Connection error: $e',
        ),
      );
      await disconnect();
      return false;
    }
  }

  void _handleIncomingBytes(List<int> bytes) {
    final frames = _reassembler.processBytes(bytes);
    for (final frame in frames) {
      if (!frame.isSuccess) continue;

      if (frame.command == JbdCommand.readBasicInfo) {
        final basicInfo = JbdTelemetryParser.parseBasicInfo(frame.payload);
        if (basicInfo != null) {
          _latestBasicInfo = basicInfo;
          _emitSnapshot();
        }
      } else if (frame.command == JbdCommand.readCellVoltages) {
        final cellVoltages = JbdTelemetryParser.parseCellVoltages(
          frame.payload,
        );
        if (cellVoltages.isNotEmpty) {
          _latestCellVoltages = cellVoltages;
          _emitSnapshot();
        }
      }
    }
  }

  void _emitSnapshot() {
    if (_latestBasicInfo != null) {
      final snapshot = BatterySnapshot(
        basicInfo: _latestBasicInfo!,
        cellVoltages: _latestCellVoltages,
        timestamp: DateTime.now(),
      );
      if (!_telemetryController.isClosed) {
        _telemetryController.add(snapshot);
      }
    }
  }

  /// Starts polling the connected BMS at the given [interval].
  void startPolling({Duration interval = const Duration(seconds: 1)}) {
    _pollingTimer?.cancel();
    if (_currentState.isConnected) {
      _updateState(_currentState.copyWith(status: BleConnectionStatus.polling));
    }

    _pollOnce();
    _pollingTimer = Timer.periodic(interval, (_) => _pollOnce());
  }

  /// Stops the active polling loop.
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    if (_currentState.status == BleConnectionStatus.polling) {
      _updateState(
        _currentState.copyWith(status: BleConnectionStatus.connected),
      );
    }
  }

  Future<void> _pollOnce() async {
    if (_writeCharacteristic == null) return;
    try {
      // Send 0x03 Basic Info request
      await _writeCharacteristic!.write(
        JbdFrameBuilder.buildBasicInfoRequest(),
        withoutResponse: true,
      );
      // Small pause between commands for BMS processing
      await Future.delayed(const Duration(milliseconds: 150));

      // Send 0x04 Cell Voltages request
      if (_writeCharacteristic != null) {
        await _writeCharacteristic!.write(
          JbdFrameBuilder.buildCellVoltagesRequest(),
          withoutResponse: true,
        );
      }
    } catch (_) {
      // Ignored for transient write drops; polling timer will re-attempt
    }
  }

  /// Executes a standalone, headless one-shot telemetry query.
  /// Designed for the WorkManager background task.
  static Future<BatterySnapshot?> fetchOneShotTelemetry({
    required String deviceId,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    BluetoothDevice? device;
    BluetoothCharacteristic? writeChar;
    BluetoothCharacteristic? notifyChar;
    StreamSubscription<List<int>>? sub;

    try {
      device = BluetoothDevice.fromId(deviceId);
      await device.connect(
        license: License.nonprofit,
        timeout: timeout,
        autoConnect: false,
      );

      final services = await device.discoverServices();
      for (final service in services) {
        for (final char in service.characteristics) {
          final uuid = char.uuid.str128.toLowerCase();
          if (uuid == notifyCharUuid || uuid.contains('ff01')) {
            notifyChar = char;
          }
          if (uuid == writeCharUuid || uuid.contains('ff02')) {
            writeChar = char;
          }
        }
      }

      if (writeChar == null || notifyChar == null) {
        await device.disconnect();
        return null;
      }

      await notifyChar.setNotifyValue(true);

      final completer = Completer<BatterySnapshot?>();
      final reassembler = JbdFrameReassembler();
      JbdBasicInfo? basicInfo;
      List<double> cellVoltages = const [];

      sub = notifyChar.onValueReceived.listen((bytes) {
        final frames = reassembler.processBytes(bytes);
        for (final frame in frames) {
          if (!frame.isSuccess) continue;

          if (frame.command == JbdCommand.readBasicInfo) {
            basicInfo = JbdTelemetryParser.parseBasicInfo(frame.payload);
          } else if (frame.command == JbdCommand.readCellVoltages) {
            cellVoltages = JbdTelemetryParser.parseCellVoltages(frame.payload);
          }

          if (basicInfo != null && !completer.isCompleted) {
            completer.complete(
              BatterySnapshot(
                basicInfo: basicInfo!,
                cellVoltages: cellVoltages,
                timestamp: DateTime.now(),
              ),
            );
          }
        }
      });

      // Send request 0x03
      await writeChar.write(
        JbdFrameBuilder.buildBasicInfoRequest(),
        withoutResponse: true,
      );

      // Timeout safety
      final result = await completer.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () => null,
      );

      return result;
    } catch (_) {
      return null;
    } finally {
      await sub?.cancel();
      try {
        await device?.disconnect();
      } catch (_) {}
    }
  }

  void _cleanupConnectionResources() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _notifySubscription?.cancel();
    _notifySubscription = null;
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
    _connectedDevice = null;
    _latestBasicInfo = null;
    _latestCellVoltages = const [];
    _reassembler.reset();
  }

  /// Disconnects from the currently connected device and releases resources.
  Future<void> disconnect() async {
    try {
      if (_notifyCharacteristic != null) {
        await _notifyCharacteristic!.setNotifyValue(false);
      }
    } catch (_) {}

    try {
      await _connectedDevice?.disconnect();
    } catch (_) {}

    _cleanupConnectionResources();
    _updateState(const BleState(status: BleConnectionStatus.disconnected));
  }

  void dispose() {
    disconnect();
    _stateController.close();
    _telemetryController.close();
  }
}
