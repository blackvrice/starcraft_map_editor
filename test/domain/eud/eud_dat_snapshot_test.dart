import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/eud/eud_dat_layout.dart';
import 'package:starcraft_map_editor/domain/eud/eud_dat_snapshot.dart';
import 'package:starcraft_map_editor/domain/eud/eud_field_manifest.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';
import 'package:starcraft_map_editor/domain/eud/eud_effective_settings.dart';
import 'package:starcraft_map_editor/domain/chk/raw_chk_section.dart';
import '../../fixtures/eud_dat_fixture.dart';
import '../../fixtures/eud_project_workspace_fixture.dart';

void main() {
  test(
    'covers 58 DAT fields, partial sounds, player runtime exclusions and enum gaps',
    () {
      final columns = syntheticDatColumns();
      columns['image.drawingFunction']![0] = 17;
      columns['image.drawingFunction']![1] = 12; // Warp texture supported.
      columns['image.drawingFunction']![2] = 18; // Outside manifest.
      columns['image.drawingFunction']![3] = 11; // Excluded HpBar gap.
      columns['unit.hasShield']![0] = 2;
      final data = EudDatSnapshot(columns);
      expect(data.value('image.drawingFunction', 0), 'WarpFlash');
      expect(data.value('image.drawingFunction', 1), 'WarpTexture');
      expect(data.value('image.drawingFunction', 2), isNull);
      expect(data.value('image.drawingFunction', 3), isNull);
      expect(data.raw('unit.hasShield', 0), 2);
      expect(data.value('unit.hasShield', 0), isNull);
      expect(data.raw('unit.readySound', 106), isNull);
      expect(data.value('player.terranSupplyMax', 0), isNull);
      expect(
        EudFieldManifest.fields
            .where((f) => EudDatLayout.counts.containsKey(f.key))
            .length,
        58,
      );
      expect(EudDatLayout.memory.length, 61);
      columns['weapon.cooldown']![0] = 99;
      expect(data.value('weapon.cooldown', 0), 15); // Immutable snapshot.
      expect(
        () => data.columns['weapon.cooldown']![0] = 1,
        throwsUnsupportedError,
      );
    },
  );
  test('missing, wrong length, overflow and extra columns are rejected', () {
    expect(
      () => EudDatSnapshot(syntheticDatColumns()..remove('sprite.image')),
      throwsFormatException,
    );
    expect(
      () => EudDatSnapshot(
        syntheticDatColumns()..['unit.readySound'] = List.filled(228, 0),
      ),
      throwsFormatException,
    );
    expect(
      () =>
          EudDatSnapshot(syntheticDatColumns()..['weapon.cooldown']![0] = 256),
      throwsFormatException,
    );
    expect(
      () => EudDatSnapshot(syntheticDatColumns()..['unknown'] = []),
      throwsFormatException,
    );
  });
  test(
    'reverse graphics includes weapons, subunits and construction, planned links and cycles',
    () {
      final c = syntheticDatColumns();
      c['unit.flingy']![0] = 1;
      c['unit.groundWeapon']![0] = 0;
      c['unit.subunit1']![2] = 0;
      c['unit.subunit1']![0] = 2; // cycle
      c['weapon.flingy']![0] = 1;
      c['flingy.sprite']![1] = 10;
      c['sprite.image']![10] = 20;
      c['unit.construction_animation']![3] = 20;
      final data = EudDatSnapshot(c), original = data.graph();
      final node = (table: EudTable.image, id: 20);
      expect(
        original
            .allUsers(node)
            .where((n) => n.table == EudTable.unit)
            .map((n) => n.id),
        [0, 2, 3],
      );
      expect(original.directUsers(node), [
        (table: EudTable.unit, id: 3),
        (table: EudTable.sprite, id: 10),
      ]);
      final planned = data.graph([
        EudOverride(field: 'sprite.image', targetId: 10, value: 21),
      ]);
      expect(planned.allUsers(node), [(table: EudTable.unit, id: 3)]);
      expect(
        planned
            .allUsers((table: EudTable.image, id: 21))
            .where((n) => n.table == EudTable.unit)
            .map((n) => n.id),
        [0, 2],
      );
      expect(
        data
            .graph([
              EudOverride(field: 'unit.groundWeapon', targetId: 0, value: 130),
            ])
            .allUsers((table: EudTable.weapon, id: 0)),
        isEmpty,
      );
      expect(data.weaponIndex().subunitUsers(0), [2]);
      expect(
        data
            .weaponIndex([
              EudOverride(field: 'unit.groundWeapon', targetId: 0, value: 130),
            ])
            .directUsers(0),
        isEmpty,
      );
      c['flingy.sprite']![1] = 999;
      expect(EudDatSnapshot(c).graph().unresolved, isNotEmpty);
    },
  );
  test('DAT baseline keeps CHK precedence and unverified bindings', () async {
    final f = EudWorkspaceFixture();
    addTearDown(f.dispose);
    await f.maps.open();
    final project = EudProject(
      mapPath: 'test.scx',
      mapSha256: 'a' * 64,
      overrides: [
        EudOverride(
          field: 'unit.maxShield',
          targetId: 0,
          value: 100,
          overrideChk: true,
        ),
        EudOverride(field: 'weapon.cooldown', targetId: 0, value: 1),
      ],
    );
    final columns = syntheticDatColumns()..['unit.maxShield']![0] = 50;
    final dat = syntheticDatSource(columns).snapshot;
    final map = f.maps.state.session!.rawDocument.appendSection(
      RawChkSection(
        nameBytes: 'UNIx'.codeUnits,
        declaredLength: 4168,
        payload: List.filled(4168, 0),
        sourceOffset: 0,
      ),
    );
    final values = EudEffectiveSettings.resolve(
      project,
      verifiedDocument: map,
      localDat: dat,
    );
    expect(values[0].baselineSource, EudBaselineSource.chk);
    expect(values[1].baselineSource, EudBaselineSource.localDat);
    expect(values[1].baselineValue, 15);
    expect(
      EudEffectiveSettings.resolve(project, localDat: dat).first.baselineSource,
      EudBaselineSource.unverifiedMap,
    );
  });
}
