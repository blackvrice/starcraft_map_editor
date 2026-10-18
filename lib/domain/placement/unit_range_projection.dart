import '../chk/typed/chk_object_views.dart';
import '../eud/eud_dat_snapshot.dart';
import 'unit_weapon_references.dart';

enum UnitRangeKind { sight, ground, air }

final class UnitRangeRing {
  const UnitRangeRing({
    required this.x,
    required this.y,
    required this.kind,
    required this.minimum,
    required this.maximum,
    required this.sourceUnit,
    this.weapon,
  });
  final int x, y, minimum, maximum, sourceUnit;
  final int? weapon;
  final UnitRangeKind kind;
}

/// Static DAT geometry only: no upgrades, UNIS/EUD overrides, target size,
/// terrain line of sight, projectile behavior or live state is inferred.
final class UnitRangeProjection {
  UnitRangeProjection._(
    List<UnitRangeRing> rings,
    this.unknownUnits,
    this.selectionLimitExceeded,
  ) : rings = List.unmodifiable(rings);
  static const maximumUnits = 64;
  static const maximumRings = 512;
  static const maximumRadius = 8192;
  final List<UnitRangeRing> rings;
  final int unknownUnits;
  final bool selectionLimitExceeded;

  factory UnitRangeProjection.fromDat({
    required EudDatSnapshot? dat,
    required Iterable<ChkUnitPlacement> selected,
    required int mapWidth,
    required int mapHeight,
  }) {
    final units = selected.take(maximumUnits + 1).toList();
    if (units.length > maximumUnits) {
      return UnitRangeProjection._(const [], units.length, true);
    }
    if (dat == null ||
        mapWidth < 1 ||
        mapWidth > 256 ||
        mapHeight < 1 ||
        mapHeight > 256) {
      return UnitRangeProjection._(const [], units.length, false);
    }
    final rings = <UnitRangeRing>[];
    var unknown = 0;
    // The index follows both subunit links and terminates on cycles/sentinels.
    final UnitWeaponIndex index;
    try {
      index = dat.weaponIndex();
    } on ArgumentError {
      return UnitRangeProjection._(const [], units.length, false);
    }
    for (final unit in units) {
      if (unit.unitType > 227 ||
          unit.x >= mapWidth * 32 ||
          unit.y >= mapHeight * 32) {
        unknown++;
        continue;
      }
      var incomplete = false;
      final sight = dat.raw('unit.sightRange', unit.unitType);
      if (sight == null || sight * 32 > maximumRadius) {
        incomplete = true;
      } else if (sight > 0) {
        rings.add(
          UnitRangeRing(
            x: unit.x,
            y: unit.y,
            kind: UnitRangeKind.sight,
            minimum: 0,
            maximum: sight * 32,
            sourceUnit: unit.unitType,
          ),
        );
      }
      for (final link in index.weaponLinks(unit.unitType)) {
        final min = dat.raw('weapon.minRange', link.weapon);
        final max = dat.raw('weapon.maxRange', link.weapon);
        if (min == null || max == null || min > max || max > maximumRadius) {
          incomplete = true;
          continue;
        }
        if (max == 0) continue;
        rings.add(
          UnitRangeRing(
            x: unit.x,
            y: unit.y,
            kind: link.air ? UnitRangeKind.air : UnitRangeKind.ground,
            minimum: min,
            maximum: max,
            sourceUnit: link.unit,
            weapon: link.weapon,
          ),
        );
      }
      if (incomplete) unknown++;
      if (rings.length > maximumRings) {
        return UnitRangeProjection._(const [], units.length, true);
      }
    }
    return UnitRangeProjection._(rings, unknown, false);
  }
}
