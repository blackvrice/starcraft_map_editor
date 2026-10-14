import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/placement/unit_collision_catalog.dart';
import 'package:starcraft_map_editor/domain/placement/unit_collision_profile.dart';
import 'package:starcraft_map_editor/domain/placement/unit_placement_capability.dart';

void main() {
  for (final candidateAir in [false, true]) {
    for (final existingAir in [false, true]) {
      test(
        'overlap separates candidateAir=$candidateAir existingAir=$existingAir',
        () {
          final candidate = _cap(0, flyer: candidateAir);
          final catalog = UnitCollisionCatalog({
            0: candidate,
            1: _cap(1, flyer: existingAir),
          });
          expect(
            catalog.check(
              candidate: candidate,
              x: 32,
              y: 32,
              existing: [_unit(1, 32, 32)],
            ),
            candidateAir == existingAir
                ? UnitCollisionCheck.overlap
                : UnitCollisionCheck.clear,
          );
        },
      );
    }
  }
  for (final x in [43, 44]) {
    test('closed collision edges at x=$x', () {
      final cap = _cap(0);
      expect(
        UnitCollisionCatalog({
          0: cap,
        }).check(candidate: cap, x: x, y: 32, existing: [_unit(0, 32, 32)]),
        x == 43 ? UnitCollisionCheck.overlap : UnitCollisionCheck.clear,
      );
    });
  }
  for (final lifted in [false, true]) {
    for (final flyer in [false, true]) {
      test('lifted building=$lifted candidateAir=$flyer', () {
        final cap = _cap(0, flyer: flyer);
        final catalog = UnitCollisionCatalog({
          0: cap,
          1: _cap(1, building: true, liftable: true),
        });
        expect(
          catalog.check(
            candidate: cap,
            x: 32,
            y: 32,
            existing: [_unit(1, 32, 32, state: lifted ? 4 : 0, valid: 4)],
          ),
          lifted == flyer
              ? UnitCollisionCheck.overlap
              : UnitCollisionCheck.clear,
        );
      });
    }
  }
  for (final kind in ['missing-valid', 'not-building', 'not-liftable']) {
    test('unsupported flight state $kind is not guessed', () {
      final cap = _cap(0);
      final catalog = UnitCollisionCatalog({
        0: cap,
        1: _cap(
          1,
          building: kind != 'not-building',
          liftable: kind != 'not-liftable',
        ),
      });
      expect(
        catalog.check(
          candidate: cap,
          x: 120,
          y: 120,
          existing: [
            _unit(1, 32, 32, state: 4, valid: kind == 'missing-valid' ? 0 : 4),
          ],
        ),
        UnitCollisionCheck.stateUnsupported,
      );
    });
  }
  for (final missing in [
    'candidate',
    'snapshot',
    'existing',
    'subunit',
    'extended',
  ]) {
    test(
      'unavailable geometry $missing cannot authorize even distant placement',
      () {
        final candidate = _cap(0, missing: missing == 'candidate');
        final catalog = UnitCollisionCatalog({
          if (missing != 'snapshot') 0: candidate,
          1: _cap(
            1,
            missing: missing == 'existing',
            subunit: missing == 'subunit',
          ),
        });
        expect(
          catalog.check(
            candidate: candidate,
            x: 120,
            y: 120,
            existing: [_unit(missing == 'extended' ? 300 : 1, 32, 32)],
          ),
          UnitCollisionCheck.metadataUnavailable,
        );
      },
    );
  }
  test('snapshot/candidate mismatches fail closed', () {
    final candidate = _cap(0);
    for (final other in [
      _cap(0, flyer: true),
      _cap(0, building: true),
      _cap(0, liftable: true),
      _cap(0, left: 8),
    ]) {
      expect(
        UnitCollisionCatalog({
          0: other,
        }).check(candidate: candidate, x: 32, y: 32, existing: []),
        UnitCollisionCheck.metadataUnavailable,
      );
    }
  });
  test(
    'unknown metadata takes priority over a known overlap in either order',
    () {
      final cap = _cap(0);
      final catalog = UnitCollisionCatalog({0: cap});
      for (final existing in [
        [_unit(0, 32, 32), _unit(300, 200, 200)],
        [_unit(300, 200, 200), _unit(0, 32, 32)],
      ]) {
        expect(
          catalog.check(candidate: cap, x: 32, y: 32, existing: existing),
          UnitCollisionCheck.metadataUnavailable,
        );
      }
    },
  );
  test('catalog freezes inputs and rejects mismatched keys', () {
    final map = {0: _cap(0)};
    final catalog = UnitCollisionCatalog(map);
    map.clear();
    expect(catalog.units, hasLength(1));
    expect(() => catalog.units.clear(), throwsUnsupportedError);
    expect(() => UnitCollisionCatalog({1: _cap(0)}), throwsArgumentError);
  });
}

UnitPlacementCapability _cap(
  int id, {
  bool flyer = false,
  bool building = false,
  bool liftable = false,
  bool missing = false,
  bool subunit = false,
  int left = 3,
}) => UnitPlacementCapability(
  unitId: id,
  isSubunit: subunit,
  collisionProfile: missing
      ? null
      : UnitCollisionProfile(
          left: left,
          up: 5,
          right: 8,
          down: 9,
          isFlyer: flyer,
        ),
  isBuilding: building,
  isFlyingBuilding: liftable,
  isSpellcaster: false,
  hasShields: false,
  isResourceContainer: false,
  isGasResourceContainer: false,
  hasHangar: false,
  isBurrowable: false,
  isCloakable: false,
  isInvincible: false,
  requiresRelationLink: false,
);

ChkUnitPlacement _unit(int id, int x, int y, {int state = 0, int valid = 0}) {
  final bytes = Uint8List(8 + 36)..setRange(0, 4, 'UNIT'.codeUnits);
  ByteData.sublistView(bytes)
    ..setUint32(4, 36, Endian.little)
    ..setUint16(12, x, Endian.little)
    ..setUint16(14, y, Endian.little)
    ..setUint16(16, id, Endian.little)
    ..setUint16(20, valid, Endian.little)
    ..setUint16(34, state, Endian.little);
  return const ChkObjectViewDecoder()
      .decode(const RawChkParser().parse(bytes).document!)
      .unitSections
      .single
      .units
      .single;
}
