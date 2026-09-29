import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_force_settings_editor.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_player_settings_editor.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_scenario_text_editor.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_tech_settings_editor.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_editor.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_unit_availability_editor.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_unit_settings_editor.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_upgrade_settings_editor.dart';

void main() {
  const factory = NewMapFactory();
  List<int> section(RawChkDocument d, String name) =>
      d.sections.singleWhere((s) => s.name == name).payload;

  test(
    'creates deterministic dirty UMS documents with valid editable defaults',
    () {
      final options = NewMapOptions(
        rawTileValue: 16,
        title: '새 맵',
        description: '직접 제작',
      );
      final document = factory.create(options);
      final bytes = const RawChkEncoder().encode(document);
      expect(document.isDirty, isTrue);
      expect(bytes, const RawChkEncoder().encode(factory.create(options)));
      final parsed = const RawChkParser().parse(bytes);
      expect(parsed.isSuccess, isTrue);
      expect(const RawChkEncoder().encode(parsed.document!), bytes);
      expect(parsed.document!.isDirty, isFalse);
      expect(
        document.sections.map((s) => s.name).toSet().length,
        document.sections.length,
      );
      final metadata = const ChkMetadataViewDecoder().decode(document);
      final strings = const ChkStringViewDecoder().decode(document);
      final terrain = const ChkTerrainViewDecoder().decode(document);
      final objects = const ChkObjectViewDecoder().decode(document);
      expect(metadata.diagnostics, isEmpty);
      expect(strings.diagnostics, isEmpty);
      expect(terrain.diagnostics, isEmpty);
      expect(objects.diagnostics, isEmpty);
      expect(
        const ChkObjectReferenceValidator().validate(
          metadataViews: metadata,
          stringViews: strings,
          objectViews: objects,
        ),
        isEmpty,
      );
      expect(const ChkPlayerSettingsEditor().diagnostics(document), isEmpty);
      expect(metadata.versions.single.knownVersion, ChkMapVersion.broodWar);
      expect(section(document, 'TYPE'), 'RAWB'.codeUnits);
      expect(section(document, 'IVE2'), [11, 0]);
      expect(section(document, 'TILE'), section(document, 'MTXM'));
      expect(document.sections.any((s) => s.name == 'ISOM'), isFalse);
      expect(section(document, 'MASK'), everyElement(255));
      final text = const ChkScenarioTextEditor().read(document);
      expect(text.title, '새 맵');
      expect(text.description, '직접 제작');
      expect(const ChkForceSettingsEditor().read(document).names, [
        'Force 1',
        'Force 2',
        'Force 3',
        'Force 4',
      ]);
      expect(ChkTriggers.read(document).records, isEmpty);
      expect(ChkTriggers.read(document, briefing: true).records, isEmpty);
      final availability = const ChkUnitAvailabilityEditor().read(document);
      for (var player = 0; player < 12; player++) {
        expect(availability.effective(player, 0), isTrue);
        expect(availability.effective(player, 227), isTrue);
      }
      final units = const ChkUnitSettingsEditor().read(document);
      for (var unit = 0; unit < 228; unit++) {
        expect(units.value(unit, ChkUnitSettingField.useDefault), 1);
      }
      final upgrades = const ChkUpgradeSettingsEditor().read(document);
      expect(upgrades.issues, isEmpty);
      expect(upgrades.value((0, null, ChkUpgradeField.maximum)), 3);
      expect(upgrades.value((16, null, ChkUpgradeField.maximum)), 1);
      expect(upgrades.value((18, null, ChkUpgradeField.maximum)), 0);
      for (var upgrade = 0; upgrade < 61; upgrade++) {
        expect(upgrades.value((upgrade, null, ChkUpgradeField.useDefault)), 1);
        expect(upgrades.value((upgrade, 11, ChkUpgradeField.inherit)), 1);
        expect(upgrades.value((upgrade, null, ChkUpgradeField.start)), 0);
      }
      final techs = const ChkTechSettingsEditor().read(document);
      expect(techs.issues, isEmpty);
      for (var tech = 0; tech < 44; tech++) {
        expect(techs.value((tech, null, ChkTechField.useDefault)), 1);
        expect(techs.value((tech, 11, ChkTechField.inherit)), 1);
        expect(techs.value((tech, null, ChkTechField.available)), 1);
      }
      expect(techs.value((4, null, ChkTechField.researched)), 1);
      expect(techs.value((9, null, ChkTechField.researched)), 0);
      // Golden fingerprint of the already game-tested fixture validation data.
      expect(
        sha256.convert(section(document, 'VCOD')).toString(),
        'c13ca25290b5d075eae9705d68a7b8c30af498c36c10e138627f8b49b795392f',
      );
    },
  );

  for (final tileset in ChkTileset.values) {
    test(
      'creates rectangular ${tileset.name} maps with eight unique starts',
      () {
        final doc = factory.create(
          NewMapOptions(
            width: 64,
            height: 96,
            tileset: tileset,
            rawTileValue: 65535,
            humanPlayers: 8,
          ),
        );
        final metadata = const ChkMetadataViewDecoder().decode(doc);
        expect(metadata.tilesets.single.rawValue, tileset.rawValue);
        final terrain = const ChkTerrainViewDecoder()
            .decode(doc)
            .tileMaps
            .single;
        expect(terrain.width, 64);
        expect(terrain.height, 96);
        expect(terrain.rawTileValues, everyElement(65535));
        expect(section(doc, 'OWNR'), [6, 6, 6, 6, 6, 6, 6, 6, 0, 0, 0, 7]);
        expect(section(doc, 'IOWN'), section(doc, 'OWNR'));
        final objects = const ChkObjectViewDecoder().decode(doc);
        final starts = objects.unitSections.single.units;
        expect(starts.map((u) => (u.x, u.y)).toSet(), hasLength(8));
        expect(
          starts.map((u) => u.owner),
          orderedEquals(List.generate(8, (i) => i)),
        );
        for (final start in starts) {
          expect(start.unitType, 214);
          expect(start.validFieldFlags, 1);
          expect(start.x, inExclusiveRange(0, 64 * 32));
          expect(start.y, inExclusiveRange(0, 96 * 32));
        }
        final anywhere = objects.locationSections.single.locations[63];
        expect(
          (
            anywhere.left,
            anywhere.top,
            anywhere.right,
            anywhere.bottom,
            anywhere.stringId,
          ),
          (0, 0, 2048, 3072, 3),
        );
        expect(const ChkPlayerSettingsEditor().diagnostics(doc), isEmpty);
      },
    );
  }

  test(
    'validates policy bounds and legacy string capacity without truncation',
    () {
      for (final dimension in [-1, 0, 31, 33, 257, 65536]) {
        expect(
          () => NewMapOptions(width: dimension, rawTileValue: 1),
          throwsArgumentError,
        );
        expect(
          () => NewMapOptions(height: dimension, rawTileValue: 1),
          throwsArgumentError,
        );
      }
      for (final tile in [-1, 65536]) {
        expect(() => NewMapOptions(rawTileValue: tile), throwsRangeError);
      }
      for (final players in [0, 9]) {
        expect(
          () => NewMapOptions(rawTileValue: 1, humanPlayers: players),
          throwsRangeError,
        );
      }
      for (final title in ['', '  ', 'x\u0000y']) {
        expect(
          () => NewMapOptions(rawTileValue: 1, title: title),
          throwsArgumentError,
        );
      }
      expect(
        () => NewMapOptions(rawTileValue: 1, description: '\u0000'),
        throwsArgumentError,
      );
      expect(
        () => factory.create(
          NewMapOptions(rawTileValue: 1, description: '한' * 22000),
        ),
        throwsArgumentError,
      );
      for (final size in [32, 256]) {
        final d = factory.create(
          NewMapOptions(width: size, height: size, rawTileValue: 0),
        );
        expect(section(d, 'MTXM').length, size * size * 2);
        final start = const ChkObjectViewDecoder()
            .decode(d)
            .unitSections
            .single
            .units
            .single;
        expect((start.x, start.y), (size * 16, size * 16));
      }
    },
  );
}
