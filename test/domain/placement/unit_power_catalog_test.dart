import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/placement/building_placement_box.dart';
import 'package:starcraft_map_editor/domain/placement/unit_collision_profile.dart';
import 'package:starcraft_map_editor/domain/placement/unit_environment_profile.dart';
import 'package:starcraft_map_editor/domain/placement/unit_placement_capability.dart';
import 'package:starcraft_map_editor/domain/placement/unit_power_catalog.dart';
import 'package:starcraft_map_editor/domain/placement/unit_power_unit_state.dart';

void main() {
  final candidate = _cap(160);
  final pylon = _cap(156, psi: false, width: 64, height: 64);
  final catalog = UnitPowerCatalog({160: candidate, 156: pylon});
  final active = _state();
  test(
    'explicit active same-owner Pylon supplies; empty snapshot does not',
    () {
      expect(_check(catalog, candidate, [active]), UnitPowerCheck.powered);
      expect(_check(catalog, candidate, []), UnitPowerCheck.unpowered);
    },
  );
  for (final x in [768, 769, 1279, 1280]) {
    test('horizontal strict boundary x=$x', () {
      expect(
        _check(catalog, candidate, [active], x: x),
        x == 768 || x == 1280
            ? UnitPowerCheck.unpowered
            : UnitPowerCheck.powered,
      );
    });
  }
  for (final y in [864, 865, 1183, 1184]) {
    test('vertical strict boundary y=$y', () {
      expect(
        _check(catalog, candidate, [active], y: y),
        y == 864 || y == 1184
            ? UnitPowerCheck.unpowered
            : UnitPowerCheck.powered,
      );
    });
  }
  for (final mismatch in [
    _cap(160, psi: false),
    _cap(160, creep: true),
    _cap(160, building: false),
    _cap(160, subunit: true),
    _cap(160, flyingBuilding: true),
    _cap(160, relation: true),
    _cap(160, width: 64),
    _cap(160, height: 64),
    _cap(160, flyer: true),
    _cap(160, missingRole: true),
    _cap(160, missingBox: true),
    _cap(160, missingGeometry: true),
  ].indexed) {
    test('candidate source facts must agree ${mismatch.$1}', () {
      expect(
        _check(UnitPowerCatalog({160: mismatch.$2}), candidate, []),
        UnitPowerCheck.unavailable,
      );
    });
  }
  test('missing candidate snapshot and requirements remain unknown', () {
    expect(
      _check(UnitPowerCatalog({}), candidate, []),
      UnitPowerCheck.unavailable,
    );
    final cap = _cap(160, missingRole: true);
    expect(
      _check(UnitPowerCatalog({160: cap}), cap, []),
      UnitPowerCheck.unavailable,
    );
  });
  test(
    'confirmed no-psi is rule N/A, not a general placement authorization',
    () {
      final cap = _cap(
        0,
        psi: false,
        building: false,
        missingBox: true,
        missingGeometry: true,
      );
      expect(
        _check(UnitPowerCatalog({0: cap}), cap, [_state(id: 300)], width: 0),
        UnitPowerCheck.notApplicable,
      );
    },
  );
  for (final cap in [
    _cap(160, building: false),
    _cap(160, subunit: true),
    _cap(160, flyingBuilding: true),
    _cap(160, relation: true),
    _cap(160, flyer: true),
  ]) {
    test(
      'custom candidate state is unsupported ${cap.isBuilding}/${cap.isSubunit}/${cap.isFlyingBuilding}/${cap.requiresRelationLink}/${cap.collisionProfile!.isFlyer}',
      () {
        expect(
          _check(UnitPowerCatalog({160: cap}), cap, []),
          UnitPowerCheck.stateUnsupported,
        );
      },
    );
  }
  for (final dims in [
    (w: 0, h: 64),
    (w: 257, h: 64),
    (w: 64, h: 0),
    (w: 64, h: 257),
  ]) {
    test('invalid DIM $dims stays unknown', () {
      expect(
        _check(catalog, candidate, [], width: dims.w, height: dims.h),
        UnitPowerCheck.unavailable,
      );
    });
  }
  for (final x in [-1, 63, 1985, 2048, 0x7fffffffffffffff]) {
    test('candidate whole StarEdit box, not center alone, at x=$x', () {
      expect(_check(catalog, candidate, [], x: x), UnitPowerCheck.outOfBounds);
    });
  }
  test(
    'other players do not supply; allied and neutral supply is not inferred',
    () {
      expect(
        _check(catalog, candidate, [_state(owner: 1)]),
        UnitPowerCheck.unpowered,
      );
      expect(
        _check(catalog, candidate, [_state(owner: 11)]),
        UnitPowerCheck.stateUnsupported,
      );
      expect(
        _check(catalog, candidate, [_state(validOwner: false)]),
        UnitPowerCheck.stateUnsupported,
      );
      expect(
        _check(catalog, candidate, [active], owner: 8),
        UnitPowerCheck.stateUnsupported,
      );
      expect(
        _check(catalog, candidate, [active], owner: -1),
        UnitPowerCheck.stateUnsupported,
      );
    },
  );
  test('nonproviders and known foreign owner need no completion guesses', () {
    final snapshot = UnitPowerCatalog({
      160: candidate,
      156: pylon,
      0: _cap(0, psi: false, building: false),
    });
    expect(
      _check(snapshot, candidate, [
        UnitPowerUnitState(_unit(0)),
        UnitPowerUnitState(_unit(156, owner: 1)),
      ]),
      UnitPowerCheck.unpowered,
    );
  });
  for (final unknown in ['exists', 'completed', 'enabled']) {
    test('unknown provider $unknown cannot be promoted to powered', () {
      final state = UnitPowerUnitState(
        _unit(156),
        exists: unknown == 'exists' ? null : true,
        isCompleted: unknown == 'completed' ? null : true,
        isEnabled: unknown == 'enabled' ? null : true,
      );
      for (final order in [
        [active, state],
        [state, active],
      ]) {
        expect(_check(catalog, candidate, order), UnitPowerCheck.unavailable);
      }
    });
  }
  test('bare CHK has no inferred completion/activation state', () {
    expect(
      _check(catalog, candidate, [UnitPowerUnitState(_unit(156))]),
      UnitPowerCheck.unavailable,
    );
    expect(
      _check(catalog, candidate, [
        UnitPowerUnitState(_unit(156), exists: false),
      ]),
      UnitPowerCheck.unpowered,
    );
    expect(
      _check(catalog, candidate, [
        UnitPowerUnitState(_unit(156), isCompleted: false),
      ]),
      UnitPowerCheck.unpowered,
    );
  });
  for (final missing in ['entry', 'role', 'box', 'geometry', 'subunit']) {
    test('unknown metadata $missing cannot be hidden by known supply', () {
      final snapshot = UnitPowerCatalog({
        160: candidate,
        if (missing != 'entry')
          156: _cap(
            156,
            psi: false,
            width: 64,
            height: 64,
            missingRole: missing == 'role',
            missingBox: missing == 'box',
            missingGeometry: missing == 'geometry',
            subunit: missing == 'subunit',
          ),
      });
      expect(_check(snapshot, candidate, [active]), UnitPowerCheck.unavailable);
    });
  }
  for (final flag in [1, 2, 4, 8, 32]) {
    test('custom provider raw state $flag is unsupported', () {
      expect(
        _check(catalog, candidate, [_state(flags: flag)]),
        UnitPowerCheck.stateUnsupported,
      );
    });
  }
  test('disabled, unknown valid bits and relation data are unsupported', () {
    for (final state in [
      _state(enabled: false),
      _state(validState: 32),
      _state(relation: 1),
      _state(relationId: 1),
      _state(flags: 16),
    ]) {
      expect(
        _check(catalog, candidate, [state]),
        UnitPowerCheck.stateUnsupported,
      );
    }
    expect(
      _check(catalog, candidate, [_state(flags: 16, validState: 16)]),
      UnitPowerCheck.powered,
    );
  });
  for (final source in [
    _cap(156, psi: true, width: 64, height: 64),
    _cap(156, psi: false, creep: true, width: 64, height: 64),
    _cap(156, psi: false, building: false, width: 64, height: 64),
    _cap(156, psi: false, flyer: true, width: 64, height: 64),
    _cap(156, psi: false, flyingBuilding: true, width: 64, height: 64),
    _cap(156, psi: false, relation: true, width: 64, height: 64),
    _cap(156, psi: false, width: 96, height: 64),
  ].indexed) {
    test('unsupported classic supplier profile ${source.$1}', () {
      expect(
        _check(UnitPowerCatalog({160: candidate, 156: source.$2}), candidate, [
          active,
        ]),
        UnitPowerCheck.stateUnsupported,
      );
    });
  }
  test('unknown > unsupported > bounds > supply is order independent', () {
    final bad = _state(flags: 8);
    final outside = _state(x: 0);
    final unknown = _state(id: 300);
    for (final states in [
      [active, bad, outside, unknown],
      [unknown, outside, bad, active],
    ]) {
      expect(_check(catalog, candidate, states), UnitPowerCheck.unavailable);
    }
    for (final states in [
      [active, outside, bad],
      [bad, outside, active],
    ]) {
      expect(
        _check(catalog, candidate, states),
        UnitPowerCheck.stateUnsupported,
      );
    }
    for (final states in [
      [active, outside],
      [outside, active],
    ]) {
      expect(_check(catalog, candidate, states), UnitPowerCheck.outOfBounds);
    }
  });
  test('record bytes stay unchanged and catalog input is immutable', () {
    final bytes = _bytes(156);
    final before = Uint8List.fromList(bytes);
    final map = {160: candidate, 156: pylon};
    final snapshot = UnitPowerCatalog(map);
    map.clear();
    expect(
      _check(snapshot, candidate, [
        UnitPowerUnitState(
          _decode(bytes),
          exists: true,
          isCompleted: true,
          isEnabled: true,
        ),
      ]),
      UnitPowerCheck.powered,
    );
    expect(bytes, orderedEquals(before));
    expect(() => snapshot.units.clear(), throwsUnsupportedError);
    expect(() => UnitPowerCatalog({0: candidate}), throwsArgumentError);
  });
}

UnitPowerCheck _check(
  UnitPowerCatalog catalog,
  UnitPlacementCapability candidate,
  Iterable<UnitPowerUnitState> states, {
  int x = 1024,
  int y = 1024,
  int owner = 0,
  int width = 64,
  int height = 64,
}) => catalog.check(
  candidate: candidate,
  owner: owner,
  x: x,
  y: y,
  mapWidthTiles: width,
  mapHeightTiles: height,
  existing: states,
);

UnitPlacementCapability _cap(
  int id, {
  bool psi = true,
  bool creep = false,
  bool building = true,
  bool flyer = false,
  bool subunit = false,
  bool flyingBuilding = false,
  bool relation = false,
  int width = 128,
  int height = 96,
  bool missingRole = false,
  bool missingBox = false,
  bool missingGeometry = false,
}) => UnitPlacementCapability(
  unitId: id,
  isSubunit: subunit,
  environmentProfile: missingRole
      ? null
      : UnitEnvironmentProfile(requiresPsi: psi, requiresCreep: creep),
  placementBox: missingBox
      ? null
      : BuildingPlacementBox(width: width, height: height),
  collisionProfile: missingGeometry
      ? null
      : UnitCollisionProfile(left: 0, up: 0, right: 0, down: 0, isFlyer: flyer),
  isBuilding: building,
  isFlyingBuilding: flyingBuilding,
  requiresRelationLink: relation,
  isSpellcaster: false,
  hasShields: false,
  isResourceContainer: false,
  isGasResourceContainer: false,
  hasHangar: false,
  isBurrowable: false,
  isCloakable: false,
  isInvincible: false,
);

UnitPowerUnitState _state({
  int id = 156,
  int x = 1024,
  int owner = 0,
  bool validOwner = true,
  int flags = 0,
  int validState = 0,
  bool enabled = true,
  int relation = 0,
  int relationId = 0,
}) => UnitPowerUnitState(
  _unit(
    id,
    x: x,
    owner: owner,
    validOwner: validOwner,
    flags: flags,
    validState: validState,
    relation: relation,
    relationId: relationId,
  ),
  exists: true,
  isCompleted: true,
  isEnabled: enabled,
);

ChkUnitPlacement _unit(
  int id, {
  int x = 1024,
  int owner = 0,
  bool validOwner = true,
  int flags = 0,
  int validState = 0,
  int relation = 0,
  int relationId = 0,
}) => _decode(
  _bytes(
    id,
    x: x,
    owner: owner,
    validOwner: validOwner,
    flags: flags,
    validState: validState,
    relation: relation,
    relationId: relationId,
  ),
);

Uint8List _bytes(
  int id, {
  int x = 1024,
  int owner = 0,
  bool validOwner = true,
  int flags = 0,
  int validState = 0,
  int relation = 0,
  int relationId = 0,
}) {
  final bytes = Uint8List(44)..setRange(0, 4, 'UNIT'.codeUnits);
  ByteData.sublistView(bytes)
    ..setUint32(4, 36, Endian.little)
    ..setUint16(12, x, Endian.little)
    ..setUint16(14, 1024, Endian.little)
    ..setUint16(16, id, Endian.little)
    ..setUint16(18, relation, Endian.little)
    ..setUint16(20, validState, Endian.little)
    ..setUint16(22, validOwner ? 1 : 0, Endian.little)
    ..setUint8(24, owner)
    ..setUint16(34, flags, Endian.little)
    ..setUint32(40, relationId, Endian.little);
  return bytes;
}

ChkUnitPlacement _decode(Uint8List bytes) => const ChkObjectViewDecoder()
    .decode(const RawChkParser().parse(bytes).document!)
    .unitSections
    .single
    .units
    .single;
