import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:jbd_battery_monitor/core/protocol/jbd_checksum.dart';
import 'package:jbd_battery_monitor/core/protocol/jbd_frame_reassembler.dart';

void main() {
  group('JbdFrameReassembler', () {
    late JbdFrameReassembler reassembler;

    setUp(() {
      reassembler = JbdFrameReassembler();
    });

    Uint8List buildMockFrame(int command, List<int> payload) {
      // frame: [0xDD, cmd, 0x00, len, ...payload, chk_hi, chk_lo, 0x77]
      final body = <int>[0x00, payload.length, ...payload];
      final chk = JbdChecksum.calculateBytes(body);
      return Uint8List.fromList([
        0xDD,
        command,
        0x00,
        payload.length,
        ...payload,
        chk[0],
        chk[1],
        0x77,
      ]);
    }

    test('reassembles single packet frame', () {
      final mock = buildMockFrame(0x04, [
        0x0D,
        0xAC,
        0x0D,
        0xB0,
      ]); // 4 bytes payload
      final frames = reassembler.processBytes(mock);
      expect(frames.length, equals(1));
      expect(frames.first.command, equals(0x04));
      expect(frames.first.payload, equals([0x0D, 0xAC, 0x0D, 0xB0]));
      expect(frames.first.status, equals(0x00));
    });

    test('reassembles fragmented frame across multiple BLE chunks', () {
      final mock = buildMockFrame(
        0x03,
        List.filled(31, 0x11),
      ); // 31 bytes payload -> 38 bytes total
      final chunk1 = mock.sublist(0, 20);
      final chunk2 = mock.sublist(20);

      final r1 = reassembler.processBytes(chunk1);
      expect(r1, isEmpty);

      final r2 = reassembler.processBytes(chunk2);
      expect(r2.length, equals(1));
      expect(r2.first.command, equals(0x03));
      expect(r2.first.payload.length, equals(31));
      expect(r2.first.payload, equals(List.filled(31, 0x11)));
    });

    test('discards garbage bytes before valid start byte 0xDD', () {
      final mock = buildMockFrame(0x04, [0x01, 0x02]);
      final withGarbage = Uint8List.fromList([0xAA, 0xBB, 0xCC, ...mock]);

      final frames = reassembler.processBytes(withGarbage);
      expect(frames.length, equals(1));
      expect(frames.first.command, equals(0x04));
      expect(frames.first.payload, equals([0x01, 0x02]));
    });

    test('recovers from invalid checksum frame and processes next frame', () {
      // Corrupt frame
      final corrupt = Uint8List.fromList([
        0xDD,
        0x04,
        0x00,
        0x02,
        0x01,
        0x02,
        0x00,
        0x00,
        0x77,
      ]);
      final valid = buildMockFrame(0x04, [0x09, 0x08]);

      final bytes = Uint8List.fromList([...corrupt, ...valid]);
      final frames = reassembler.processBytes(bytes);
      expect(frames.length, equals(1));
      expect(frames.first.payload, equals([0x09, 0x08]));
    });

    test('handles multiple complete frames in one chunk', () {
      final f1 = buildMockFrame(0x03, [0x10, 0x20]);
      final f2 = buildMockFrame(0x04, [0x30, 0x40]);

      final frames = reassembler.processBytes(
        Uint8List.fromList([...f1, ...f2]),
      );
      expect(frames.length, equals(2));
      expect(frames[0].command, equals(0x03));
      expect(frames[1].command, equals(0x04));
    });

    test('reset clears internal buffer', () {
      final mock = buildMockFrame(0x03, List.filled(31, 0x00));
      reassembler.processBytes(mock.sublist(0, 15));
      reassembler.reset();
      final frames = reassembler.processBytes(mock.sublist(15));
      expect(frames, isEmpty);
    });
  });
}
