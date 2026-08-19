/// Operational state of a Victron Solar Charger.
enum VictronDeviceState {
  off(0, 'Off'),
  lowPower(1, 'Low Power'),
  fault(2, 'Fault'),
  bulk(3, 'Bulk'),
  absorption(4, 'Absorption'),
  floatState(5, 'Float'),
  storage(6, 'Storage'),
  equalize(7, 'Equalize'),
  startingUp(245, 'Starting Up'),
  autoEqualize(247, 'Auto Equalize'),
  externalControl(252, 'External Control'),
  unknown(255, 'Unknown');

  final int code;
  final String displayName;
  const VictronDeviceState(this.code, this.displayName);

  static VictronDeviceState fromCode(int code) {
    for (final state in VictronDeviceState.values) {
      if (state.code == code) return state;
    }
    return VictronDeviceState.unknown;
  }

  bool get isCharging =>
      this == VictronDeviceState.bulk ||
      this == VictronDeviceState.absorption ||
      this == VictronDeviceState.floatState ||
      this == VictronDeviceState.storage ||
      this == VictronDeviceState.equalize;
}

/// Error codes reported by a Victron Solar Charger.
enum VictronChargerError {
  noError(0, 'No Error'),
  batteryVoltageHigh(2, 'Battery voltage too high'),
  chargerTemperatureHigh(17, 'Charger temperature too high'),
  chargerOverCurrent(18, 'Charger over-current'),
  bulkTimeLimit(20, 'Bulk time limit exceeded'),
  currentSensorIssue(21, 'Current sensor issue'),
  terminalsOverheated(26, 'Terminals overheated'),
  pvVoltageHigh(33, 'PV input voltage too high'),
  pvOverCurrent(34, 'PV input over-current'),
  inputShutdown(38, 'Input shutdown (battery voltage high)'),
  unknown(255, 'Unknown error');

  final int code;
  final String description;
  const VictronChargerError(this.code, this.description);

  static VictronChargerError fromCode(int code) {
    for (final err in VictronChargerError.values) {
      if (err.code == code) return err;
    }
    return VictronChargerError.unknown;
  }
}

/// Decoded telemetry data from a Victron SmartSolar MPPT charge controller.
class VictronMpptData {
  final VictronDeviceState deviceState;
  final VictronChargerError chargerError;
  final double batteryVoltage; // Volts
  final double batteryCurrent; // Amperes
  final double solarPower; // Watts
  final double yieldTodayWh; // Watt-hours (Wh)
  final double? loadCurrent; // Amperes (if load output is present)
  final DateTime timestamp;
  final int rawState;
  final int rawError;

  const VictronMpptData({
    required this.deviceState,
    required this.chargerError,
    required this.batteryVoltage,
    required this.batteryCurrent,
    required this.solarPower,
    required this.yieldTodayWh,
    this.loadCurrent,
    required this.timestamp,
    required this.rawState,
    required this.rawError,
  });

  /// Yield in kilowatt-hours (kWh)
  double get yieldTodayKwh => yieldTodayWh / 1000.0;

  @override
  String toString() =>
      'VictronMpptData(state: ${deviceState.displayName}, solar: ${solarPower}W, '
      'yield: ${yieldTodayWh.toStringAsFixed(0)}Wh, batt: ${batteryVoltage}V / ${batteryCurrent}A)';
}
