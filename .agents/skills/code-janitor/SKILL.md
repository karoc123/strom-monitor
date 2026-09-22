---
name: code-janitor
description: Use if the user requests full code cleanliness, pre-commit checks, or before completing a change.
---

# Code Janitor

Before you finish a change — and any time you want confidence the codebase is
clean — run the janitor's rounds. Each step catches a different class of
problem; do not skip any. Run everything from the repository root and fix every failure
before moving on.

## The sweep (in order)

1. **Format check** — `dart format --output=none --set-exit-if-changed .` (auto-format with `dart format .`)
2. **Lint & Static Analysis** — `flutter analyze` (strictly zero warnings or errors per AGENTS.md)
3. **Automated Tests** — `flutter test`
4. **Clean & Cache Reset** — `flutter clean && flutter pub get` (build reset and dependency synchronization)

Fix failures at the step that surfaced them, then re-run that step and let the
rest of the sweep continue. If a step is irrelevant to your change (e.g. documentation-only changes), you may note it and skip, but never silently drop formatting, static analysis, or automated tests on code modifications.

---

## Step details

### 1. Format (Dart Format)

Verifies Dart code style formatting across `lib/`, `test/`, and tooling scripts according to standard Dart formatting conventions.

```bash
# Verify formatting (fails with non-zero exit code if files need formatting)
dart format --output=none --set-exit-if-changed .

# Auto-format all files in place
dart format .
```

Key conventions enforced:
- Default 80-character line length limit.
- Trailing commas on multiline argument lists, parameter lists, and widget trees to ensure clean diffs and proper indentation.

### 2. Lint & Static Analysis (Flutter Analyze)

Runs Flutter static analysis against rules configured in `analysis_options.yaml` (including `package:flutter_lints/flutter.yaml`).

```bash
flutter analyze
```

Repository rule (`AGENTS.md`):
- All code must strictly pass with **zero warnings and zero errors**.
- Do not suppress linter errors with `// ignore:` comments unless explicitly authorized.

Common fixes:
- **Unused imports or variables:** Remove unused imports or prefix unused parameters with `_`.
- **Prefer single quotes:** Follow standard Dart quote conventions.
- **Null safety:** Strictly handle nullable types without unsafe force-unwraps (`!`) where null is possible.
- **Const constructors:** Prefer `const` constructors for immutable widgets and data structures.

### 3. Automated Tests (Flutter Test)

Executes the automated unit and widget test suites in `test/`.

```bash
# Run all test suites
flutter test

# Run a specific test file
flutter test test/core/protocol/jbd_frame_builder_test.dart

# Run tests matching a specific description
flutter test --name "parses basic info payload"
```

Scope of covered components:
- Protocol framing and reassembly (`JbdFrameBuilder`, `JbdFrameReassembler`).
- Byte parsing and checksum calculations (`JbdTelemetryParser`, `VictronMpptParser`, `VictronCrypto`).
- Database and persistence (`AppDatabase`, `ReadingDao`, SQLite migrations).
- Telemetry processing and downsampling (`Downsampler`, aggregators).
- State management and UI widgets (`HistoryChart`, Riverpod state notifiers).

### 4. Clean & Cache Reset (Flutter Clean & Pub Get)

Removes build artifacts, generated assets, and `.dart_tool` cache, then restores packages.

```bash
flutter clean && flutter pub get
```

Run this step when:
- Encountering unusual analyzer cache desynchronization.
- Build artifacts in `build/` consume excessive disk space or cause stale linkage.
- Preparing for a clean release or tag.

---

## Hardware-in-the-Loop Testing Notice

As mandated by `AGENTS.md`:
> Prompt the user to perform live testing with their physical Android device and actual JBD LiFePO4 battery whenever Bluetooth (`flutter_blue_plus`), background execution (`workmanager`), or timing-critical logic is modified.

Provide clear, step-by-step verification instructions to the user whenever changes touch:
1. Bluetooth Low Energy scanning, GATT service discovery, or characteristic subscriptions.
2. JBD BMS frame request/response communication.
3. Victron MPPT advertisement decryption and parsing.
4. Background sync worker execution and power management.
