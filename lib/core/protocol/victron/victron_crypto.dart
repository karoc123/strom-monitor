import 'dart:typed_data';
import 'package:pointycastle/export.dart';

/// Cryptographic helper for Victron BLE Instant Readout payloads.
class VictronCrypto {
  /// Decrypts Victron Instant Readout payload using AES-128-CTR mode.
  ///
  /// [key]: 16-byte AES encryption key.
  /// [nonce]: 16-bit uint counter from bytes [5-6] of manufacturer data.
  /// [encryptedData]: The encrypted payload bytes.
  static Uint8List decryptPayload({
    required Uint8List key,
    required int nonce,
    required Uint8List encryptedData,
  }) {
    if (key.length != 16) {
      throw ArgumentError('Victron encryption key must be exactly 16 bytes.');
    }
    if (encryptedData.isEmpty) {
      return Uint8List(0);
    }

    // Victron AES-128-CTR IV:
    // 16 bytes: [nonce & 0xFF, (nonce >> 8) & 0xFF, 0, 0, ..., 0]
    final iv = Uint8List(16);
    iv[0] = nonce & 0xFF;
    iv[1] = (nonce >> 8) & 0xFF;

    final cipher = CTRStreamCipher(AESEngine());
    final params = ParametersWithIV<KeyParameter>(KeyParameter(key), iv);
    cipher.init(false, params);

    return cipher.process(encryptedData);
  }

  /// Parses a 32-character hex key string to a 16-byte [Uint8List].
  /// Returns `null` if invalid length or non-hex characters.
  static Uint8List? parseHexKey(String hex) {
    final cleaned = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (cleaned.length != 32) return null;

    final bytes = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      final byteHex = cleaned.substring(i * 2, i * 2 + 2);
      final byteVal = int.tryParse(byteHex, radix: 16);
      if (byteVal == null) return null;
      bytes[i] = byteVal;
    }
    return bytes;
  }
}
