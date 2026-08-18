import 'dart:typed_data';

/// Parsed basic telemetry data from JBD command 0x03.
class JbdBasicInfo {
  final double voltage; // Total pack voltage in Volts
  final double current; // Current in Amperes (>0 charging, <0 discharging)
  final double power; // Calculated power in Watts (voltage * current)
  final double remainingCapacityAh; // Remaining capacity in Ah
  final double nominalCapacityAh; // Nominal capacity in Ah
  final int cycleCount; // Lifetime charge cycle count
  final int soc; // State of charge in % (0 - 100)
  final bool chargeFetEnabled; // Whether charging FET is closed/enabled
  final bool dischargeFetEnabled; // Whether discharging FET is closed/enabled
  final int cellCount; // Number of battery cells in pack
  final List<double> temperatures; // Temperature sensor readings in °C
  final double? tempBms; // BMS temp in °C
  final double? tempCells; // Cells temp in °C
  final int protectionStatus; // Protection status bitmask
  final int balanceStatusLow; // Balance status bitmask (cells 1-16)
  final int balanceStatusHigh; // Balance status bitmask (cells 17-32)
  final int softwareVersion; // Software version

  const JbdBasicInfo({
    required this.voltage,
    required this.current,
    required this.power,
    required this.remainingCapacityAh,
    required this.nominalCapacityAh,
    required this.cycleCount,
    required this.soc,
    required this.chargeFetEnabled,
    required this.dischargeFetEnabled,
    required this.cellCount,
    required this.temperatures,
    this.tempBms,
    this.tempCells,
    required this.protectionStatus,
    required this.balanceStatusLow,
    required this.balanceStatusHigh,
    required this.softwareVersion,
  });

  bool get isCharging => current > 0.05;
  bool get isDischarging => current < -0.05;
  bool get isStandby => !isCharging && !isDischarging;

  @override
  String toString() =>
      'JbdBasicInfo(voltage: ${voltage}V, current: ${current}A, power: ${power}W, soc: $soc%)';
}

/// Parser for JBD protocol responses.
class JbdTelemetryParser {
  const JbdTelemetryParser._();

  /// Parses the payload of a 0x03 Basic Info response frame.
  static JbdBasicInfo? parseBasicInfo(Uint8List payload) {
    // Basic info payload requires at least 23 bytes
    if (payload.length < 23) {
      return null;
    }

    final byteData = ByteData.sublistView(payload);

    // 0-1: Total Voltage in 10mV units -> Volts
    final rawVoltage = byteData.getUint16(0, Endian.big);
    final voltage = rawVoltage / 100.0;

    // 2-3: Current in 10mA units (signed 16-bit integer) -> Amperes
    final rawCurrent = byteData.getInt16(2, Endian.big);
    final current = rawCurrent / 100.0;

    // Calculated power (Watts)
    final power = voltage * current;

    // 4-5: Remaining capacity in 10mAh units -> Ah
    final rawRemainingCap = byteData.getUint16(4, Endian.big);
    final remainingCapacityAh = rawRemainingCap / 100.0;

    // 6-7: Nominal capacity in 10mAh units -> Ah
    final rawNominalCap = byteData.getUint16(6, Endian.big);
    final nominalCapacityAh = rawNominalCap / 100.0;

    // 8-9: Cycle count
    final cycleCount = byteData.getUint16(8, Endian.big);

    // 12-13: Balance status low
    final balanceStatusLow = byteData.getUint16(12, Endian.big);

    // 14-15: Balance status high
    final balanceStatusHigh = byteData.getUint16(14, Endian.big);

    // 16-17: Protection status
    final protectionStatus = byteData.getUint16(16, Endian.big);

    // 18: Software version
    final softwareVersion = payload[18];

    // 19: State of Charge (0 - 100 %)
    final soc = payload[19].clamp(0, 100);

    // 20: FET Status (Bit 0: Charge, Bit 1: Discharge)
    final fetStatus = payload[20];
    final chargeFet = (fetStatus & 0x01) != 0;
    final dischargeFet = (fetStatus & 0x02) != 0;

    // 21: Cell count
    final cellCount = payload[21];

    // 22: NTC sensor count
    final ntcCount = payload[22];

    final temperatures = <double>[];
    for (int i = 0; i < ntcCount; i++) {
      final offset = 23 + (i * 2);
      if (offset + 1 < payload.length) {
        // Temperature is in 0.1 Kelvin: (raw - 2731) / 10.0 -> °C
        final rawKelvin = byteData.getUint16(offset, Endian.big);
        final celsius = (rawKelvin - 2731) / 10.0;
        temperatures.add(celsius);
      }
    }

    final tempBms = temperatures.isNotEmpty ? temperatures[0] : null;
    final tempCells = temperatures.length > 1 ? temperatures[1] : null;

    return JbdBasicInfo(
      voltage: voltage,
      current: current,
      power: power,
      remainingCapacityAh: remainingCapacityAh,
      nominalCapacityAh: nominalCapacityAh,
      cycleCount: cycleCount,
      soc: soc,
      chargeFetEnabled: chargeFet,
      dischargeFetEnabled: dischargeFet,
      cellCount: cellCount,
      temperatures: temperatures,
      tempBms: tempBms,
      tempCells: tempCells,
      protectionStatus: protectionStatus,
      balanceStatusLow: balanceStatusLow,
      balanceStatusHigh: balanceStatusHigh,
      softwareVersion: softwareVersion,
    );
  }

  /// Parses the payload of a 0x04 Cell Voltages response frame.
  /// Returns the list of cell voltages in Volts (e.g. [3.332, 3.337, 3.333, 3.330]).
  static List<double> parseCellVoltages(Uint8List payload) {
    if (payload.length < 2) {
      return const [];
    }

    final byteData = ByteData.sublistView(payload);
    final count = payload.length ~/ 2;
    final cellVoltages = <double>[];

    for (int i = 0; i < count; i++) {
      // Cell voltage is uint16 in millivolts -> Volts
      final millivolts = byteData.getUint16(i * 2, Endian.big);
      cellVoltages.add(millivolts / 1000.0);
    }

    return cellVoltages;
  }
}
