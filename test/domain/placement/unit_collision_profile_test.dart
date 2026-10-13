import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/placement/unit_collision_profile.dart';
import 'package:starcraft_map_editor/domain/placement/unit_placement_capability.dart';

void main() {
  test('asymmetric offsets preserve negative and large unclamped bounds', () {
    final profile = _profile(left: 3, up: 5, right: 7, down: 9);
    final bounds = profile.boundsAt(2, 4);
    expect(
      [bounds.left, bounds.top, bounds.right, bounds.bottom],
      [-1, -1, 9, 13],
    );
    final large = _profile(left: 65535, down: 65535).boundsAt(65535, 65535);
    expect(large.left, 0);
    expect(large.bottom, 131070);
  });

  test('zero offsets represent one closed pixel, not missing metadata', () {
    final profile = _profile();
    expect(profile.boundsAt(0, 0).overlaps(profile.boundsAt(0, 0)), isTrue);
    expect(profile.boundsAt(0, 0).overlaps(profile.boundsAt(1, 0)), isFalse);
  });

  test('closed bounds overlap symmetrically at edges and corners', () {
    final profile = _profile(left: 3, up: 5, right: 7, down: 9);
    final bounds = profile.boundsAt(10, 20);
    for (final point in [(7, 15), (17, 29), (7, 29), (17, 15), (10, 20)]) {
      final other = _profile().boundsAt(point.$1, point.$2);
      expect(bounds.overlaps(other), isTrue);
      expect(other.overlaps(bounds), isTrue);
    }
    for (final point in [(6, 20), (18, 20), (10, 14), (10, 30)]) {
      final other = _profile().boundsAt(point.$1, point.$2);
      expect(bounds.overlaps(other), isFalse);
      expect(other.overlaps(bounds), isFalse);
    }
  });

  for (final value in [-1, 65536]) {
    for (final field in ['left', 'up', 'right', 'down']) {
      test('rejects $field offset $value without narrowing', () {
        expect(
          () => _profile(
            left: field == 'left' ? value : 0,
            up: field == 'up' ? value : 0,
            right: field == 'right' ? value : 0,
            down: field == 'down' ? value : 0,
          ),
          throwsRangeError,
        );
      });
    }
  }

  test('unknown metadata is not a ground unit or inferred tile box', () {
    final capability = _capability();
    expect(capability.isAirborne(inTransit: false), isNull);
    expect(capability.isAirborne(inTransit: true), isNull);
  });

  test(
    'flight uses Flyer or building plus flying-building plus in-transit',
    () {
      for (final flyer in [false, true]) {
        for (final building in [false, true]) {
          for (final flyingBuilding in [false, true]) {
            final capability = _capability(
              profile: _profile(flyer: flyer),
              building: building,
              flyingBuilding: flyingBuilding,
            );
            for (final inTransit in [false, true]) {
              expect(
                capability.isAirborne(inTransit: inTransit),
                flyer || (building && flyingBuilding && inTransit),
              );
            }
          }
        }
      }
    },
  );
}

UnitCollisionProfile _profile({
  int left = 0,
  int up = 0,
  int right = 0,
  int down = 0,
  bool flyer = false,
}) => UnitCollisionProfile(
  left: left,
  up: up,
  right: right,
  down: down,
  isFlyer: flyer,
);

UnitPlacementCapability _capability({
  UnitCollisionProfile? profile,
  bool building = false,
  bool flyingBuilding = false,
}) => UnitPlacementCapability(
  unitId: 0,
  collisionProfile: profile,
  isBuilding: building,
  isFlyingBuilding: flyingBuilding,
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
