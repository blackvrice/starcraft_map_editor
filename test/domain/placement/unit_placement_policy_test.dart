import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/placement/unit_placement_policy.dart';

void main() {
  for (final terrain in [false, true]) {
    for (final overlap in [false, true]) {
      test('policy derives actual mode terrain=$terrain overlap=$overlap', () {
        final policy = UnitPlacementPolicy(
          checkTerrain: terrain,
          allowOverlap: overlap,
        );
        expect(
          policy.mode,
          terrain && !overlap
              ? UnitPlacementMode.checked
              : !terrain && overlap
              ? UnitPlacementMode.free
              : UnitPlacementMode.custom,
        );
      });
    }
  }
  test('presets require local checks or skip them explicitly', () {
    expect(UnitPlacementPolicy.checked.checkTerrain, isTrue);
    expect(UnitPlacementPolicy.checked.allowOverlap, isFalse);
    expect(UnitPlacementPolicy.free.checkTerrain, isFalse);
    expect(UnitPlacementPolicy.free.allowOverlap, isTrue);
  });
}
