import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jbd_battery_monitor/core/protocol/victron/victron_crypto.dart';

void main() {
  group('VictronCrypto Tests', () {
    test('parses valid 32-character hex key correctly', () {
      const hex = '0123456789abcdef0123456789abcdef';
      final bytes = VictronCrypto.parseHexKey(hex);
      expect(bytes, isNotNull);
      expect(bytes!.length, 16);
      expect(bytes[0], 0x01);
      expect(bytes[1], 0x23);
      expect(bytes[15], 0xEF);
    });

    test('parses hex key with whitespace or colons', () {
      const hex = '01:23:45:67:89:ab:cd:ef: 01 23 45 67 89 ab cd ef';
      final bytes = VictronCrypto.parseHexKey(hex);
      expect(bytes, isNotNull);
      expect(bytes!.length, 16);
    });

    test('rejects invalid hex keys', () {
      expect(VictronCrypto.parseHexKey('too_short'), isNull);
      expect(
        VictronCrypto.parseHexKey('0123456789abcdef0123456789abcdeg'),
        isNull,
      ); // invalid char 'g'
      expect(
        VictronCrypto.parseHexKey('0123456789abcdef0123456789abcdef00'),
        isNull,
      ); // 34 chars
    });

    test('encrypts and decrypts payload symmetrically with AES-CTR', () {
      final key = Uint8List.fromList(List.generate(16, (i) => i * 3 + 1));
      const nonce = 0x1234;
      final plainData = Uint8List.fromList([
        0x03, 0x00, // State Bulk, error 0
        0x2C, 0x05, // 13.24V (1324 = 0x052C)
        0x32, 0x00, // 5.0A (50 = 0x0032)
        0x78, 0x00, // 1.20 kWh (120 = 0x0078)
        0x55, 0x00, // 85W (85 = 0x0055)
        0x00, 0x00, // load
      ]);

      // AES-CTR encrypt is identical to decrypt
      final encrypted = VictronCrypto.decryptPayload(
        key: key,
        nonce: nonce,
        encryptedData: plainData,
      );
      expect(encrypted, isNot(equals(plainData)));

      final decrypted = VictronCrypto.decryptPayload(
        key: key,
        nonce: nonce,
        encryptedData: encrypted,
      );
      expect(decrypted, equals(plainData));
    });

    test('decryptPayload handles empty encryptedData gracefully', () {
      final key = Uint8List(16);
      final result = VictronCrypto.decryptPayload(
        key: key,
        nonce: 0,
        encryptedData: Uint8List(0),
      );
      expect(result, isEmpty);
    });

    test(
      'decryptPayload throws ArgumentError if key length is not 16 bytes',
      () {
        expect(
          () => VictronCrypto.decryptPayload(
            key: Uint8List(15),
            nonce: 0,
            encryptedData: Uint8List(8),
          ),
          throwsArgumentError,
        );
        expect(
          () => VictronCrypto.decryptPayload(
            key: Uint8List(32),
            nonce: 0,
            encryptedData: Uint8List(8),
          ),
          throwsArgumentError,
        );
      },
    );

    test('AES-CTR processes multi-block streams across 16-byte boundaries', () {
      final key = Uint8List.fromList(List.generate(16, (i) => i * 7 + 3));
      const nonce = 0xABCD;
      // 48 bytes span exactly 3 full AES blocks
      final multiBlockData = Uint8List.fromList(
        List.generate(48, (i) => (i * 13) % 256),
      );

      final encrypted = VictronCrypto.decryptPayload(
        key: key,
        nonce: nonce,
        encryptedData: multiBlockData,
      );
      expect(encrypted.length, equals(48));
      expect(encrypted, isNot(equals(multiBlockData)));

      final decrypted = VictronCrypto.decryptPayload(
        key: key,
        nonce: nonce,
        encryptedData: encrypted,
      );
      expect(decrypted, equals(multiBlockData));
    });

    test('different nonces produce completely different ciphertexts', () {
      final key = Uint8List(16);
      final data = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final enc1 = VictronCrypto.decryptPayload(
        key: key,
        nonce: 100,
        encryptedData: data,
      );
      final enc2 = VictronCrypto.decryptPayload(
        key: key,
        nonce: 101,
        encryptedData: data,
      );
      expect(enc1, isNot(equals(enc2)));
    });
  });
}
