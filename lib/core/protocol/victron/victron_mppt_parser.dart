import 'dart:typed_data';
import 'victron_crypto.dart';
import 'victron_mppt_data.dart';

/// Parser for Victron SmartSolar MPPT BLE Instant Readout advertisements.
class VictronMpptParser {
  static const int victronManufacturerId = 0x02E1; // 737
  static const int prefixByte = 0x10;
  static const int recordTypeSolarCharger = 0x01;

  /// Checks if the manufacturer data contains a Victron Solar Charger advertisement.
  static bool isVictronSolarChargerAdv(Map<int, List<int>> manufacturerData) {
    final bytes = manufacturerData[victronManufacturerId];
    if (bytes == null || bytes.length < 8) return false;
    return bytes[0] == prefixByte && bytes[4] == recordTypeSolarCharger;
  }

  /// Parses and decrypts a Victron MPPT advertisement payload.
  ///
  /// [manufacturerData]: Manufacturer data map from BLE scan result.
  /// [encryptionKeyHex]: 32-character hex string (16 bytes).
  ///
  /// Returns [VictronMpptData] if valid, or `null` on decryption/validation failure.
  static VictronMpptData? parseAdvertisement({
    required Map<int, List<int>> manufacturerData,
    required String encryptionKeyHex,
    DateTime? timestamp,
  }) {
    final keyBytes = VictronCrypto.parseHexKey(encryptionKeyHex);
    if (keyBytes == null) return null;

    final rawBytes = manufacturerData[victronManufacturerId];
    if (rawBytes == null || rawBytes.length < 18) {
      // Need at least 8 header bytes + 10 decrypted payload bytes
      return null;
    }

    // Check prefix
    if (rawBytes[0] != prefixByte) return null;

    // Check record type (0x01 = Solar Charger)
    if (rawBytes[4] != recordTypeSolarCharger) return null;

    // Validate key check byte (Byte 7 must equal keyBytes[0])
    final keyCheckByte = rawBytes[7];
    if (keyCheckByte != keyBytes[0]) {
      return null;
    }

    // Nonce (Bytes 5-6, little-endian)
    final nonce = rawBytes[5] | (rawBytes[6] << 8);

    // Encrypted payload starts at Byte 8
    final encryptedPayload = Uint8List.fromList(rawBytes.sublist(8));

    try {
      final decrypted = VictronCrypto.decryptPayload(
        key: keyBytes,
        nonce: nonce,
        encryptedData: encryptedPayload,
      );

      return parseDecryptedPayload(decrypted, timestamp: timestamp);
    } catch (_) {
      return null;
    }
  }

  /// Parses the decrypted binary payload into a [VictronMpptData] entity.
  static VictronMpptData? parseDecryptedPayload(
    Uint8List decrypted, {
    DateTime? timestamp,
  }) {
    if (decrypted.length < 10) {
      return null;
    }

    final byteData = ByteData.sublistView(decrypted);

    final rawState = decrypted[0];
    final rawError = decrypted[1];

    final deviceState = VictronDeviceState.fromCode(rawState);
    final chargerError = VictronChargerError.fromCode(rawError);

    // Battery voltage: int16 LE, scale: 0.01V
    final rawBattV = byteData.getInt16(2, Endian.little);
    final batteryVoltage = rawBattV == 0x7FFF ? 0.0 : rawBattV * 0.01;

    // Battery current: int16 LE, scale: 0.1A
    final rawBattI = byteData.getInt16(4, Endian.little);
    final batteryCurrent = rawBattI == 0x7FFF ? 0.0 : rawBattI * 0.1;

    // Yield today: uint16 LE, scale: 0.01 kWh = 10 Wh
    final rawYield = byteData.getUint16(6, Endian.little);
    final yieldTodayWh = rawYield == 0xFFFF ? 0.0 : rawYield * 10.0;

    // PV / Solar power: uint16 LE, scale: 1W
    final rawPvPower = byteData.getUint16(8, Endian.little);
    final solarPower = rawPvPower == 0xFFFF ? 0.0 : rawPvPower.toDouble();

    // Load current: optional 9-bit or uint16 LE, scale: 0.1A
    double? loadCurrent;
    if (decrypted.length >= 12) {
      final rawLoad = decrypted[10] | ((decrypted[11] & 0x01) << 8);
      if (rawLoad != 0x1FF) {
        loadCurrent = rawLoad * 0.1;
      }
    }

    return VictronMpptData(
      deviceState: deviceState,
      chargerError: chargerError,
      batteryVoltage: batteryVoltage,
      batteryCurrent: batteryCurrent,
      solarPower: solarPower,
      yieldTodayWh: yieldTodayWh,
      loadCurrent: loadCurrent,
      timestamp: timestamp ?? DateTime.now(),
      rawState: rawState,
      rawError: rawError,
    );
  }
}
