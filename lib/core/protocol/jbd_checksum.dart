import 'dart:typed_data';

/// Utility class for calculating and verifying JBD / Xiaoxiang BMS protocol checksums.
///
/// The JBD protocol checksum algorithm is:
/// Checksum = 0x10000 - sum(bytes)
/// where sum is the 16-bit sum of the data payload bytes (starting after command/status
/// byte through the end of the data payload).
class JbdChecksum {
  const JbdChecksum._();

  /// Calculates the 16-bit JBD checksum for the provided [data] bytes.
  static int calculate(List<int> data) {
    int sum = 0;
    for (final byte in data) {
      sum = (sum + byte) & 0xFFFF;
    }
    return (0x10000 - sum) & 0xFFFF;
  }

  /// Calculates the 2-byte big-endian representation of the checksum.
  static List<int> calculateBytes(List<int> data) {
    final checksum = calculate(data);
    return [(checksum >> 8) & 0xFF, checksum & 0xFF];
  }

  /// Verifies if a complete JBD frame [frame] (starting with 0xDD and ending with 0x77)
  /// has a valid checksum.
  ///
  /// JBD Response Frame structure:
  /// [0] 0xDD (Start)
  /// [1] Command
  /// [2] Status (0x00 = OK)
  /// [3] Length (N)
  /// [4 .. 3+N] Data Payload (if any)
  /// [4+N] Checksum High
  /// [5+N] Checksum Low
  /// [6+N] 0x77 (End)
  ///
  /// Checksum in response covers bytes [2] through [3+N] (Status, Length, Data).
  /// Checksum in request covers bytes [2] and [3] (Length, Command/Data).
  static bool verifyFrame(Uint8List frame) {
    if (frame.length < 7) {
      return false;
    }
    if (frame[0] != 0xDD || frame[frame.length - 1] != 0x77) {
      return false;
    }

    final dataLength = frame[3];
    final expectedTotalLength = dataLength + 7;
    if (frame.length != expectedTotalLength) {
      return false;
    }

    // Checksum covers bytes from index 2 to index 3 + dataLength (inclusive)
    final bytesToChecksum = frame.sublist(2, 4 + dataLength);
    final calculated = calculate(bytesToChecksum);

    final actualHigh = frame[4 + dataLength];
    final actualLow = frame[5 + dataLength];
    final actualChecksum = (actualHigh << 8) | actualLow;

    return calculated == actualChecksum;
  }
}
