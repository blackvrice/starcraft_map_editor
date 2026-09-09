final class UnitWeaponReferences {
  UnitWeaponReferences({
    required this.ground,
    required this.air,
    required this.subunit1,
    required this.subunit2,
  }) {
    RangeError.checkValueInInterval(ground, 0, 130, 'ground');
    RangeError.checkValueInInterval(air, 0, 130, 'air');
    RangeError.checkValueInInterval(subunit1, 0, 228, 'subunit1');
    RangeError.checkValueInInterval(subunit2, 0, 228, 'subunit2');
  }
  final int ground;
  final int air;
  final int subunit1;
  final int subunit2;
}

/// Complete classic DAT reference coverage, not runtime/EUD attack behavior.
final class UnitWeaponIndex {
  UnitWeaponIndex(List<UnitWeaponReferences> units)
    : units = List.unmodifiable(units) {
    if (units.length != 228) throw ArgumentError('All 228 units are required.');
  }
  final List<UnitWeaponReferences> units;
  List<int> directUsers(int weapon) {
    RangeError.checkValueInInterval(weapon, 0, 129, 'weapon');
    return [
      for (var i = 0; i < units.length; i++)
        if (units[i].ground == weapon || units[i].air == weapon) i,
    ];
  }

  List<int> subunitUsers(int weapon) {
    final direct = directUsers(weapon).toSet();
    bool reaches(int unit, Set<int> visited) {
      if (unit == 228 || !visited.add(unit)) return false;
      if (direct.contains(unit)) return true;
      return reaches(units[unit].subunit1, visited) ||
          reaches(units[unit].subunit2, visited);
    }

    return [
      for (var i = 0; i < units.length; i++)
        if (!direct.contains(i) &&
            (reaches(units[i].subunit1, {i}) ||
                reaches(units[i].subunit2, {i})))
          i,
    ];
  }
}
