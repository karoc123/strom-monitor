/// Persistent battery telemetry reading representing one historical time-series point.
class BatteryReading {
  final int? id;
  final int timestamp; // Unix epoch in milliseconds
  final int soc; // State of Charge (0-100)
  final double voltage; // Total pack voltage in Volts
  final double current; // Current in Amperes
  final double power; // Calculated power in Watts (voltage * current)

  // Extensible telemetry fields
  final double? cellVoltage1;
  final double? cellVoltage2;
  final double? cellVoltage3;
  final double? cellVoltage4;
  final double? tempBms;
  final double? tempCells;
  final int? cycles;

  // Solar (Victron MPPT) telemetry fields
  final double? solarPower; // Instantaneous solar power in Watts
  final double? solarYieldToday; // Solar yield today in Watt-hours (Wh)
  final double? solarVoltage; // Solar panel / battery voltage in Volts
  final double? solarCurrent; // Solar charge current in Amperes
  final int? solarState; // VictronDeviceState code

  const BatteryReading({
    this.id,
    required this.timestamp,
    required this.soc,
    required this.voltage,
    required this.current,
    required this.power,
    this.cellVoltage1,
    this.cellVoltage2,
    this.cellVoltage3,
    this.cellVoltage4,
    this.tempBms,
    this.tempCells,
    this.cycles,
    this.solarPower,
    this.solarYieldToday,
    this.solarVoltage,
    this.solarCurrent,
    this.solarState,
  });

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  /// Convert SQLite row map to [BatteryReading].
  factory BatteryReading.fromMap(Map<String, dynamic> map) {
    return BatteryReading(
      id: map['id'] as int?,
      timestamp: map['timestamp'] as int,
      soc: map['soc'] as int,
      voltage: (map['voltage'] as num).toDouble(),
      current: (map['current'] as num).toDouble(),
      power: (map['power'] as num).toDouble(),
      cellVoltage1: (map['cell_voltage_1'] as num?)?.toDouble(),
      cellVoltage2: (map['cell_voltage_2'] as num?)?.toDouble(),
      cellVoltage3: (map['cell_voltage_3'] as num?)?.toDouble(),
      cellVoltage4: (map['cell_voltage_4'] as num?)?.toDouble(),
      tempBms: (map['temp_bms'] as num?)?.toDouble(),
      tempCells: (map['temp_cells'] as num?)?.toDouble(),
      cycles: map['cycles'] as int?,
      solarPower: (map['solar_power'] as num?)?.toDouble(),
      solarYieldToday: (map['solar_yield_today'] as num?)?.toDouble(),
      solarVoltage: (map['solar_voltage'] as num?)?.toDouble(),
      solarCurrent: (map['solar_current'] as num?)?.toDouble(),
      solarState: map['solar_state'] as int?,
    );
  }

  /// Convert [BatteryReading] to SQLite row map.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'timestamp': timestamp,
      'soc': soc,
      'voltage': voltage,
      'current': current,
      'power': power,
    };
    if (id != null) map['id'] = id;
    if (cellVoltage1 != null) map['cell_voltage_1'] = cellVoltage1;
    if (cellVoltage2 != null) map['cell_voltage_2'] = cellVoltage2;
    if (cellVoltage3 != null) map['cell_voltage_3'] = cellVoltage3;
    if (cellVoltage4 != null) map['cell_voltage_4'] = cellVoltage4;
    if (tempBms != null) map['temp_bms'] = tempBms;
    if (tempCells != null) map['temp_cells'] = tempCells;
    if (cycles != null) map['cycles'] = cycles;
    if (solarPower != null) map['solar_power'] = solarPower;
    if (solarYieldToday != null) map['solar_yield_today'] = solarYieldToday;
    if (solarVoltage != null) map['solar_voltage'] = solarVoltage;
    if (solarCurrent != null) map['solar_current'] = solarCurrent;
    if (solarState != null) map['solar_state'] = solarState;
    return map;
  }

  /// JSON serialization
  Map<String, dynamic> toJson() => toMap();

  /// JSON deserialization
  factory BatteryReading.fromJson(Map<String, dynamic> json) =>
      BatteryReading.fromMap(json);

  /// CSV Header row
  static String get csvHeader =>
      'timestamp_ms,iso_time,soc_percent,voltage_v,current_a,power_w,cell1_v,cell2_v,cell3_v,cell4_v,temp_bms_c,temp_cells_c,cycles,solar_power_w,solar_yield_wh,solar_v,solar_a,solar_state';

  /// Convert to CSV row
  String toCsvRow() {
    final iso = DateTime.fromMillisecondsSinceEpoch(
      timestamp,
    ).toIso8601String();
    return '$timestamp,$iso,$soc,$voltage,$current,$power,'
        '${cellVoltage1 ?? ""},${cellVoltage2 ?? ""},${cellVoltage3 ?? ""},${cellVoltage4 ?? ""},'
        '${tempBms ?? ""},${tempCells ?? ""},${cycles ?? ""},'
        '${solarPower ?? ""},${solarYieldToday ?? ""},${solarVoltage ?? ""},${solarCurrent ?? ""},${solarState ?? ""}';
  }

  /// Parse from CSV row
  static BatteryReading? fromCsvRow(String line) {
    final parts = line.split(',');
    if (parts.length < 6) return null;

    try {
      final ts = int.parse(parts[0].trim());
      final soc = int.parse(parts[2].trim());
      final volt = double.parse(parts[3].trim());
      final curr = double.parse(parts[4].trim());
      final pow = double.parse(parts[5].trim());

      double? c1 = parts.length > 6 && parts[6].isNotEmpty
          ? double.tryParse(parts[6])
          : null;
      double? c2 = parts.length > 7 && parts[7].isNotEmpty
          ? double.tryParse(parts[7])
          : null;
      double? c3 = parts.length > 8 && parts[8].isNotEmpty
          ? double.tryParse(parts[8])
          : null;
      double? c4 = parts.length > 9 && parts[9].isNotEmpty
          ? double.tryParse(parts[9])
          : null;
      double? tb = parts.length > 10 && parts[10].isNotEmpty
          ? double.tryParse(parts[10])
          : null;
      double? tc = parts.length > 11 && parts[11].isNotEmpty
          ? double.tryParse(parts[11])
          : null;
      int? cyc = parts.length > 12 && parts[12].isNotEmpty
          ? int.tryParse(parts[12])
          : null;

      double? solP = parts.length > 13 && parts[13].isNotEmpty
          ? double.tryParse(parts[13])
          : null;
      double? solY = parts.length > 14 && parts[14].isNotEmpty
          ? double.tryParse(parts[14])
          : null;
      double? solV = parts.length > 15 && parts[15].isNotEmpty
          ? double.tryParse(parts[15])
          : null;
      double? solI = parts.length > 16 && parts[16].isNotEmpty
          ? double.tryParse(parts[16])
          : null;
      int? solS = parts.length > 17 && parts[17].isNotEmpty
          ? int.tryParse(parts[17])
          : null;

      return BatteryReading(
        timestamp: ts,
        soc: soc,
        voltage: volt,
        current: curr,
        power: pow,
        cellVoltage1: c1,
        cellVoltage2: c2,
        cellVoltage3: c3,
        cellVoltage4: c4,
        tempBms: tb,
        tempCells: tc,
        cycles: cyc,
        solarPower: solP,
        solarYieldToday: solY,
        solarVoltage: solV,
        solarCurrent: solI,
        solarState: solS,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() =>
      'BatteryReading(ts: $timestamp, soc: $soc%, voltage: ${voltage}V, current: ${current}A, power: ${power}W, solar: ${solarPower ?? "--"}W)';
}
