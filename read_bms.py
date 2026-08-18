import asyncio
from bleak import BleakClient, BleakScanner

DEVICE_NAME = "Faketraudel"

# JBD / Xiaoxiang Standard-GATT-Charakteristiken
WRITE_UUID = "0000ff02-0000-1000-8000-00805f9b34fb"
NOTIFY_UUID = "0000ff01-0000-1000-8000-00805f9b34fb"

# Request-Frame für Basisdaten (0x03)
REQ_BASIC_INFO = bytes([0xDD, 0xA5, 0x03, 0x00, 0xFF, 0xFD, 0x77])


class BMSReader:

    def __init__(self):
        self.buffer = bytearray()
        self.response_event = asyncio.Event()

    def notification_handler(self, sender, data: bytearray):
        self.buffer.extend(data)
        # JBD-Antwort endet immer mit 0x77
        if len(self.buffer) >= 7 and self.buffer[-1] == 0x77:
            self.response_event.set()

    def parse_payload(self) -> dict | None:
        raw = bytes(self.buffer)
        if len(raw) < 27 or raw[0] != 0xDD or raw[1] != 0x03:
            return None

        # SoC befindet sich an Byte-Index 23 (Wert 0 - 100 %)
        soc = raw[23]
        voltage_raw = (raw[4] << 8) | raw[5]
        current_raw = (raw[6] << 8) | raw[7]
        if current_raw >= 0x8000:
            current_raw -= 0x10000

        return {
            "soc_percent": soc,
            "voltage_v": voltage_raw / 100.0,
            "current_a": current_raw / 100.0,
        }


async def main():
    print(f"Suche nach BLE-Gerät '{DEVICE_NAME}'...")
    device = await BleakScanner.find_device_by_filter(
        lambda d, ad: d.name and DEVICE_NAME.lower() in d.name.lower()
    )

    if not device:
        print(f"Gerät '{DEVICE_NAME}' nicht gefunden.")
        return

    print(f"Gefunden: {device.name} [{device.address}]. Verbinde...")

    reader = BMSReader()

    async with BleakClient(device) as client:
        if not client.is_connected:
            print("Verbindung fehlgeschlagen.")
            return

        # Notifications abonnieren
        await client.start_notify(NOTIFY_UUID, reader.notification_handler)

        # Abfragebefehl senden
        await client.write_gatt_char(
            WRITE_UUID, REQ_BASIC_INFO, response=False
        )

        try:
            # Warten auf vollständige Antwort (Timeout nach 5 Sekunden)
            await asyncio.wait_for(reader.response_event.wait(), timeout=5.0)
            data = reader.parse_payload()

            if data:
                print(f"--- BMS Daten empfangen ---")
                print(f"Ladestand (SoC):  {data['soc_percent']} %")
                print(f"Gesamtspannung:   {data['voltage_v']} V")
                print(f"Aktueller Strom:  {data['current_a']} A")
            else:
                print("Fehler beim Parsen der Payload.")

        except asyncio.TimeoutError:
            print("Timeout: Keine Antwort vom BMS erhalten.")
        finally:
            await client.stop_notify(NOTIFY_UUID)


if __name__ == "__main__":
    asyncio.run(main())
