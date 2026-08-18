import 'package:flutter_test/flutter_test.dart';
import 'package:jbd_battery_monitor/core/protocol/jbd_checksum.dart';
import 'package:jbd_battery_monitor/core/protocol/jbd_frame_builder.dart';

void main() {
  group('JbdFrameBuilder', () {
    test('buildBasicInfoRequest generates exact expected bytes', () {
      final frame = JbdFrameBuilder.buildBasicInfoRequest();
      // Expect: [0xDD, 0xA5, 0x03, 0x00, 0xFF, 0xFD, 0x77]
      expect(frame, equals([0xDD, 0xA5, 0x03, 0x00, 0xFF, 0xFD, 0x77]));
      expect(JbdChecksum.verifyFrame(frame), isTrue);
    });

    test('buildCellVoltagesRequest generates exact expected bytes', () {
      final frame = JbdFrameBuilder.buildCellVoltagesRequest();
      // Expect: [0xDD, 0xA5, 0x04, 0x00, 0xFF, 0xFC, 0x77]
      expect(frame, equals([0xDD, 0xA5, 0x04, 0x00, 0xFF, 0xFC, 0x77]));
      expect(JbdChecksum.verifyFrame(frame), isTrue);
    });

    test('buildHardwareVersionRequest generates valid checksum frame', () {
      final frame = JbdFrameBuilder.buildHardwareVersionRequest();
      // Command 0x05, Length 0x00 -> sum = 5 -> 0x10000 - 5 = 0xFFFB
      expect(frame, equals([0xDD, 0xA5, 0x05, 0x00, 0xFF, 0xFB, 0x77]));
      expect(JbdChecksum.verifyFrame(frame), isTrue);
    });

    test('buildReadCommand produces valid generic read frame', () {
      final frame = JbdFrameBuilder.buildReadCommand(0x10);
      // Command 0x10, Length 0x00 -> sum = 16 -> 0x10000 - 16 = 0xFFF0
      expect(frame, equals([0xDD, 0xA5, 0x10, 0x00, 0xFF, 0xF0, 0x77]));
      expect(JbdChecksum.verifyFrame(frame), isTrue);
    });
  });
}
