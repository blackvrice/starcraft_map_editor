import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/placement/building_placement_box.dart';
import 'package:starcraft_map_editor/domain/placement/unit_collision_profile.dart';
import 'package:starcraft_map_editor/domain/placement/unit_creep_catalog.dart';
import 'package:starcraft_map_editor/domain/placement/unit_creep_coverage.dart';
import 'package:starcraft_map_editor/domain/placement/unit_environment_profile.dart';
import 'package:starcraft_map_editor/domain/placement/unit_placement_capability.dart';

void main() {
  final candidate = _cap();
  final catalog = UnitCreepCatalog({candidate.unitId: candidate});

  test('coverage is immutable, row-major and distinguishes unknown/absent', () {
    final tiles = [
      UnitCreepTile.present,
      UnitCreepTile.absent,
      UnitCreepTile.unknown,
      UnitCreepTile.present,
    ];
    final coverage = UnitCreepCoverage(width: 2, height: 2, tiles: tiles);
    tiles[0] = UnitCreepTile.absent;
    expect(coverage.tileAt(x: 0, y: 0), UnitCreepTile.present);
    expect(coverage.tileAt(x: 1, y: 0), UnitCreepTile.absent);
    expect(coverage.tileAt(x: 0, y: 1), UnitCreepTile.unknown);
    expect(coverage.tileAt(x: 1, y: 1), UnitCreepTile.present);
    expect(() => coverage.tiles.clear(), throwsUnsupportedError);
    for (final point in [(-1, 0), (2, 0), (0, -1), (0, 2)]) {
      expect(coverage.tileAt(x: point.$1, y: point.$2), UnitCreepTile.unknown);
    }
  });
  for (final dimensions in [(0, 8), (257, 8), (8, 0), (8, 257)]) {
    test('invalid coverage dimensions $dimensions rejected', () {
      expect(
        () => UnitCreepCoverage(
          width: dimensions.$1,
          height: dimensions.$2,
          tiles: const [],
        ),
        throwsArgumentError,
      );
    });
  }
  for (final count in [0, 63, 65]) {
    test('coverage needs exactly width*height records: $count', () {
      expect(
        () => UnitCreepCoverage(
          width: 8,
          height: 8,
          tiles: List.filled(count, UnitCreepTile.absent),
        ),
        throwsArgumentError,
      );
    });
  }
  for (final tile in UnitCreepTile.values) {
    test('explicit uniform $tile, no provider or image inference', () {
      expect(
        _check(catalog, candidate, coverage: _coverage(fill: tile)),
        switch (tile) {
          UnitCreepTile.present => UnitCreepCheck.covered,
          UnitCreepTile.absent => UnitCreepCheck.missing,
          UnitCreepTile.unknown => UnitCreepCheck.unavailable,
        },
      );
    });
  }
  test('missing coverage is unavailable, never an all-absent map', () {
    expect(_check(catalog, candidate), UnitCreepCheck.unavailable);
  });
  for (final points in [((1, 1), (2, 2)), ((2, 2), (1, 1))]) {
    test('unknown outranks absence in either tile order $points', () {
      expect(
        _check(
          catalog,
          candidate,
          coverage: _coverage(
            edits: {
              points.$1: UnitCreepTile.unknown,
              points.$2: UnitCreepTile.absent,
            },
          ),
        ),
        UnitCreepCheck.unavailable,
      );
    });
  }
  test('only intersected footprint matters; right/bottom are exclusive', () {
    final coverage = _coverage(
      edits: {
        (0, 0): UnitCreepTile.unknown,
        (3, 1): UnitCreepTile.absent,
        (1, 3): UnitCreepTile.absent,
      },
    );
    expect(
      _check(catalog, candidate, coverage: coverage),
      UnitCreepCheck.covered,
    );
    expect(
      _check(catalog, candidate, coverage: coverage, x: 65),
      UnitCreepCheck.missing,
    );
    expect(
      _check(catalog, candidate, coverage: coverage, y: 65),
      UnitCreepCheck.missing,
    );
  });
  for (final point in [(32, 32), (224, 224)]) {
    test('whole box may touch map edge $point', () {
      expect(
        _check(
          catalog,
          candidate,
          coverage: _coverage(),
          x: point.$1,
          y: point.$2,
        ),
        UnitCreepCheck.covered,
      );
    });
  }
  for (final point in [
    (-1, 64),
    (31, 64),
    (225, 64),
    (256, 64),
    (64, -1),
    (64, 31),
    (64, 225),
    (64, 256),
    (0x7fffffffffffffff, 64),
    (64, 0x7fffffffffffffff),
  ]) {
    test('whole box outside or extreme coordinate $point', () {
      expect(
        _check(
          catalog,
          candidate,
          coverage: _coverage(),
          x: point.$1,
          y: point.$2,
        ),
        UnitCreepCheck.outOfBounds,
      );
    });
  }
  test('source map copied and wrong catalog ID rejected', () {
    final source = {candidate.unitId: candidate};
    final copied = UnitCreepCatalog(source);
    source.clear();
    expect(
      _check(copied, candidate, coverage: _coverage()),
      UnitCreepCheck.covered,
    );
    expect(() => copied.units.clear(), throwsUnsupportedError);
    expect(() => UnitCreepCatalog({0: candidate}), throwsArgumentError);
  });
  test('missing DAT role/source is not a false requirement', () {
    expect(_check(UnitCreepCatalog({}), candidate), UnitCreepCheck.unavailable);
    final unknown = _cap(missingRole: true);
    expect(
      _check(UnitCreepCatalog({unknown.unitId: unknown}), unknown),
      UnitCreepCheck.unavailable,
    );
  });
  for (final mismatch in <String, UnitPlacementCapability>{
    'requirement': _cap(creep: false),
    'psi': _cap(psi: true),
    'building': _cap(building: false),
    'subunit': _cap(subunit: true),
    'flying building': _cap(flyingBuilding: true),
    'relation': _cap(relation: true),
    'gas': _cap(gas: true),
    'width': _cap(width: 96),
    'height': _cap(height: 96),
    'flyer': _cap(flyer: true),
    'role missing': _cap(missingRole: true),
    'box missing': _cap(missingBox: true),
    'geometry missing': _cap(missingGeometry: true),
  }.entries) {
    test('candidate/source mismatch: ${mismatch.key}', () {
      expect(
        _check(
          UnitCreepCatalog({candidate.unitId: mismatch.value}),
          candidate,
          coverage: _coverage(),
        ),
        UnitCreepCheck.unavailable,
      );
    });
  }
  for (final unsupported in <String, UnitPlacementCapability>{
    'nonbuilding': _cap(building: false),
    'subunit': _cap(subunit: true),
    'flying building': _cap(flyingBuilding: true),
    'relation': _cap(relation: true),
    'gas exception': _cap(gas: true),
    'flyer': _cap(flyer: true),
  }.entries) {
    test('special state not approximated: ${unsupported.key}', () {
      final cap = unsupported.value;
      expect(
        _check(UnitCreepCatalog({cap.unitId: cap}), cap, coverage: _coverage()),
        UnitCreepCheck.stateUnsupported,
      );
    });
  }
  test('no-creep requirement is rule N/A, not creep permission', () {
    final cap = _cap(
      creep: false,
      building: false,
      missingBox: true,
      missingGeometry: true,
    );
    expect(
      _check(UnitCreepCatalog({cap.unitId: cap}), cap, mapWidth: 0),
      UnitCreepCheck.notApplicable,
    );
  });
  test('psi remains independent; positive creep check does not test power', () {
    final cap = _cap(psi: true);
    expect(
      _check(UnitCreepCatalog({cap.unitId: cap}), cap, coverage: _coverage()),
      UnitCreepCheck.covered,
    );
  });
  for (final dims in [(0, 8), (257, 8), (8, 0), (8, 257)]) {
    test('invalid map DIM $dims is unavailable', () {
      expect(
        _check(
          catalog,
          candidate,
          coverage: _coverage(),
          mapWidth: dims.$1,
          mapHeight: dims.$2,
        ),
        UnitCreepCheck.unavailable,
      );
    });
  }
  for (final dims in [(4, 8), (8, 4)]) {
    test('coverage must match current DIM $dims', () {
      expect(
        _check(
          catalog,
          candidate,
          coverage: _coverage(width: dims.$1, height: dims.$2),
        ),
        UnitCreepCheck.unavailable,
      );
    });
  }
  for (final extent in [2048, 2080]) {
    test('synchronous tile budget boundary extent=$extent', () {
      final cap = _cap(width: extent, height: 2048);
      final c = UnitCreepCatalog({cap.unitId: cap});
      expect(
        _check(
          c,
          cap,
          coverage: _coverage(width: 256, height: 256),
          mapWidth: 256,
          mapHeight: 256,
          x: 4096,
          y: 4096,
        ),
        extent == 2048 ? UnitCreepCheck.covered : UnitCreepCheck.unavailable,
      );
    });
  }
  test(
    'all intersected tiles agree with a pixel reference across alignments',
    () {
      final coverage = _coverage(edits: {(2, 3): UnitCreepTile.absent});
      for (final width in [32, 64, 96]) {
        for (final height in [32, 64, 96]) {
          final cap = _cap(width: width, height: height);
          final c = UnitCreepCatalog({cap.unitId: cap});
          for (var x = 48; x <= 112; x += 8) {
            for (var y = 48; y <= 112; y += 8) {
              var missing = false;
              for (var px = x - width ~/ 2; px < x + width ~/ 2; px++) {
                for (var py = y - height ~/ 2; py < y + height ~/ 2; py++) {
                  missing |=
                      coverage.tileAt(x: px ~/ 32, y: py ~/ 32) ==
                      UnitCreepTile.absent;
                }
              }
              expect(
                _check(c, cap, coverage: coverage, x: x, y: y),
                missing ? UnitCreepCheck.missing : UnitCreepCheck.covered,
                reason: '$width x $height at $x,$y',
              );
            }
          }
        }
      }
    },
  );
}

UnitCreepCoverage _coverage({
  int width = 8,
  int height = 8,
  UnitCreepTile fill = UnitCreepTile.present,
  Map<(int, int), UnitCreepTile> edits = const {},
}) {
  final tiles = List.filled(width * height, fill);
  for (final edit in edits.entries) {
    tiles[edit.key.$2 * width + edit.key.$1] = edit.value;
  }
  return UnitCreepCoverage(width: width, height: height, tiles: tiles);
}

UnitCreepCheck _check(
  UnitCreepCatalog catalog,
  UnitPlacementCapability cap, {
  UnitCreepCoverage? coverage,
  int x = 64,
  int y = 64,
  int mapWidth = 8,
  int mapHeight = 8,
}) => catalog.checkRequirement(
  candidate: cap,
  x: x,
  y: y,
  mapWidthTiles: mapWidth,
  mapHeightTiles: mapHeight,
  coverage: coverage,
);

UnitPlacementCapability _cap({
  bool creep = true,
  bool psi = false,
  bool building = true,
  bool subunit = false,
  bool flyingBuilding = false,
  bool relation = false,
  bool gas = false,
  bool flyer = false,
  int width = 64,
  int height = 64,
  bool missingRole = false,
  bool missingBox = false,
  bool missingGeometry = false,
}) => UnitPlacementCapability(
  unitId: 142,
  isSubunit: subunit,
  isSpellcaster: false,
  hasShields: false,
  isResourceContainer: gas,
  isGasResourceContainer: gas,
  hasHangar: false,
  isFlyingBuilding: flyingBuilding,
  isBurrowable: false,
  isCloakable: false,
  isInvincible: false,
  isBuilding: building,
  requiresRelationLink: relation,
  environmentProfile: missingRole
      ? null
      : UnitEnvironmentProfile(requiresPsi: psi, requiresCreep: creep),
  placementBox: missingBox
      ? null
      : BuildingPlacementBox(width: width, height: height),
  collisionProfile: missingGeometry
      ? null
      : UnitCollisionProfile(
          left: 0,
          up: 0,
          right: 65535,
          down: 65535,
          isFlyer: flyer,
        ),
);
