typedef UnitWeaponLink = ({int unit, int weapon, bool air});

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

  /// Direct slots followed by each reachable subunit once, in DAT order.
  List<UnitWeaponLink> weaponLinks(int unit) {
    RangeError.checkValueInInterval(unit, 0, 227, 'unit');
    final links = <UnitWeaponLink>[];
    final visited = <int>{};
    void visit(int id) {
      if (id == 228 || !visited.add(id)) return;
      final ref = units[id];
      if (ref.ground < 130) {
        links.add((unit: id, weapon: ref.ground, air: false));
      }
      if (ref.air < 130) links.add((unit: id, weapon: ref.air, air: true));
      visit(ref.subunit1);
      visit(ref.subunit2);
    }

    visit(unit);
    return List.unmodifiable(links);
  }

  /// Prefer direct ground/air, then subunits in DAT order; stop on cycles.
  ({int unit, int weapon})? preferredWeapon(int unit) {
    final links = weaponLinks(unit);
    return links.isEmpty
        ? null
        : (unit: links.first.unit, weapon: links.first.weapon);
  }

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
