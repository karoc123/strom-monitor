---
name: dependency-audit
description: Use when checking, auditing, aligning, updating, or reviewing dependencies in pubspec.yaml and pubspec.lock.
---

# Dependency Audit & Management

Use this skill to systematically inspect, align, audit, and remediate dependencies for the Flutter/Dart codebase. It enforces repository policies, verifies lockfile synchronization, detects phantom and unused dependencies, and ensures safe upgrades without breaking platform or API compatibility.

Run all commands from the repository root.

---

## The Audit Protocol (Step-by-Step)

### Step 1: Policy & Consistency Check

Run the automated Flutter/Dart dependency checker:

```bash
dart run .agents/skills/dependency-audit/scripts/check_deps.dart
```

This automated script checks:

1. **Version Specifier Validity**: Verifies valid version constraints in `pubspec.yaml` (standard caret `^x.y.z` allowed; flags loose wildcards like `*` or `any`).
2. **Phantom Dependencies**: Scans `lib/` and `test/` for package imports (`package:<name>/...`) that are not declared in `pubspec.yaml`.
3. **Dev-Dependency Leakage**: Confirms that dependencies declared under `dev_dependencies` (e.g. `flutter_test`) are never imported inside production code (`lib/`).
4. **Unused Direct Dependencies**: Detects declared runtime dependencies that are never imported in application code or tests (excluding framework defaults like `cupertino_icons`).
5. **Lockfile Synchronization**: Validates that all declared direct dependencies are properly recorded in `pubspec.lock`.

Fix any `[FAIL]` or `[WARN]` outputs surfaced in this step before proceeding.

---

### Step 2: Outdated & Drift Analysis

Check available upstream package versions across all dependencies:

```bash
flutter pub outdated
```

Key columns to evaluate:
- **Current**: Version currently resolved in `pubspec.lock`.
- **Upgradable**: Highest version matching the constraint in `pubspec.yaml`.
- **Resolvable**: Highest version resolvable without constraint conflicts or breaking other packages.
- **Latest**: Newest version published on `pub.dev`.

Categorize findings:
- **Patch/Minor updates** (Current -> Upgradable): Generally backward-compatible. Verify release notes.
- **Major updates** (Current -> Latest): Potential breaking API changes, Android SDK requirement bumps, or migration overhead. Requires API review and full test suite validation.

---

### Step 3: Dependency Graph & Conflict Inspection

Inspect the dependency tree to examine transitive relationships and resolve version constraints:

```bash
flutter pub deps
```

Identify:
- Shared transitive packages (e.g., `sqlite3`, `intl`, `crypto`).
- Potential diamond dependency constraints between direct packages.

---

### Step 4: Upgrading & Lockfile Synchronization

When updating dependencies:

1. **Safe Patch & Minor Upgrades**:
   ```bash
   flutter pub upgrade
   ```
2. **Targeted Major Upgrade**:
   Rather than upgrading all packages indiscriminately, upgrade specific packages individually in `pubspec.yaml`:
   ```bash
   flutter pub upgrade <package_name>
   # or manually adjust the version in pubspec.yaml and run:
   flutter pub get
   ```
3. **Inspect Lockfile Changes**:
   Always review the exact transitive changes:
   ```bash
   git diff pubspec.lock
   ```

---

### Step 5: Full Verification Sweep

Run the full verification suite to guarantee changes introduced zero regressions:

```bash
# 1. Format check
dart format --output=none --set-exit-if-changed .

# 2. Static analysis (zero issues required)
flutter analyze

# 3. Automated tests
flutter test

# 4. Dependency check rerun
dart run .agents/skills/dependency-audit/scripts/check_deps.dart
```

---

### Step 6: Audit & Migration Report (Mandatory Output)

Always present a structured report to the user at the conclusion of the audit:

1. **Status of Baseline Checks**: Confirmation that all dependency policies pass, no phantom dependencies exist, no dev-dependencies leak into `lib/`, and all tests/analysis pass.
2. **Major Upgrades Requiring Adaptations**: Explicitly list all available major version jumps (from `flutter pub outdated`), detailing:
   - Package name and version jump (e.g. `flutter_riverpod 2.6.1 -> 3.4.3`, `file_picker 12.0.0 -> 13.1.0`).
   - Breaking API changes and affected files/modules.
   - Native platform constraints (e.g. Android `minSdkVersion`, Gradle, Kotlin version requirements).
3. **User Decision Prompt**: Ask the user explicitly which of the identified major upgrades should be migrated, proposing an isolated, step-by-step approach with separate commits.

---

## Stolpersteine (Known Traps & Pitfalls)

### Stolperstein 1: Major Version Breaking Changes in Flutter Plugins

- **Problem**: Running `flutter pub upgrade --major-versions` indiscriminately modifies `pubspec.yaml` across all dependencies simultaneously (e.g. bumping `flutter_riverpod` from 2.x to 3.x, `pointycastle` from 3.x to 4.x), introducing massive breaking changes across state management, crypto, and UI layers.
- **Solution**: Never run `flutter pub upgrade --major-versions` across all packages at once. Upgrade one major dependency at a time, review changelogs, adapt calling code, and verify with `flutter analyze` and `flutter test`.

### Stolperstein 2: Native Android SDK & Gradle Incompatibilities

- **Problem**: Plugins interacting with native Android hardware/APIs (`flutter_blue_plus`, `workmanager`, `sqflite`) often raise minimum Android SDK versions (`minSdkVersion`, `compileSdkVersion`), Java version requirements (e.g. Java 17), or Gradle/AGP requirements in major releases.
- **Solution**: Inspect plugin changelogs and `android/app/build.gradle` before updating BLE or background execution plugins. Verify Android builds locally (`flutter build apk --debug`).

### Stolperstein 3: Dev-Dependency Leakage in Production Code

- **Problem**: Importing testing utilities (such as `flutter_test` or `matcher`) in `lib/` files may appear to work during local development or unit testing, but can fail unexpectedly during release compilation or app bundling.
- **Solution**: Always run `check_deps.dart`. Keep `flutter_test` restricted exclusively to files within `test/`.

### Stolperstein 4: Lockfile Drift and Team Inconsistencies

- **Problem**: Omitting `pubspec.lock` or allowing unexpected transitive updates between developers or CI runners causes "works on my machine" failures.
- **Solution**: Always commit `pubspec.lock`. When testing dependencies, run `git diff pubspec.lock` to inspect exact version movements.

### Stolperstein 5: Caret Semver Auto-Resolving Breaking Transitive Updates

- **Problem**: Because `pubspec.yaml` uses caret syntax (e.g. `^2.3.12`), running `flutter pub upgrade` can pull in a new minor/patch release of a transitive dependency that has a bug or incompatibility.
- **Solution**: If a newly resolved transitive dependency causes issues, lock it temporarily using `dependency_overrides:` in `pubspec.yaml`, document the reason, and file an issue upstream.
