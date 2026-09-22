import 'dart:io';

void main(List<String> args) {
  final rootDir = Directory.current;
  final pubspecFile = File('${rootDir.path}/pubspec.yaml');
  final lockFile = File('${rootDir.path}/pubspec.lock');

  if (!pubspecFile.existsSync()) {
    stderr.writeln('Error: pubspec.yaml not found in current directory.');
    exit(1);
  }

  print('=== FLUTTER/DART DEPENDENCY AUDIT CHECK ===\n');

  final pubspecContent = pubspecFile.readAsStringSync();
  final packageName = _extractPackageName(pubspecContent);
  final dependencies = _extractDependencies(pubspecContent, 'dependencies');
  final devDependencies = _extractDependencies(
    pubspecContent,
    'dev_dependencies',
  );

  var hasFailures = false;

  // 1. Dependency Version Specifier Check
  print('1. Version Specifier & Pinning Check');
  var syntaxIssues = 0;
  for (final entry in [...dependencies.entries, ...devDependencies.entries]) {
    final dep = entry.key;
    final spec = entry.value;

    if (spec.contains('*') || spec.toLowerCase() == 'any') {
      print('  [WARN] "$dep" uses unconstrained version "$spec".');
      syntaxIssues++;
    }
  }
  if (syntaxIssues == 0) {
    print('  [PASS] All dependency version specifiers are valid.');
  }

  // 2. Scan Dart source files for imports
  print('\n2. Import Analysis (Phantom & Dev-Dependency Leakage)');
  final libFiles = _findDartFiles(Directory('${rootDir.path}/lib'));
  final testFiles = _findDartFiles(Directory('${rootDir.path}/test'));

  final libImports = _collectPackageImports(libFiles);
  final testImports = _collectPackageImports(testFiles);
  final allImports = {...libImports, ...testImports};

  final allDeclared = {
    ...dependencies.keys,
    ...devDependencies.keys,
    'flutter',
    'flutter_test',
    if (packageName != null) packageName,
  };

  // Phantom dependencies
  var phantomCount = 0;
  for (final pkg in allImports) {
    if (!allDeclared.contains(pkg)) {
      print('  [FAIL] Phantom (undeclared) dependency imported: "$pkg"');
      phantomCount++;
      hasFailures = true;
    }
  }
  if (phantomCount == 0) {
    print('  [PASS] No phantom dependencies detected.');
  }

  // Dev-dependency leakage into lib/
  var devLeakCount = 0;
  for (final devDep in devDependencies.keys) {
    if (devDep == 'flutter_test' || devDep == 'flutter_lints') continue;
    if (libImports.contains(devDep)) {
      print(
        '  [FAIL] dev_dependency "$devDep" is imported in production code (lib/).',
      );
      devLeakCount++;
      hasFailures = true;
    }
  }
  if (libImports.contains('flutter_test')) {
    print(
      '  [FAIL] dev_dependency "flutter_test" is imported in production code (lib/).',
    );
    devLeakCount++;
    hasFailures = true;
  }
  if (devLeakCount == 0) {
    print('  [PASS] No dev_dependencies leaked into production code (lib/).');
  }

  // 3. Unused direct dependencies
  print('\n3. Unused Dependencies Check');
  final allowlistUnused = {
    'flutter',
    'cupertino_icons', // standard template dependency for iOS icon fallback
    'flutter_lints',
  };

  var unusedCount = 0;
  for (final dep in dependencies.keys) {
    if (allowlistUnused.contains(dep)) continue;
    if (!allImports.contains(dep)) {
      print(
        '  [INFO] "$dep" is declared in dependencies but not directly imported in lib/ or test/.',
      );
      unusedCount++;
    }
  }
  if (unusedCount == 0) {
    print('  [PASS] All declared direct dependencies are imported.');
  }

  // 4. Lockfile Synchronization Check
  print('\n4. Lockfile Check (pubspec.lock)');
  if (!lockFile.existsSync()) {
    print('  [FAIL] pubspec.lock does not exist. Run "flutter pub get".');
    hasFailures = true;
  } else {
    final lockContent = lockFile.readAsStringSync();
    var missingInLock = 0;
    for (final dep in dependencies.keys) {
      if (dep == 'flutter') continue;
      if (!lockContent.contains('  $dep:')) {
        print('  [WARN] "$dep" appears missing from pubspec.lock.');
        missingInLock++;
      }
    }
    if (missingInLock == 0) {
      print('  [PASS] pubspec.lock contains all declared direct dependencies.');
    }
  }

  print(
    '\nResult: '
    '${hasFailures ? "ISSUES DETECTED (Exit code 1)" : "ALL CHECKS PASSED"}',
  );
  if (hasFailures) {
    exit(1);
  }
}

String? _extractPackageName(String pubspecContent) {
  final match = RegExp(
    r'^name:\s*([a-zA-Z0-9_]+)',
    multiLine: true,
  ).firstMatch(pubspecContent);
  return match?.group(1);
}

Map<String, String> _extractDependencies(
  String pubspecContent,
  String sectionName,
) {
  final deps = <String, String>{};
  final lines = pubspecContent.split('\n');
  var inSection = false;

  for (final line in lines) {
    if (line.trim().startsWith('#')) continue;

    if (line.startsWith('$sectionName:')) {
      inSection = true;
      continue;
    }

    if (inSection) {
      // Check if section ended (line starts with non-whitespace)
      if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('\t')) {
        inSection = false;
        continue;
      }

      // 2-space indented direct dependency key
      final match = RegExp(r'^  ([a-zA-Z0-9_]+):\s*(.*)$').firstMatch(line);
      if (match != null) {
        final depName = match.group(1)!;
        final rawVersion = match.group(2)!.trim();
        deps[depName] = rawVersion;
      }
    }
  }

  return deps;
}

List<File> _findDartFiles(Directory dir) {
  final files = <File>[];
  if (!dir.existsSync()) return files;

  for (final entity in dir.listSync(recursive: true, followLinks: false)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      files.pushIfValid(entity);
    }
  }
  return files;
}

extension on List<File> {
  void pushIfValid(File file) {
    if (!file.path.contains('.dart_tool') && !file.path.contains('/build/')) {
      add(file);
    }
  }
}

Set<String> _collectPackageImports(List<File> files) {
  final packages = <String>{};
  final importExportRegex = RegExp(
    r"""(?:import|export)\s+['"]package:([a-zA-Z0-9_]+)/[^'"]*['"]""",
  );

  for (final file in files) {
    final content = file.readAsStringSync();
    for (final match in importExportRegex.allMatches(content)) {
      final pkg = match.group(1);
      if (pkg != null) {
        packages.add(pkg);
      }
    }
  }

  return packages;
}
