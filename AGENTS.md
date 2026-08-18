# AGENTS.md

## Core Engineering Principles

* **Architecture & Clean Code:** Strictly follow KISS, DRY, SOLID, and Clean Architecture patterns. Avoid over-engineering, unnecessary dependencies, and premature abstraction.
* **Code Formatting & Linting:** 
  * All code must strictly pass static analysis via `flutter analyze` / `dart analyze` with zero warnings or errors.
  * Use standard Flutter/Dart lint rule sets (`package:flutter_lints` or stricter rules in `analysis_options.yaml`).
  * Enforce automated formatting with `dart format` (default 80-character line length, trailing commas for multiline parameter lists).
* **Zero Speculation:** Never make unverified assumptions regarding requirements, protocols, platform behaviors, or UX. Ask the user for clarification before writing code.
* **Comprehensive Testing:** Implement unit and integration tests for every testable component (protocol framing, checksum calculation, byte parsing, DAOs, data aggregation, state reducers).
* **Hardware-in-the-Loop Testing:** Prompt the user to perform live testing with their physical Android device and actual JBD LiFePO4 battery whenever Bluetooth, background execution, or timing-critical logic is modified.

---

## Agent Execution Workflow

1. **Clarification:** Verify all functional and non-functional requirements with the user before implementing changes.
2. **Design & Implementation:** Write modular, typed, and well-structured Dart/Flutter code respecting domain, data, and presentation boundaries.
3. **Static Analysis & Formatting:** Format all files using `dart format .` and verify that `flutter analyze` completes with zero issues.
4. **Automated Verification:** Provide matching automated test cases (e.g., unit tests with raw byte vectors for JBD frames).
5. **Physical Verification Instructions:** Provide clear, step-by-step verification instructions when real-device/real-BMS testing is required.