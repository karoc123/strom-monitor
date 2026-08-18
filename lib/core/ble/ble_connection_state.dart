/// BLE Connection and polling status.
enum BleConnectionStatus {
  disconnected,
  scanning,
  connecting,
  connected,
  polling,
  error,
}

/// Detailed state holder for BLE connectivity.
class BleState {
  final BleConnectionStatus status;
  final String? connectedDeviceId;
  final String? connectedDeviceName;
  final String? errorMessage;

  const BleState({
    this.status = BleConnectionStatus.disconnected,
    this.connectedDeviceId,
    this.connectedDeviceName,
    this.errorMessage,
  });

  BleState copyWith({
    BleConnectionStatus? status,
    String? connectedDeviceId,
    String? connectedDeviceName,
    String? errorMessage,
  }) {
    return BleState(
      status: status ?? this.status,
      connectedDeviceId: connectedDeviceId ?? this.connectedDeviceId,
      connectedDeviceName: connectedDeviceName ?? this.connectedDeviceName,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isConnected =>
      status == BleConnectionStatus.connected ||
      status == BleConnectionStatus.polling;

  @override
  String toString() =>
      'BleState(status: $status, device: $connectedDeviceName ($connectedDeviceId), error: $errorMessage)';
}
