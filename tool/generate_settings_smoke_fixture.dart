import 'dart:typed_data';
import 'dart:convert';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_unit_settings_editor.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_upgrade_settings_editor.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_tech_settings_editor.dart';
import 'generate_eud_smoke_fixture.dart';
import 'settings_validation_code.dart';

Future<void> main(List<String> arguments) async {
  final args = [...arguments];
  final changed = args.remove('--modified');
  final combat = args.remove('--combat');
  await generateMapFixture(
    args,
    scenarioBuilder: () => combat
        ? buildCombatSettingsScenario(modified: changed)
        : buildSettingsSmokeScenario(modified: changed),
  );
}

/// Uses the app's setting editors to prepare explicit damage, level and tech
/// overrides. Both variants retain the already tested air-unit placements.
Uint8List buildCombatSettingsScenario({required bool modified}) {
  var doc = const RawChkParser()
      .parse(buildSettingsSmokeScenario(modified: true))
      .document!;
  void apply(Map<int, RawChkSection> changes) {
    for (final entry in changes.entries) {
      doc = doc.replaceSection(entry.key, entry.value);
    }
  }

  apply(
    const ChkUnitSettingsEditor().edit(
      doc,
      damage: {
        (15, false): modified ? 32 : 20,
        (15, true): modified ? 4 : 2,
        (16, false): modified ? 12 : 8,
        (16, true): modified ? 2 : 1,
      },
    ),
  );
  apply(
    const ChkUpgradeSettingsEditor().edit(doc, {
      (9, null, ChkUpgradeField.maximum): 3,
      (9, null, ChkUpgradeField.start): modified ? 2 : 0,
      (9, 0, ChkUpgradeField.inherit): 1,
    }),
  );
  apply(
    const ChkTechSettingsEditor().edit(doc, {
      (9, null, ChkTechField.useDefault): 0,
      (9, null, ChkTechField.energy): modified ? 10 : 25,
      (9, null, ChkTechField.available): 1,
      (9, null, ChkTechField.researched): modified ? 1 : 0,
      (9, 0, ChkTechField.inherit): 1,
    }),
  );
  return const RawChkEncoder().encode(doc);
}

/// First manual gameplay case: selectable flying units over uniform terrain.
/// Game launch and displayed values still require an actual SC:R observation.
Uint8List buildSettingsSmokeScenario({required bool modified}) {
  var doc = const RawChkParser().parse(buildEudSmokeScenarioBytes()).document!;
  void replace(String name, List<int> bytes) {
    final index = doc.sections.indexWhere((s) => s.name == name);
    doc = doc.replaceSection(index, doc.sections[index].withPayload(bytes));
  }

  replace('VCOD', validationCode());
  final title = ascii.encode('Settings Air Stats');
  final description = ascii.encode(
    'Use Map Settings. Compare baseline and modified files. No victory triggers.',
  );
  final strings = BytesBuilder()
    ..add([2, 0, 6, 0, 7 + title.length, 0])
    ..add(title)
    ..addByte(0)
    ..add(description)
    ..addByte(0);
  replace('STR ', strings.takeBytes());
  replace('VER ', [206, 0]);
  replace('OWNR', [6, 5, ...List.filled(9, 0), 7]);
  replace('SIDE', [1, 0, ...List.filled(10, 0)]);
  replace('FORC', [0, 1, ...List.filled(18, 0)]);
  replace('MASK', List.filled(32 * 32, 0));
  final units = BytesBuilder();
  var serial = 0;
  void unit(int type, int owner, int x, int y) {
    final data = ByteData(36)
      ..setUint32(0, ++serial, Endian.little)
      ..setUint16(4, x, Endian.little)
      ..setUint16(6, y, Endian.little)
      ..setUint16(8, type, Endian.little)
      ..setUint16(14, 1, Endian.little) // Owner; other properties use defaults.
      ..setUint8(16, owner)
      ..setUint8(17, 100)
      ..setUint8(18, 100)
      ..setUint8(19, 100);
    units.add(data.buffer.asUint8List());
  }

  unit(214, 0, 160, 160); // Player 1 start.
  unit(214, 1, 800, 800); // Player 2 start.
  unit(8, 0, 224, 224); // Wraith.
  unit(70, 0, 352, 224); // Scout.
  unit(9, 0, 480, 224); // Science Vessel, unchanged control.
  unit(42, 1, 800, 640); // Overlord, unchanged target.
  replace('UNIT', units.takeBytes());

  final settings = Uint8List(4168)..fillRange(0, 228, 1);
  if (modified) {
    final data = ByteData.sublistView(settings);
    for (final (id, hp, shields, armor) in [
      (8, 240, 0, 3),
      (70, 300, 200, 4),
    ]) {
      data
        ..setUint8(id, 0)
        ..setUint32(228 + id * 4, hp * 256, Endian.little)
        ..setUint16(1140 + id * 2, shields, Endian.little)
        ..setUint8(1596 + id, armor);
    }
  }
  replace('UNIx', settings);
  replace('UPGx', Uint8List(794)..fillRange(0, 61, 1));
  replace('TECx', Uint8List(396)..fillRange(0, 44, 1));
  // No production/research/victory triggers in this observation-only case.
  return const RawChkEncoder().encode(doc);
}
