import 'dart:typed_data';

import 'jbd_checksum.dart';
import 'jbd_command.dart';

/// Represents a successfully parsed and checksum-verified JBD response frame.
class JbdResponseFrame {
  /// The command byte that was echoed (e.g. 0x03 for basic info, 0x04 for cell voltages).
  final int command;

  /// Status byte (0x00 indicates success; non-zero indicates error).
  final int status;

  /// The raw payload data extracted from the frame.
  final Uint8List payload;

  const JbdResponseFrame({
    required this.command,
    required this.status,
    required this.payload,
  });

  bool get isSuccess => status == 0x00;

  @override
  String toString() =>
      'JbdResponseFrame(command: 0x${command.toRadixString(16)}, status: $status, payloadLength: ${payload.length})';
}

/// Accumulates incoming BLE chunks and reassembles complete, validated [JbdResponseFrame]s.
class JbdFrameReassembler {
  final List<int> _buffer = [];

  /// Processes newly received bytes from a BLE GATT notification and returns
  /// any complete, verified frames found.
  List<JbdResponseFrame> processBytes(List<int> incomingBytes) {
    _buffer.addAll(incomingBytes);
    final frames = <JbdResponseFrame>[];

    while (true) {
      // Find start byte 0xDD
      final startIndex = _buffer.indexOf(JbdCommand.startByte);
      if (startIndex == -1) {
        // No start byte in buffer, discard everything
        _buffer.clear();
        break;
      }

      // Discard any garbage bytes before start byte
      if (startIndex > 0) {
        _buffer.removeRange(0, startIndex);
      }

      // Need at least 4 bytes to read command, status, and payload length:
      // [0xDD, cmd, status, len]
      if (_buffer.length < 4) {
        break;
      }

      final dataLength = _buffer[3];
      final totalFrameLength =
          dataLength +
          7; // 0xDD, cmd, status, len, payload(N), chk_hi, chk_lo, 0x77

      // Check if complete frame is available in buffer
      if (_buffer.length < totalFrameLength) {
        break;
      }

      // Check stop byte
      if (_buffer[totalFrameLength - 1] != JbdCommand.stopByte) {
        // Invalid frame framing: remove start byte and search again
        _buffer.removeAt(0);
        continue;
      }

      final frameBytes = Uint8List.fromList(
        _buffer.sublist(0, totalFrameLength),
      );

      // Verify checksum
      if (!JbdChecksum.verifyFrame(frameBytes)) {
        // Corrupt frame: discard start byte and try next
        _buffer.removeAt(0);
        continue;
      }

      // Valid frame extracted!
      final command = frameBytes[1];
      final status = frameBytes[2];
      final payload = frameBytes.sublist(4, 4 + dataLength);

      frames.add(
        JbdResponseFrame(
          command: command,
          status: status,
          payload: Uint8List.fromList(payload),
        ),
      );

      // Remove the consumed frame from buffer
      _buffer.removeRange(0, totalFrameLength);
    }

    return frames;
  }

  /// Resets and clears the internal buffer.
  void reset() {
    _buffer.clear();
  }
}
