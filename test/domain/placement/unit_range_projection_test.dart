import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/eud/eud_dat_snapshot.dart';
import 'package:starcraft_map_editor/domain/placement/unit_range_projection.dart';
import '../../fixtures/basic_editing_fixture.dart';
import '../../fixtures/eud_dat_fixture.dart';

void main() {
  final unit = const ChkObjectViewDecoder()
      .decode(basicDocument(units: [basicUnit()]))
      .unitSections
      .single
      .units
      .single;
  UnitRangeProjection project(EudDatSnapshot? dat, {int count = 1}) =>
      UnitRangeProjection.fromDat(
        dat: dat,
        selected: List.filled(count, unit),
        mapWidth: 32,
        mapHeight: 32,
      );
  test(
    'sight uses tiles, weapons pixels; follows turret and both air/ground',
    () {
      final c = syntheticDatColumns();
      c['unit.sightRange']![0] = 7;
      c['unit.subunit1']![0] = 1;
      c['unit.groundWeapon']![1] = 2;
      c['unit.airWeapon']![1] = 3;
      c['weapon.minRange']![2] = 64;
      c['weapon.maxRange']![2] = 224;
      c['weapon.maxRange']![3] = 192;
      final result = project(EudDatSnapshot(c));
      expect(
        result.rings.map((r) => (r.kind, r.minimum, r.maximum, r.sourceUnit)),
        [
          (UnitRangeKind.sight, 0, 224, 0),
          (UnitRangeKind.ground, 64, 224, 1),
          (UnitRangeKind.air, 0, 192, 1),
        ],
      );
      expect(result.unknownUnits, 0);
      expect(result.rings.every((r) => r.x == 128 && r.y == 128), isTrue);
      expect(() => result.rings.clear(), throwsUnsupportedError);
    },
  );
  test('cycles terminate and shared subunits are visited only once', () {
    final c = syntheticDatColumns();
    c['unit.subunit1']![0] = 1;
    c['unit.subunit2']![0] = 1;
    c['unit.subunit1']![1] = 0;
    c['unit.groundWeapon']![1] = 2;
    c['weapon.maxRange']![2] = 32;
    expect(project(EudDatSnapshot(c)).rings.length, 1);
  });
  for (final pair in [(128, 64), (0, 8193)]) {
    test('invalid/over-budget weapon geometry $pair stays unknown', () {
      final c = syntheticDatColumns();
      c['unit.groundWeapon']![0] = 0;
      c['weapon.minRange']![0] = pair.$1;
      c['weapon.maxRange']![0] = pair.$2;
      final result = project(EudDatSnapshot(c));
      expect(result.rings, isEmpty);
      expect(result.unknownUnits, 1);
    });
  }
  test('invalid DAT references fail closed rather than crash rendering', () {
    final c = syntheticDatColumns();
    c['unit.subunit1']![2] = 65535;
    expect(project(EudDatSnapshot(c)).unknownUnits, 1);
  });
  test('missing DAT, zero radii and selection budget are explicit', () {
    expect(project(null).unknownUnits, 1);
    expect(project(EudDatSnapshot(syntheticDatColumns())).rings, isEmpty);
    final over = project(null, count: 65);
    expect(over.selectionLimitExceeded, isTrue);
    expect(over.rings, isEmpty);
  });
  test('invalid UNIT id and off-map coordinates never create rings', () {
    final selected = const ChkObjectViewDecoder()
        .decode(
          basicDocument(
            units: [
              basicUnit(type: 228),
              basicUnit(x: 1024),
              basicUnit(y: 1024),
            ],
          ),
        )
        .unitSections
        .single
        .units;
    final result = UnitRangeProjection.fromDat(
      dat: EudDatSnapshot(syntheticDatColumns()),
      selected: selected,
      mapWidth: 32,
      mapHeight: 32,
    );
    expect(result.unknownUnits, 3);
    expect(result.rings, isEmpty);
  });
  test(
    'ring budget prevents pathological reference graphs from flooding paint',
    () {
      final c = syntheticDatColumns();
      for (var i = 0; i < 228; i++) {
        c['unit.subunit1']![i] = (i + 1) % 228;
        c['unit.groundWeapon']![i] = 0;
        c['weapon.maxRange']![0] = 32;
      }
      final result = project(EudDatSnapshot(c), count: 3);
      expect(result.selectionLimitExceeded, isTrue);
      expect(result.rings, isEmpty);
    },
  );
}
