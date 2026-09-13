import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_unit_settings_editor.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';
import '../../tool/generate_settings_smoke_fixture.dart';

void main() {
  test('air stat pair differs only in intended unit settings bytes', () {
    final before = const RawChkParser()
        .parse(buildSettingsSmokeScenario(modified: false))
        .document!;
    final after = const RawChkParser()
        .parse(buildSettingsSmokeScenario(modified: true))
        .document!;
    expect(
      after.sections.map((s) => s.name),
      before.sections.map((s) => s.name),
    );
    for (var i = 0; i < before.sections.length; i++) {
      if (before.sections[i].name != 'UNIx') {
        expect(
          after.sections[i].payload,
          before.sections[i].payload,
          reason: before.sections[i].name,
        );
      }
    }
    final expected = Uint8List.fromList(
      before.sections.singleWhere((s) => s.name == 'UNIx').payload,
    );
    final data = ByteData.sublistView(expected);
    data
      ..setUint8(8, 0)
      ..setUint32(260, 61440, Endian.little)
      ..setUint8(1604, 3)
      ..setUint8(70, 0)
      ..setUint32(508, 76800, Endian.little)
      ..setUint16(1280, 200, Endian.little)
      ..setUint8(1666, 4);
    expect(
      after.sections.singleWhere((s) => s.name == 'UNIx').payload,
      expected,
    );
    final settings = const ChkUnitSettingsEditor().read(after);
    expect(settings.value(9, ChkUnitSettingField.useDefault), 1);
    expect(settings.value(42, ChkUnitSettingField.useDefault), 1);
  });

  test(
    'scenario has start positions, flying controls and no victory triggers',
    () {
      final doc = const RawChkParser()
          .parse(buildSettingsSmokeScenario(modified: false))
          .document!;
      final units = doc.sections.singleWhere((s) => s.name == 'UNIT').payload;
      final data = ByteData.sublistView(Uint8List.fromList(units));
      expect(units.length, 6 * 36);
      expect(
        [for (var i = 0; i < 6; i++) data.getUint16(i * 36 + 8, Endian.little)],
        [214, 214, 8, 70, 9, 42],
      );
      expect(
        doc.sections.singleWhere((s) => s.name == 'VCOD').payload.length,
        1040,
      );
      expect(
        doc.sections.singleWhere((s) => s.name == 'TRIG').payload,
        isEmpty,
      );
      expect(
        doc.sections.singleWhere((s) => s.name == 'UNIx').payload.take(228),
        everyElement(1),
      );
    },
  );

  final helper = Platform.environment['MAP_ARCHIVE_HELPER_PATH'];
  test(
    'native helper writes and reopens both manual settings maps',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'settings_game_smoke_',
      );
      addTearDown(() => root.delete(recursive: true));
      final source = File(
        'test/fixtures/maps/generated/minimal-self-authored.scx',
      ).absolute;
      final before = await source.readAsBytes();
      final gateway = ProcessMapArchiveGateway(helperExecutablePath: helper!);
      for (final modified in [false, true]) {
        final bytes = buildSettingsSmokeScenario(modified: modified);
        final path = '${root.path}/$modified.scx';
        final written = await gateway.writeTemporary(
          MapArchiveWriteRequest(
            operationId: 'game-$modified',
            sourcePath: source.path,
            temporaryOutputPath: path,
            scenarioChkBytes: bytes,
            timeout: const Duration(seconds: 30),
          ),
        );
        expect(written.isSuccess, isTrue, reason: '${written.diagnostics}');
        final reopened = await gateway.open(
          MapArchiveOpenRequest(
            operationId: 'reopen-$modified',
            sourcePath: path,
            timeout: const Duration(seconds: 30),
          ),
        );
        expect(reopened.isSuccess, isTrue, reason: '${reopened.diagnostics}');
        expect(reopened.extractedMap!.scenarioChkBytes, bytes);
      }
      expect(await source.readAsBytes(), before);
    },
    skip: !Platform.isWindows || helper == null
        ? 'Set MAP_ARCHIVE_HELPER_PATH on Windows.'
        : false,
  );
}
