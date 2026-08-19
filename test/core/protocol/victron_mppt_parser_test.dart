import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:jbd_battery_monitor/core/protocol/victron/victron_crypto.dart';
import 'package:jbd_battery_monitor/core/protocol/victron/victron_mppt_data.dart';
import 'package:jbd_battery_monitor/core/protocol/victron/victron_mppt_parser.dart';

void main() {
  group('VictronMpptParser Tests', () {
    const testKeyHex = 'aabbccddeeff00112233445566778899';
    final keyBytes = VictronCrypto.parseHexKey(testKeyHex)!;

    test('parses plain decrypted payload correctly', () {
      // Byte layout:
      // [0]: State: 3 (Bulk)
      // [1]: Error: 0 (No error)
      // [2-3]: Batt V: 13.24V -> 1324 = 0x052C -> [0x2C, 0x05]
      // [4-5]: Batt I: 10.5A -> 105 = 0x0069 -> [0x69, 0x00]
      // [6-7]: Yield: 1.85 kWh = 1850 Wh -> 185 = 0x00B9 -> [0xB9, 0x00]
      // [8-9]: PV Power: 140W -> 140 = 0x008C -> [0x8C, 0x00]
      // [10-11]: Load current: 2.5A -> 25 = 0x0019 -> [0x19, 0x00]
      final decrypted = Uint8List.fromList([
        0x03, 0x00, // bulk, no error
        0x2C, 0x05, // 13.24 V
        0x69, 0x00, // 10.5 A
        0xB9, 0x00, // 185 * 10 = 1850 Wh (1.85 kWh)
        0x8C, 0x00, // 140 W
        0x19, 0x00, // 2.5 A load
      ]);

      final data = VictronMpptParser.parseDecryptedPayload(decrypted);
      expect(data, isNotNull);
      expect(data!.deviceState, equals(VictronDeviceState.bulk));
      expect(data.chargerError, equals(VictronChargerError.noError));
      expect(data.batteryVoltage, closeTo(13.24, 0.001));
      expect(data.batteryCurrent, closeTo(10.5, 0.001));
      expect(data.yieldTodayWh, closeTo(1850.0, 0.001));
      expect(data.yieldTodayKwh, closeTo(1.85, 0.001));
      expect(data.solarPower, closeTo(140.0, 0.001));
      expect(data.loadCurrent, closeTo(2.5, 0.001));
    });

    test('full end-to-end advertisement parsing and decryption', () {
      const nonce = 0x4321;
      final plainPayload = Uint8List.fromList([
        0x04, 0x00, // Absorption
        0xE8, 0x05, // 15.12 V (1512 = 0x05E8)
        0x14, 0x00, // 2.0 A (20 = 0x0014)
        0x64, 0x00, // 1000 Wh (100 = 0x0064)
        0x1E, 0x00, // 30 W (30 = 0x001E)
      ]);

      final encrypted = VictronCrypto.decryptPayload(
        key: keyBytes,
        nonce: nonce,
        encryptedData: plainPayload,
      );

      // Build full manufacturer data
      // Byte 0: 0x10
      // Bytes 1-2: 0xA0, 0x02 (Model ID e.g. 0x02A0)
      // Byte 3: 0x01 (Readout type)
      // Byte 4: 0x01 (Record type Solar Charger)
      // Bytes 5-6: Nonce LE -> 0x21, 0x43
      // Byte 7: key check byte -> keyBytes[0] = 0xAA
      // Bytes 8+: Encrypted payload
      final rawAdv = <int>[
        0x10,
        0xA0,
        0x02,
        0x01,
        0x01,
        0x21,
        0x43,
        0xAA,
        ...encrypted,
      ];

      final manufacturerData = {0x02E1: rawAdv};

      expect(
        VictronMpptParser.isVictronSolarChargerAdv(manufacturerData),
        isTrue,
      );

      final result = VictronMpptParser.parseAdvertisement(
        manufacturerData: manufacturerData,
        encryptionKeyHex: testKeyHex,
      );

      expect(result, isNotNull);
      expect(result!.deviceState, equals(VictronDeviceState.absorption));
      expect(result.batteryVoltage, closeTo(15.12, 0.001));
      expect(result.batteryCurrent, closeTo(2.0, 0.001));
      expect(result.yieldTodayWh, closeTo(1000.0, 0.001));
      expect(result.solarPower, closeTo(30.0, 0.001));
    });

    test('rejects advertisement if key check byte does not match', () {
      const wrongKeyHex = '11223344556677889900112233445566'; // first byte 0x11
      final rawAdv = <int>[
        0x10, 0xA0, 0x02, 0x01, 0x01, 0x21, 0x43,
        0xAA, // Key check is 0xAA != 0x11
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x10,
      ];

      final result = VictronMpptParser.parseAdvertisement(
        manufacturerData: {0x02E1: rawAdv},
        encryptionKeyHex: wrongKeyHex,
      );

      expect(result, isNull);
    });

    test('rejects non-solar record types or truncated advertisements', () {
      // Record type 0x02 (Battery monitor, not solar charger)
      final nonSolarAdv = <int>[
        0x10,
        0xA0,
        0x02,
        0x01,
        0x02,
        0x21,
        0x43,
        0xAA,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
      ];
      expect(
        VictronMpptParser.isVictronSolarChargerAdv({0x02E1: nonSolarAdv}),
        isFalse,
      );

      final result = VictronMpptParser.parseAdvertisement(
        manufacturerData: {0x02E1: nonSolarAdv},
        encryptionKeyHex: testKeyHex,
      );
      expect(result, isNull);
    });
  });
}
