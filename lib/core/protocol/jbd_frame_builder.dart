import 'dart:typed_data';
import 'jbd_checksum.dart';
import 'jbd_command.dart';

/// Helper to build raw JBD request frames.
class JbdFrameBuilder {
  const JbdFrameBuilder._();

  /// Builds a read command frame for a specified register [command].
  ///
  /// Structure:
  /// [0xDD, 0xA5, command, 0x00, checksum_hi, checksum_lo, 0x77]
  static Uint8List buildReadCommand(int command) {
    final payloadToChecksum = [command, 0x00];
    final checksumBytes = JbdChecksum.calculateBytes(payloadToChecksum);

    return Uint8List.fromList([
      JbdCommand.startByte,
      JbdCommand.readAction,
      command,
      0x00,
      checksumBytes[0],
      checksumBytes[1],
      JbdCommand.stopByte,
    ]);
  }

  /// Builds command frame to query basic battery information (0x03).
  static Uint8List buildBasicInfoRequest() {
    return buildReadCommand(JbdCommand.readBasicInfo);
  }

  /// Builds command frame to query individual cell voltages (0x04).
  static Uint8List buildCellVoltagesRequest() {
    return buildReadCommand(JbdCommand.readCellVoltages);
  }

  /// Builds command frame to query hardware/version information (0x05).
  static Uint8List buildHardwareVersionRequest() {
    return buildReadCommand(JbdCommand.readHardwareVersion);
  }
}
