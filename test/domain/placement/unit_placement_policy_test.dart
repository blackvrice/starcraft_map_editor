import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/placement/unit_placement_policy.dart';

void main() {
  for (final terrain in [false, true]) {
    for (final overlap in [false, true]) {
      for (final resource in [false, true]) {
        test(
          'explicit layout power makes mode custom $terrain/$overlap/$resource',
          () {
            expect(
              UnitPlacementPolicy(
                checkTerrain: terrain,
                allowOverlap: overlap,
                checkResourceDistance: resource,
                checkPreplacedPower: true,
              ).mode,
              UnitPlacementMode.custom,
            );
          },
        );
        test(
          'policy derives actual mode terrain=$terrain overlap=$overlap resource=$resource',
          () {
            final policy = UnitPlacementPolicy(
              checkTerrain: terrain,
              allowOverlap: overlap,
              checkResourceDistance: resource,
            );
            expect(
              policy.mode,
              terrain && !overlap && resource
                  ? UnitPlacementMode.checked
                  : !terrain && overlap && !resource
                  ? UnitPlacementMode.free
                  : UnitPlacementMode.custom,
            );
          },
        );
      }
    }
  }
  test('presets require local checks or skip them explicitly', () {
    expect(UnitPlacementPolicy.checked.checkTerrain, isTrue);
    expect(UnitPlacementPolicy.checked.allowOverlap, isFalse);
    expect(UnitPlacementPolicy.checked.checkResourceDistance, isTrue);
    expect(UnitPlacementPolicy.free.checkTerrain, isFalse);
    expect(UnitPlacementPolicy.free.allowOverlap, isTrue);
    expect(UnitPlacementPolicy.free.checkResourceDistance, isFalse);
    expect(UnitPlacementPolicy.checked.checkPreplacedPower, isFalse);
    expect(UnitPlacementPolicy.free.checkPreplacedPower, isFalse);
  });
}
