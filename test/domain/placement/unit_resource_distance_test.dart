import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/placement/unit_collision_profile.dart';
import 'package:starcraft_map_editor/domain/placement/unit_resource_distance.dart';
import 'package:starcraft_map_editor/domain/placement/unit_resource_profile.dart';

const _depot = UnitResourceProfile(isDepot: true, isResource: false);
const _resource = UnitResourceProfile(isDepot: false, isResource: true);
const _neither = UnitResourceProfile(isDepot: false, isResource: false);
const _both = UnitResourceProfile(isDepot: true, isResource: true);

UnitCollisionBounds _bounds(
  int x,
  int y, {
  int left = 0,
  int up = 0,
  int right = 0,
  int down = 0,
}) => UnitCollisionProfile(
  left: left,
  up: up,
  right: right,
  down: down,
  isFlyer: false,
).boundsAt(x, y);

void main() {
  final roles = [_neither, _depot, _resource, _both];
  for (var c = 0; c < roles.length; c++) {
    for (var o = 0; o < roles.length; o++) {
      test(
        'distance roles candidate=$c other=$o preserve depot-first priority',
        () {
          final candidate = roles[c], other = roles[o];
          final applies = candidate.isDepot
              ? other.isResource
              : candidate.isResource && other.isDepot;
          expect(
            UnitResourceDistance.checkPair(
              candidateRole: candidate,
              existingRole: other,
              candidateBounds: _bounds(160, 160),
              existingBounds: _bounds(160, 160),
              mapWidthTiles: 16,
              mapHeightTiles: 16,
            ),
            applies
                ? UnitResourceDistanceCheck.tooClose
                : UnitResourceDistanceCheck.notApplicable,
          );
        },
      );
    }
  }
  for (final swap in [false, true]) {
    for (final delta in [95, 96, 127, 128, 159]) {
      test(
        'closed projected tiles, not pixel radius delta=$delta swap=$swap',
        () {
          final a = _bounds(160 + delta, 160), b = _bounds(160, 160);
          expect(
            UnitResourceDistance.checkPair(
              candidateRole: swap ? _resource : _depot,
              existingRole: swap ? _depot : _resource,
              candidateBounds: a,
              existingBounds: b,
              mapWidthTiles: 16,
              mapHeightTiles: 16,
            ),
            delta < 128
                ? UnitResourceDistanceCheck.tooClose
                : UnitResourceDistanceCheck.clear,
          );
        },
      );
    }
  }
  for (final direction in [
    (1, 0),
    (-1, 0),
    (0, 1),
    (0, -1),
    (1, 1),
    (-1, -1),
  ]) {
    for (final gap in [96, 128]) {
      test('rectangular tile buffer direction=$direction gap=$gap', () {
        expect(
          UnitResourceDistance.checkPair(
            candidateRole: _depot,
            existingRole: _resource,
            candidateBounds: _bounds(
              160 + direction.$1 * gap,
              160 + direction.$2 * gap,
            ),
            existingBounds: _bounds(160, 160),
            mapWidthTiles: 16,
            mapHeightTiles: 16,
          ),
          gap == 96
              ? UnitResourceDistanceCheck.tooClose
              : UnitResourceDistanceCheck.clear,
        );
      });
    }
  }
  for (final right in [31, 32]) {
    test('whole collision extent crosses one tile at right=$right', () {
      expect(
        UnitResourceDistance.checkPair(
          candidateRole: _depot,
          existingRole: _resource,
          candidateBounds: _bounds(
            224,
            160,
            left: 2,
            up: 7,
            right: right,
            down: 8,
          ),
          existingBounds: _bounds(352, 160),
          mapWidthTiles: 16,
          mapHeightTiles: 16,
        ),
        right == 31
            ? UnitResourceDistanceCheck.clear
            : UnitResourceDistanceCheck.tooClose,
      );
    });
  }
  for (final kind in [
    'candidate-role',
    'other-role',
    'candidate-bounds',
    'other-bounds',
    'width',
    'height',
    'oversize',
  ]) {
    test('relevant pair with unavailable $kind stays unknown', () {
      expect(
        UnitResourceDistance.checkPair(
          candidateRole: kind == 'candidate-role' ? null : _depot,
          existingRole: kind == 'other-role' ? null : _resource,
          candidateBounds: kind == 'candidate-bounds'
              ? null
              : _bounds(160, 160),
          existingBounds: kind == 'other-bounds' ? null : _bounds(160, 160),
          mapWidthTiles: kind == 'width'
              ? 0
              : kind == 'oversize'
              ? 257
              : 16,
          mapHeightTiles: kind == 'height' ? -1 : 16,
        ),
        UnitResourceDistanceCheck.unavailable,
      );
    });
  }
  for (final point in [(-1, 160), (512, 160), (160, -1), (160, 512)]) {
    for (final existingOutside in [false, true]) {
      test(
        'entire footprint outside $point existing=$existingOutside is not clamped',
        () {
          final outside = _bounds(point.$1, point.$2);
          expect(
            UnitResourceDistance.checkPair(
              candidateRole: _depot,
              existingRole: _resource,
              candidateBounds: existingOutside ? _bounds(160, 160) : outside,
              existingBounds: existingOutside ? outside : _bounds(160, 160),
              mapWidthTiles: 16,
              mapHeightTiles: 16,
            ),
            UnitResourceDistanceCheck.outOfBounds,
          );
        },
      );
    }
  }
  test('legal map edges and 256-tile final pixel are supported', () {
    for (final point in [0, 8191]) {
      expect(
        UnitResourceDistance.checkPair(
          candidateRole: _depot,
          existingRole: _resource,
          candidateBounds: _bounds(point, point),
          existingBounds: _bounds(point, point),
          mapWidthTiles: 256,
          mapHeightTiles: 256,
        ),
        UnitResourceDistanceCheck.tooClose,
      );
    }
    expect(
      UnitResourceDistance.checkPair(
        candidateRole: _depot,
        existingRole: _resource,
        candidateBounds: _bounds(8191, 8191, right: 1),
        existingBounds: _bounds(8191, 8191),
        mapWidthTiles: 256,
        mapHeightTiles: 256,
      ),
      UnitResourceDistanceCheck.outOfBounds,
    );
  });
  test('unknown and confirmed irrelevant roles are different', () {
    for (final role in [_neither, _depot]) {
      expect(
        UnitResourceDistance.checkPair(
          candidateRole: role,
          existingRole: role == _neither ? null : _neither,
          candidateBounds: null,
          existingBounds: null,
          mapWidthTiles: 0,
          mapHeightTiles: 0,
        ),
        UnitResourceDistanceCheck.notApplicable,
      );
    }
  });
}
