import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/placement/unit_weapon_references.dart';

void main() {
  test(
    'lists all slots through diamond and cyclic subunits in stable order',
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
      units[0] = UnitWeaponReferences(
        ground: 1,
        air: 2,
        subunit1: 1,
        subunit2: 2,
      );
      units[1] = UnitWeaponReferences(
        ground: 3,
        air: 4,
        subunit1: 3,
        subunit2: 0,
      );
      units[2] = UnitWeaponReferences(
        ground: 130,
        air: 5,
        subunit1: 3,
        subunit2: 228,
      );
      units[3] = UnitWeaponReferences(
        ground: 6,
        air: 6,
        subunit1: 1,
        subunit2: 228,
      );
      final index = UnitWeaponIndex(units);
      final links = index.weaponLinks(0);
      expect(links, [
        (unit: 0, weapon: 1, air: false),
        (unit: 0, weapon: 2, air: true),
        (unit: 1, weapon: 3, air: false),
        (unit: 1, weapon: 4, air: true),
        (unit: 3, weapon: 6, air: false),
        (unit: 3, weapon: 6, air: true),
        (unit: 2, weapon: 5, air: true),
      ]);
      expect(index.preferredWeapon(0), (unit: 0, weapon: 1));
      expect(index.weaponLinks(4), isEmpty);
      expect(() => links.clear(), throwsUnsupportedError);
      expect(() => index.weaponLinks(228), throwsRangeError);
    },
  );
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
      expect(index.preferredWeapon(7), (unit: 7, weapon: 5));
      expect(index.preferredWeapon(9), (unit: 7, weapon: 5));
      expect(index.preferredWeapon(10), isNull);
      expect(() => index.preferredWeapon(228), throwsRangeError);
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
