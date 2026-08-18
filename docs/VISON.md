# VISION.md: JBD LiFePO4 Battery Monitor (Android)

## 1. Executive Summary
An open-source, lightweight Android application built with Flutter to monitor, record, and visualize battery telemetry from JBD (Xiaoxiang/Liontron) LiFePO4 Battery Management Systems (BMS) over Bluetooth Low Energy (BLE).

The application balances real-time diagnostic visibility during active use with energy-efficient, OS-friendly background telemetry logging and historical time-series analytics.

---

## 2. Core Architecture & Technology Stack

| Layer | Technology / Package | Rationale |
| :--- | :--- | :--- |
| **Framework** | Flutter (Dart) | Android-first native compilation, performant reactive UI rendering. |
| **BLE Communication** | `flutter_blue_plus` | Mature BLE GATT handling, MTU negotiation, and notification streaming. |
| **Background Processing** | `workmanager` (Android WorkManager) | Battery-conscious, non-exact background task scheduling aligned with Android OS Doze-mode standards. |
| **Persistence** | SQLite (`sqflite` or `drift`) | Local, indexed relational storage with high write performance and zero external dependencies. |
| **Data Visualization** | `fl_chart` | Interactive, pannable, and zoomable line/area charts. |
| **State Management** | Riverpod / BLoC | Decoupled background service streams and UI state bindings. |

---

## 3. Functional Requirements

### 3.1. Live Dashboard (Foreground Mode)
* **Polling Rate:** 1.0 – 2.0 second intervals via active GATT notifications.
* **Metrics Displayed:**
  * State of Charge (SoC) in `%` (primary gauge/card).
  * Pack Total Voltage (`V`), Current Draw/Charge (`A`), and calculated Power ($P = U \cdot I$ in `W`).
  * Operational status (Charging / Discharging / Standby).
* **Write Throttling:** While in foreground mode, live data updates the UI at 1 Hz, but is committed to SQLite only once every designated period (e.g., once every 60 seconds) or when a significant telemetry delta occurs to prevent database bloat.

### 3.2. Background Telemetry Collector
* **Execution Paradigm:** Managed periodic jobs using Android `WorkManager` (configurable interval: 15 min, 30 min, 60 min, 120 min).
* **Lifecycle:**
  1. Trigger worker task.
  2. Scan and connect to target BMS by stored MAC address/Name.
  3. Send request frame `0x03` (and optionally `0x04`).
  4. Receive response frame, validate checksum, parse telemetry.
  5. Write single record into SQLite database.
  6. Disconnect GATT client and yield execution.
* **Fault Handling (Out of Range):** If connection fails within a strict 10-second timeout, the attempt is aborted silently without aggressive retries until the next system-scheduled interval.

### 3.3. Historical Charts & Analytics
* **Time Windows:** 24 Hours, 7 Days, 30 Days, Custom / All-Time.
* **Chart Types:**
  * SoC over time (`%`).
  * Current over time (`A` / charge vs. discharge).
  * Total Voltage over time (`V`).
* **Interactivity:** Horizontal panning, pinch-to-zoom, and tooltip readouts on specific data points.
* **Downsampling:** Dynamic bucket aggregation (averaging/LTTB downsampling) when querying wide time spans to maintain UI fluidity.

### 3.4. Data Management & Portability
* **Export:** Full export of historical readings to JSON and CSV formats via the Android Storage Access Framework (SAF).
* **Import:** Restore database from backup JSON/CSV files with duplicate-timestamp conflict resolution (`INSERT OR IGNORE`).
* **Pruning:** Options to purge data older than 30, 90, or 365 days.

### 3.5. Settings & System Management
* **Target Pairing:** Bluetooth discovery sheet with RSSI indicator; selection and persistence of target BMS MAC address.
* **Interval Configuration:** Background polling rate selection.
* **Licensing & Legal:** Embedded GNU General Public License v3 (GPL-3.0) text and source code attribution.

---

## 4. SQLite Database Schema

```sql
CREATE TABLE readings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp INTEGER NOT NULL,            -- Unix epoch in milliseconds (Indexed)
    soc INTEGER NOT NULL,                  -- State of Charge (0-100)
    voltage REAL NOT NULL,                 -- Total pack voltage in Volts (e.g. 13.24)
    current REAL NOT NULL,                 -- Current in Amperes (Negative = discharge, Positive = charge)
    power REAL NOT NULL,                   -- Calculated: voltage * current (Watts)
    
    -- Extensible Telemetry Fields (Nullable for V1)
    cell_voltage_1 REAL,                   -- Millivolts converted to Volts
    cell_voltage_2 REAL,
    cell_voltage_3 REAL,
    cell_voltage_4 REAL,
    temp_bms REAL,                         -- Temperature in Celsius
    temp_cells REAL,                       -- Temperature in Celsius
    cycles INTEGER                         -- Lifetime charge cycles
);

CREATE INDEX idx_readings_timestamp ON readings(timestamp);

```

---

## 5. Android Permissions & OS Integration

```xml
<!-- Manifest Permissions for Android 12+ (API 31+) -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" 
                 android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

<!-- Legacy BLE Fallback for Android 10/11 (API 29-30) -->
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />

<!-- Background Scheduling -->
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

```

---

## 6. Implementation Roadmap


├── Milestone 1: Core BLE & Decoding Engine
│   ├── JBD Protocol frame builder & response parser
│   ├── BLE Connection Manager (scan, pair, subscribe to 0xFF01, write 0xFF02)
│   └── Verification against hardware
│
├── Milestone 2: Persistence & Foreground Dashboard
│   ├── SQLite schema definition & Data Access Object (DAO) layer
│   ├── Real-time dashboard view with 1-2s polling
│   └── Throttled database writer (foreground mode)
│
├── Milestone 3: Background Worker Integration
│   ├── Android WorkManager periodic worker implementation
│   ├── Timeout & disconnected-state resilience handling
│   └── System reboot receiver (Auto-start worker)
│
├── Milestone 4: Analytics, Charts & Data Portability
│   ├── fl_chart implementation (zoom, pan, time filters)
│   ├── Database query downsampling layer
│   └── CSV/JSON export and import engines
│
└── Milestone 5: Settings, Polishing & GPL Compliance
    ├── Configurable background intervals
    ├── Storage pruning tools
    └── GPLv3 legal view and release packaging