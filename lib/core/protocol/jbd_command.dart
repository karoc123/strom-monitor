/// Known JBD / Xiaoxiang BMS Command Register codes.
class JbdCommand {
  const JbdCommand._();

  /// Start of Frame delimiter.
  static const int startByte = 0xDD;

  /// Read command action code.
  static const int readAction = 0xA5;

  /// Write command action code.
  static const int writeAction = 0x5A;

  /// End of Frame delimiter.
  static const int stopByte = 0x77;

  /// Command 0x03: Read basic battery info (Voltage, Current, Capacity, SoC, Temps, etc.)
  static const int readBasicInfo = 0x03;

  /// Command 0x04: Read individual cell voltages (Cell 1 .. N in mV)
  static const int readCellVoltages = 0x04;

  /// Command 0x05: Read BMS hardware / version name string
  static const int readHardwareVersion = 0x05;
}
