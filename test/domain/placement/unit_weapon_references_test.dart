import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/placement/unit_weapon_references.dart';

void main() {
  test(
    'finds direct and transitive subunit references without duplicates or cycles',
    () {
      final units = List.generate(
        228,
        (_) => UnitWeaponReferences(
          ground: 130,
          air: 130,
          subunit1: 228,
          subunit2: 228,
        ),
      );
      units[7] = UnitWeaponReferences(
        ground: 5,
        air: 5,
        subunit1: 228,
        subunit2: 228,
      );
      units[8] = UnitWeaponReferences(
        ground: 130,
        air: 130,
        subunit1: 7,
        subunit2: 9,
      );
      units[9] = UnitWeaponReferences(
        ground: 130,
        air: 130,
        subunit1: 8,
        subunit2: 228,
      );
      units[10] = UnitWeaponReferences(
        ground: 130,
        air: 130,
        subunit1: 10,
        subunit2: 228,
      );
      final index = UnitWeaponIndex(units);
      expect(index.directUsers(5), [7]);
      expect(index.subunitUsers(5), [8, 9]);
      expect(index.directUsers(129), isEmpty);
      expect(index.subunitUsers(129), isEmpty);
      units.clear();
      expect(index.units, hasLength(228));
    },
  );
  test('rejects incomplete coverage and invalid IDs', () {
    expect(() => UnitWeaponIndex([]), throwsArgumentError);
    expect(
      () => UnitWeaponReferences(
        ground: 131,
        air: 0,
        subunit1: 228,
        subunit2: 228,
      ),
      throwsRangeError,
    );
    expect(
      () =>
          UnitWeaponReferences(ground: 0, air: 0, subunit1: 229, subunit2: 228),
      throwsRangeError,
    );
  });
}
