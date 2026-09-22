// ignore_for_file: depend_on_referenced_packages

import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jbd_battery_monitor/features/history/data/data_exporter.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus/share_plus.dart';

final class _FakePlatformFile extends PlatformFile {
  final String _name;
  final Uri _uri;
  final String? _path;

  _FakePlatformFile({required String name, required Uri uri, String? path})
    : _name = name,
      _uri = uri,
      _path = path;

  @override
  String get name => _name;

  @override
  Uri get uri => _uri;

  @override
  String? get path =>
      _path ?? (_uri.scheme == 'file' ? _uri.toFilePath() : null);

  @override
  XFile get xFile => XFile(_path ?? '');

  @override
  int? lengthSync() => 0;

  @override
  Future<int> length() async => 0;

  @override
  Future<Uint8List> readAsBytes() async => Uint8List(0);

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(Uint8List(0));
}

class _FakeFilePickerPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements FilePickerPlatform {
  PlatformFile? fileToReturn;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #pickFile) {
      return Future<PlatformFile?>.value(fileToReturn);
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FilePickerPlatform initialPlatform;
  late _FakeFilePickerPlatform fakePicker;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('file_picker_test_');
    initialPlatform = FilePickerPlatform.instance;
    fakePicker = _FakeFilePickerPlatform();
    FilePickerPlatform.instance = fakePicker;
  });

  tearDown(() async {
    FilePickerPlatform.instance = initialPlatform;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FilePicker & Backup Import Integration Tests', () {
    test('successfully picks CSV backup and parses battery readings', () async {
      const csvContent =
          'timestamp_ms,iso_time,soc_percent,voltage_v,current_a,power_w,cell1_v,cell2_v,cell3_v,cell4_v,temp_bms_c,temp_cells_c,cycles,solar_power_w,solar_yield_wh,solar_v,solar_a,solar_state\n'
          '1700000000000,2023-11-14T22:13:20.000,75,13.35,2.50,33.375,3.338,3.337,3.338,3.337,22.0,21.5,10,85.0,1200.0,19.5,4.3,3\n';

      final testFile = File('${tempDir.path}/test_backup.csv');
      await testFile.writeAsString(csvContent);

      fakePicker.fileToReturn = _FakePlatformFile(
        name: 'test_backup.csv',
        uri: Uri.file(testFile.path),
        path: testFile.path,
      );

      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv', 'json', 'txt'],
      );

      expect(picked, isNotNull);
      expect(picked!.path, equals(testFile.path));

      final file = File(picked.path!);
      expect(file.existsSync(), isTrue);

      final content = await file.readAsString();
      final readings = DataExporter.importFromText(content);

      expect(readings.length, equals(1));
      expect(readings.first.soc, equals(75));
      expect(readings.first.voltage, closeTo(13.35, 0.001));
      expect(readings.first.solarPower, closeTo(85.0, 0.001));
    });

    test(
      'successfully picks JSON backup and parses battery readings',
      () async {
        const jsonContent = '''
[
  {
    "timestamp": 1700000000000,
    "soc": 82,
    "voltage": 13.40,
    "current": 5.0,
    "power": 67.0,
    "solar_power": 120.0
  }
]
''';
        final testFile = File('${tempDir.path}/test_backup.json');
        await testFile.writeAsString(jsonContent);

        fakePicker.fileToReturn = _FakePlatformFile(
          name: 'test_backup.json',
          uri: Uri.file(testFile.path),
          path: testFile.path,
        );

        final picked = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['csv', 'json', 'txt'],
        );

        expect(picked, isNotNull);
        final file = File(picked!.path!);
        final readings = DataExporter.importFromText(await file.readAsString());

        expect(readings.length, equals(1));
        expect(readings.first.soc, equals(82));
        expect(readings.first.voltage, closeTo(13.40, 0.001));
        expect(readings.first.solarPower, closeTo(120.0, 0.001));
      },
    );

    test('returns null when user cancels picker dialog', () async {
      fakePicker.fileToReturn = null;

      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv', 'json', 'txt'],
      );

      expect(picked, isNull);
    });

    test('handles empty file gracefully without crashing', () async {
      final emptyFile = File('${tempDir.path}/empty.csv');
      await emptyFile.writeAsString('');

      fakePicker.fileToReturn = _FakePlatformFile(
        name: 'empty.csv',
        uri: Uri.file(emptyFile.path),
        path: emptyFile.path,
      );

      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv', 'json', 'txt'],
      );

      expect(picked, isNotNull);
      final readings = DataExporter.importFromText(
        await File(picked!.path!).readAsString(),
      );
      expect(readings, isEmpty);
    });
  });
}
