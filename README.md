# Ström Monitor

<p align="center">
  <img src="assets/icon/icon.png" alt="Ström Monitor App Icon" width="128" height="128" />
</p>

<p align="center">
  <strong>Modern BLE telemetry & battery monitor for JBD LiFePO4 Battery Management Systems.</strong><br>
  <code>de.karoc.strommonitor</code>
</p>

<p align="center">
  <a href="https://www.gnu.org/licenses/gpl-3.0"><img src="https://img.shields.io/badge/License-GPLv3-blue.svg" alt="License: GPL v3"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.41.7-02569B?logo=flutter" alt="Flutter"></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.11.5-0175C2?logo=dart" alt="Dart"></a>
  <a href="https://developer.android.com"><img src="https://img.shields.io/badge/Android-API%2029%2B-3DDC84?logo=android" alt="Android"></a>
</p>

An open-source, lightweight, and battery-conscious Android application built with **Flutter** to monitor, record, and visualize telemetry from **JBD (Xiaoxiang / Liontron)** LiFePO4 Battery Management Systems (BMS) over **Bluetooth Low Energy (BLE)**.

---

## ⚡ Features

* **Real-time Live Telemetry:**
  * Interactive State of Charge (SoC %) arc gauge with dynamic color indicators (Charging, Discharging, Standby).
  * High-precision readouts: Total Pack Voltage ($V$), Current Draw/Charge ($A$), Power ($W = U \cdot I$), and Remaining vs. Nominal Capacity ($Ah$).
  * 4S Individual Cell Voltage breakdown with delta ($\Delta V$) imbalance warning in millivolts.
  * Thermal monitoring (BMS NTC sensor and Battery Cell temperature) and lifetime charge cycle counter.
  * Throttled SQLite persistence during live view to minimize database storage overhead.

* **Energy-Efficient Background Telemetry Collector:**
  * Android `WorkManager` periodic headless worker (15 min, 30 min, 60 min, 120 min intervals).
  * Strict 10-second timeout guard: silent and clean abort when out of range to prevent wake-lock battery drain.
  * Survives device reboots (`RECEIVE_BOOT_COMPLETED`).

* **Historical Analytics & Interactive Charts:**
  * Interactive charts powered by `fl_chart` with touch tooltips, panning, and time filtering (24 Hours, 7 Days, 30 Days, All Time).
  * Dynamic bucket-averaging downsampling for instant chart rendering even with thousands of historical data points.
  * Summary cards displaying Minimum, Average, and Maximum metrics.

* **Data Management & Full Portability:**
  * **Export:** Export complete time-series database to standardized **CSV** or structured **JSON** via Android Share.
  * **Import:** Restore backups with automatic duplicate-timestamp resolution (`INSERT OR IGNORE`).
  * **Pruning:** Built-in storage maintenance tools to purge data older than 30, 90, or 365 days.

* **100% Offline & Privacy First:** Zero external telemetry, zero tracking, zero cloud dependencies.

---

## 🏛️ Clean Architecture

The codebase strictly adheres to Clean Architecture with clear boundaries between Data, Domain, and Presentation layers:

```
lib/
├── main.dart                       # Entrypoint, WorkManager initialization, Riverpod Scope
├── app.dart                        # MaterialApp, Material 3 Theme, Navigation Shell
├── core/
│   ├── ble/                        # BLE Client, GATT notification handling, connection state machine
│   │   ├── ble_client.dart
│   │   ├── ble_connection_state.dart
│   │   └── ble_device_info.dart
│   ├── database/                   # SQLite Manager, Migrations, DAO
│   │   ├── app_database.dart
│   │   ├── reading_dao.dart
│   │   └── models/
│   │       └── battery_reading.dart
│   ├── protocol/                   # JBD Checksum, Command Registers, Framing & Telemetry Parser
│   │   ├── jbd_checksum.dart
│   │   ├── jbd_command.dart
│   │   ├── jbd_frame_builder.dart
│   │   ├── jbd_frame_reassembler.dart
│   │   └── jbd_telemetry_parser.dart
│   └── providers/                  # Core Riverpod providers (BLE, Database, Settings)
└── features/
    ├── background/                 # Headless Android WorkManager task handler
    │   ├── background_task_handler.dart
    │   └── background_service_manager.dart
    ├── dashboard/                  # Live Telemetry Gauge & Diagnostics
    │   ├── data/telemetry_recorder.dart
    │   └── presentation/
    ├── history/                    # Time-Series Charts & Data Portability
    │   ├── data/
    │   │   ├── data_exporter.dart
    │   │   └── downsampler.dart
    │   └── presentation/
    └── settings/                   # BLE Scanner & Pairing, Intervals, Pruning, GPL View
        ├── data/settings_repository.dart
        ├── domain/app_settings.dart
        └── presentation/
```

---

## 📡 JBD Protocol Specification

| Characteristic / Register | UUID / Hex | Description |
| :--- | :--- | :--- |
| **GATT Service** | `0000ff00-0000-1000-8000-00805f9b34fb` | JBD / Xiaoxiang Primary BLE Service |
| **Notify Characteristic** | `0000ff01-0000-1000-8000-00805f9b34fb` | Stream notifications for response frames |
| **Write Characteristic** | `0000ff02-0000-1000-8000-00805f9b34fb` | Command write endpoint (`withoutResponse`) |
| **Read Basic Info** | `0x03` | `[0xDD, 0xA5, 0x03, 0x00, 0xFF, 0xFD, 0x77]` |
| **Read Cell Voltages** | `0x04` | `[0xDD, 0xA5, 0x04, 0x00, 0xFF, 0xFC, 0x77]` |

**Checksum Formula:**
$$\text{Checksum} = (0x10000 - \sum \text{DataBytes}) \pmod{0x10000}$$

---

## 🛠️ Prerequisites & Setup

* **Flutter SDK:** $\ge 3.24.0$ (Dart $\ge 3.5.0$)
* **Android SDK:** API 29+ (Target API 34+ / Android 14)
* **Android NDK:** Standard Flutter NDK bundle

### Required Android Permissions (Configured in Manifest):
* `BLUETOOTH_SCAN` (`usesPermissionFlags="neverForLocation"`)
* `BLUETOOTH_CONNECT`
* `BLUETOOTH` & `BLUETOOTH_ADMIN` (Legacy Android 10/11)
* `ACCESS_FINE_LOCATION` (Legacy Android 10/11)
* `WAKE_LOCK` & `RECEIVE_BOOT_COMPLETED` (WorkManager scheduling)

---

## 🚀 Build Instructions

### 1. Clone & Fetch Dependencies
```bash
git clone https://github.com/karoc/jbd-battery-monitor.git
cd jbd-battery-monitor
flutter pub get
```

### 2. Run Static Analysis & Tests
```bash
# Verify formatting
dart format --output=none --set-exit-if-changed .

# Static analysis (zero warnings / zero errors)
flutter analyze

# Execute all automated unit tests
flutter test
```

### 3. Build APK
```bash
# Build Debug APK
flutter build apk --debug

# Build Release APK
flutter build apk --release
```
The compiled APK will be located at `build/app/outputs/flutter-apk/app-release.apk`.

---

## 🔋 Hardware-in-the-Loop Testing

To test with a physical Android device and an actual JBD LiFePO4 BMS:

1. Connect your Android smartphone via USB with USB-Debugging enabled.
2. Verify device connection: `flutter devices`.
3. Launch the app: `flutter run -d <device-id>`.
4. Grant the required Bluetooth permissions on your phone.
5. In the app, navigate to **Settings** $\to$ **Target Battery BMS** $\to$ **Pair**.
6. Select your JBD BMS from the list.
7. Return to **Dashboard** to see live 1 Hz telemetry updates.
8. Set the background interval in **Settings** to 15 min, minimize the app, and observe scheduled logs in `adb logcat | grep -i workmanager`.

---

## 📄 License

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)**. See the [LICENSE](LICENSE) file for details.
