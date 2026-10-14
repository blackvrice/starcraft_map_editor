import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/placement/unit_collision_profile.dart';
import 'package:starcraft_map_editor/domain/placement/unit_placement_capability.dart';
import 'package:starcraft_map_editor/domain/placement/unit_resource_distance_catalog.dart';
import 'package:starcraft_map_editor/domain/placement/unit_resource_profile.dart';

void main() {
  final depot = _cap(0, depot: true);
  final resource = _cap(1, resource: true);
  final catalog = UnitResourceDistanceCatalog({0: depot, 1: resource});

  for (final reverseRoles in [false, true]) {
    for (final x in [224, 256]) {
      test('aggregate distance reverse=$reverseRoles x=$x', () {
        expect(
          _check(catalog, reverseRoles ? resource : depot, [
            _unit(reverseRoles ? 0 : 1, x, 128),
          ]),
          x == 224
              ? UnitResourceDistanceCatalogCheck.tooClose
              : UnitResourceDistanceCatalogCheck.clear,
        );
      });
    }
  }
  test('confirmed nonparticipant is not a general placement permission', () {
    final cap = _cap(2, missingGeometry: true);
    expect(
      _check(
        UnitResourceDistanceCatalog({2: cap}),
        cap,
        [_unit(300, 0, 0)],
        width: 0,
        x: -10,
      ),
      UnitResourceDistanceCatalogCheck.notApplicable,
    );
  });
  test(
    'both roles use depot-first matching, not an invented exclusive role',
    () {
      final both = _cap(2, depot: true, resource: true);
      final snapshot = UnitResourceDistanceCatalog({
        0: depot,
        1: resource,
        2: both,
      });
      expect(
        _check(snapshot, both, [_unit(0, 128, 128)]),
        UnitResourceDistanceCatalogCheck.clear,
      );
      expect(
        _check(snapshot, both, [_unit(1, 128, 128)]),
        UnitResourceDistanceCatalogCheck.tooClose,
      );
    },
  );
  for (final source in [
    _cap(0),
    _cap(0, depot: true, resource: true),
    _cap(0, depot: true, missingRole: true),
    _cap(0, depot: true, missingGeometry: true),
    _cap(0, depot: true, left: 1),
    _cap(0, depot: true, up: 1),
    _cap(0, depot: true, right: 1),
    _cap(0, depot: true, down: 1),
    _cap(0, depot: true, flyer: true),
    _cap(0, depot: true, building: true),
    _cap(0, depot: true, liftable: true),
    _cap(0, depot: true, subunit: true),
    _cap(0, depot: true, relation: true),
  ].indexed) {
    test(
      'selected capability must agree with numeric snapshot ${source.$1}',
      () {
        expect(
          _check(UnitResourceDistanceCatalog({0: source.$2}), depot, []),
          UnitResourceDistanceCatalogCheck.metadataUnavailable,
        );
      },
    );
  }
  test('missing selected metadata or candidate geometry remains unknown', () {
    for (final cap in [
      _cap(0, depot: true, missingRole: true),
      _cap(0, depot: true, missingGeometry: true),
      _cap(0, depot: true, subunit: true),
    ]) {
      expect(
        _check(UnitResourceDistanceCatalog({0: cap}), cap, []),
        UnitResourceDistanceCatalogCheck.metadataUnavailable,
      );
    }
    expect(
      _check(UnitResourceDistanceCatalog({}), depot, []),
      UnitResourceDistanceCatalogCheck.metadataUnavailable,
    );
  });
  for (final missing in ['entry', 'role', 'geometry', 'subunit']) {
    test('distant unknown $missing outranks known distance violation', () {
      final snapshot = UnitResourceDistanceCatalog({
        0: depot,
        1: resource,
        if (missing != 'entry')
          2: _cap(
            2,
            missingRole: missing == 'role',
            missingGeometry: missing == 'geometry',
            subunit: missing == 'subunit',
          ),
      });
      final units = [
        _unit(1, 128, 128),
        _unit(missing == 'entry' ? 300 : 2, 900, 900),
      ];
      for (final order in [units, units.reversed]) {
        expect(
          _check(snapshot, depot, order),
          UnitResourceDistanceCatalogCheck.metadataUnavailable,
        );
      }
    });
  }
  for (final state in [
    'missing-valid',
    'not-building',
    'not-liftable',
    'lifted',
    'flyer',
  ]) {
    test('relevant flight $state is explicitly unsupported', () {
      final cap = _cap(
        2,
        resource: true,
        building: state != 'not-building',
        liftable: state != 'not-liftable',
        flyer: state == 'flyer',
      );
      expect(
        _check(UnitResourceDistanceCatalog({0: depot, 2: cap}), depot, [
          _unit(
            2,
            900,
            900,
            state: state == 'flyer' ? 0 : 4,
            valid: state == 'missing-valid' ? 0 : 4,
          ),
        ]),
        UnitResourceDistanceCatalogCheck.stateUnsupported,
      );
    });
  }
  test('grounded liftable participant remains supported', () {
    final cap = _cap(2, resource: true, building: true, liftable: true);
    expect(
      _check(UnitResourceDistanceCatalog({0: depot, 2: cap}), depot, [
        _unit(2, 128, 128, valid: 4),
      ]),
      UnitResourceDistanceCatalogCheck.tooClose,
    );
  });
  test('irrelevant valid flight is ignored but malformed flight is not', () {
    final cap = _cap(2, building: true, liftable: true);
    final snapshot = UnitResourceDistanceCatalog({0: depot, 2: cap});
    expect(
      _check(snapshot, depot, [_unit(2, 128, 128, state: 4, valid: 4)]),
      UnitResourceDistanceCatalogCheck.clear,
    );
    expect(
      _check(snapshot, depot, [_unit(2, 128, 128, state: 4)]),
      UnitResourceDistanceCatalogCheck.stateUnsupported,
    );
  });
  test('candidate flyer is unsupported; unknown UNIT still has priority', () {
    final cap = _cap(0, depot: true, flyer: true);
    final snapshot = UnitResourceDistanceCatalog({0: cap});
    expect(
      _check(snapshot, cap, []),
      UnitResourceDistanceCatalogCheck.stateUnsupported,
    );
    expect(
      _check(snapshot, cap, [_unit(300, 900, 900)]),
      UnitResourceDistanceCatalogCheck.metadataUnavailable,
    );
  });
  test('flight then bounds then distance priority is order-independent', () {
    final cap = _cap(2, resource: true, flyer: true);
    final snapshot = UnitResourceDistanceCatalog({
      0: depot,
      1: resource,
      2: cap,
    });
    final units = [_unit(1, 128, 128), _unit(1, 2048, 128), _unit(2, 900, 900)];
    for (final order in [units, units.reversed]) {
      expect(
        _check(snapshot, depot, order),
        UnitResourceDistanceCatalogCheck.stateUnsupported,
      );
    }
    for (final order in [units.take(2), units.take(2).toList().reversed]) {
      expect(
        _check(snapshot, depot, order),
        UnitResourceDistanceCatalogCheck.outOfBounds,
      );
    }
  });
  for (final point in [
    (x: -1, y: 128),
    (x: 2048, y: 128),
    (x: 128, y: -1),
    (x: 128, y: 2048),
  ]) {
    test('candidate bounds checked even in empty map $point', () {
      expect(
        _check(catalog, depot, [], x: point.x, y: point.y),
        UnitResourceDistanceCatalogCheck.outOfBounds,
      );
    });
  }
  test('bounds include extents, not only center, and are never clamped', () {
    final cap = _cap(0, depot: true, left: 3);
    expect(
      _check(UnitResourceDistanceCatalog({0: cap}), cap, [], x: 2),
      UnitResourceDistanceCatalogCheck.outOfBounds,
    );
  });
  for (final dims in [
    (w: 0, h: 64),
    (w: 257, h: 64),
    (w: 64, h: 0),
    (w: 64, h: 257),
  ]) {
    test('invalid dimensions $dims are not inferred', () {
      expect(
        _check(catalog, depot, [], width: dims.w, height: dims.h),
        UnitResourceDistanceCatalogCheck.metadataUnavailable,
      );
    });
  }
  test('known unrelated out-of-map UNIT is not a distance participant', () {
    final snapshot = UnitResourceDistanceCatalog({0: depot, 2: _cap(2)});
    expect(
      _check(snapshot, depot, [_unit(2, 65535, 65535)]),
      UnitResourceDistanceCatalogCheck.clear,
    );
  });
  test(
    'gas, exhausted resources and other owners remain participants; bytes unchanged',
    () {
      final bytes = _unitBytes(1, 128, 128, owner: 11, amount: 0);
      final before = Uint8List.fromList(bytes);
      final snapshot = UnitResourceDistanceCatalog({
        0: depot,
        1: _cap(1, resource: true, gas: true),
      });
      final unit = _decode(bytes);
      expect(
        _check(snapshot, depot, [unit]),
        UnitResourceDistanceCatalogCheck.tooClose,
      );
      expect(bytes, orderedEquals(before));
      expect(unit.resourceAmount, 0);
      expect(unit.owner, 11);
    },
  );
  test('catalog freezes inputs and rejects mismatched keys', () {
    final input = {0: depot};
    final snapshot = UnitResourceDistanceCatalog(input);
    input.clear();
    expect(snapshot.units, hasLength(1));
    expect(() => snapshot.units.clear(), throwsUnsupportedError);
    expect(() => UnitResourceDistanceCatalog({1: depot}), throwsArgumentError);
  });
}

UnitResourceDistanceCatalogCheck _check(
  UnitResourceDistanceCatalog catalog,
  UnitPlacementCapability candidate,
  Iterable<ChkUnitPlacement> existing, {
  int x = 128,
  int y = 128,
  int width = 64,
  int height = 64,
}) => catalog.check(
  candidate: candidate,
  x: x,
  y: y,
  mapWidthTiles: width,
  mapHeightTiles: height,
  existing: existing,
);

UnitPlacementCapability _cap(
  int id, {
  bool depot = false,
  bool resource = false,
  bool gas = false,
  bool flyer = false,
  bool building = false,
  bool liftable = false,
  bool subunit = false,
  bool relation = false,
  bool missingRole = false,
  bool missingGeometry = false,
  int left = 0,
  int up = 0,
  int right = 0,
  int down = 0,
}) => UnitPlacementCapability(
  unitId: id,
  isSubunit: subunit,
  resourceProfile: missingRole
      ? null
      : UnitResourceProfile(isDepot: depot, isResource: resource),
  collisionProfile: missingGeometry
      ? null
      : UnitCollisionProfile(
          left: left,
          up: up,
          right: right,
          down: down,
          isFlyer: flyer,
        ),
  isBuilding: building,
  isFlyingBuilding: liftable,
  isSpellcaster: false,
  hasShields: false,
  isResourceContainer: resource,
  isGasResourceContainer: gas,
  hasHangar: false,
  isBurrowable: false,
  isCloakable: false,
  isInvincible: false,
  requiresRelationLink: relation,
);

ChkUnitPlacement _unit(int id, int x, int y, {int state = 0, int valid = 0}) =>
    _decode(_unitBytes(id, x, y, state: state, valid: valid));

Uint8List _unitBytes(
  int id,
  int x,
  int y, {
  int state = 0,
  int valid = 0,
  int owner = 0,
  int amount = 0,
}) {
  final bytes = Uint8List(8 + 36)..setRange(0, 4, 'UNIT'.codeUnits);
  ByteData.sublistView(bytes)
    ..setUint32(4, 36, Endian.little)
    ..setUint16(12, x, Endian.little)
    ..setUint16(14, y, Endian.little)
    ..setUint16(16, id, Endian.little)
    ..setUint16(20, valid, Endian.little)
    ..setUint8(24, owner)
    ..setUint32(28, amount, Endian.little)
    ..setUint16(34, state, Endian.little);
  return bytes;
}

ChkUnitPlacement _decode(Uint8List bytes) => const ChkObjectViewDecoder()
    .decode(const RawChkParser().parse(bytes).document!)
    .unitSections
    .single
    .units
    .single;
