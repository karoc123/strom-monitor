/// Information about a discovered BLE peripheral.
class BleDeviceInfo {
  final String id; // MAC Address / UUID identifier
  final String name; // Advertised Device Name
  final int rssi; // Signal Strength in dBm

  const BleDeviceInfo({
    required this.id,
    required this.name,
    required this.rssi,
  });

  bool get isJbdCandidate {
    final lower = name.toLowerCase();
    return lower.contains('jbd') ||
        lower.contains('xiaoxiang') ||
        lower.contains('liontron') ||
        lower.contains('bms') ||
        lower.contains('smart');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleDeviceInfo &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'BleDeviceInfo(name: $name, id: $id, rssi: ${rssi}dBm)';
}
