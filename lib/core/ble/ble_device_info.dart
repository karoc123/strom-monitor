/// Information about a discovered BLE peripheral.
class BleDeviceInfo {
  final String id; // MAC Address / UUID identifier
  final String name; // Advertised Device Name
  final int rssi; // Signal Strength in dBm

  final Map<int, List<int>> manufacturerData;

  const BleDeviceInfo({
    required this.id,
    required this.name,
    required this.rssi,
    this.manufacturerData = const {},
  });

  bool get isJbdCandidate {
    final lower = name.toLowerCase();
    return lower.contains('jbd') ||
        lower.contains('xiaoxiang') ||
        lower.contains('liontron') ||
        lower.contains('bms');
  }

  bool get isVictronCandidate {
    if (manufacturerData.containsKey(0x02E1)) return true;
    final lower = name.toLowerCase();
    return lower.contains('smartsolar') ||
        lower.contains('bluesolar') ||
        lower.contains('victron');
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
