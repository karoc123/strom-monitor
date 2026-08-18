import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:jbd_battery_monitor/core/protocol/jbd_checksum.dart';

void main() {
  group('JbdChecksum', () {
    test('computes correct checksum for 0x03 read command (empty data)', () {
      // Command 0x03, Length 0x00 -> sum = 3 -> 0x10000 - 3 = 0xFFFD
      final data = Uint8List.fromList([0x03, 0x00]);
      final checksum = JbdChecksum.calculate(data);
      expect(checksum, equals(0xFFFD));
      expect(JbdChecksum.calculateBytes(data), equals([0xFF, 0xFD]));
    });

    test('computes correct checksum for 0x04 read command (empty data)', () {
      // Command 0x04, Length 0x00 -> sum = 4 -> 0x10000 - 4 = 0xFFFC
      final data = Uint8List.fromList([0x04, 0x00]);
      final checksum = JbdChecksum.calculate(data);
      expect(checksum, equals(0xFFFC));
      expect(JbdChecksum.calculateBytes(data), equals([0xFF, 0xFC]));
    });

    test('validates full valid frame with checksum and stop byte', () {
      final validFrame = Uint8List.fromList([
        0xDD,
        0xA5,
        0x03,
        0x00,
        0xFF,
        0xFD,
        0x77,
      ]);
      expect(JbdChecksum.verifyFrame(validFrame), isTrue);
    });

    test('rejects frame with invalid checksum', () {
      final corruptedFrame = Uint8List.fromList([
        0xDD,
        0xA5,
        0x03,
        0x00,
        0xFF,
        0x00,
        0x77,
      ]);
      expect(JbdChecksum.verifyFrame(corruptedFrame), isFalse);
    });

    test('rejects frame without start/stop bytes or too short', () {
      expect(JbdChecksum.verifyFrame(Uint8List(3)), isFalse);
      expect(
        JbdChecksum.verifyFrame(
          Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),
        ),
        isFalse,
      );
    });
  });
}
