import 'package:starcraft_map_editor/domain/placement/unit_weapon_references.dart';

UnitWeaponIndex impactReferences() {
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
    ground: 5,
    air: 5,
    subunit1: 228,
    subunit2: 228,
  );
  units[1] = UnitWeaponReferences(
    ground: 130,
    air: 5,
    subunit1: 228,
    subunit2: 228,
  );
  units[2] = UnitWeaponReferences(
    ground: 130,
    air: 130,
    subunit1: 0,
    subunit2: 3,
  );
  units[3] = UnitWeaponReferences(
    ground: 130,
    air: 130,
    subunit1: 2,
    subunit2: 228,
  );
  return UnitWeaponIndex(units);
}
