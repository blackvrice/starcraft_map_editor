import 'unit_weapon_references.dart';
import 'doodad_placement_recipe.dart';

/// The minimum verified `units.dat` capability snapshot required to synthesize
/// a default `UNIT` record for a unit that the current map does not contain.
///
/// Placement flags are derived booleans; optional weapon references are validated IDs.
/// Raw DAT bytes never cross the StarCraft
/// data helper boundary, and a capability that cannot be read is reported as an
/// item level issue instead of being guessed.
///
/// The field set matches the Chkdraft selection defaults recorded in
/// `docs/research/VISUAL_PLACEMENT_AND_CHK_RULES.md` section 3.2.
final class UnitPlacementCapability {
  UnitPlacementCapability({
    required this.unitId,
    this.weaponReferences,
    required this.isSpellcaster,
    required this.hasShields,
    required this.isResourceContainer,
    required this.isGasResourceContainer,
    required this.hasHangar,
    required this.isFlyingBuilding,
    required this.isBurrowable,
    required this.isCloakable,
    required this.isInvincible,
    required this.isBuilding,
    required this.requiresRelationLink,
  }) {
    if (unitId < 0 || unitId > maximumUnitId) {
      throw RangeError.range(unitId, 0, maximumUnitId, 'unitId');
    }
    if (isGasResourceContainer && !isResourceContainer) {
      throw ArgumentError(
        'A gas resource container must also be a resource container.',
      );
    }
  }

  /// The classic `units.dat` entry count shares its upper bound with the
  /// verified Doodad overlay unit range.
  static const maximumUnitId = DoodadOverlayRecipe.maximumUnitId;

  /// The resource amount Chkdraft assigns to a non gas resource container.
  static const mineralResourceAmount = 1500;

  /// The resource amount Chkdraft assigns to a vespene geyser, Terran
  /// refinery, Zerg extractor or Protoss assimilator.
  static const gasResourceAmount = 5000;

  final int unitId;
  final UnitWeaponReferences? weaponReferences;

  /// `Spellcaster` in `units.dat`. Marks the energy field as valid.
  final bool isSpellcaster;

  /// `shieldEnable != 0` in `units.dat`. Marks the shield field as valid.
  final bool hasShields;

  /// `ResourceContainer` in `units.dat`. Marks the resource field as valid.
  final bool isResourceContainer;

  /// A vespene geyser, Terran refinery, Zerg extractor or Protoss assimilator.
  final bool isGasResourceContainer;

  /// A Carrier or Reaver family unit. Marks the hangar field as valid.
  final bool hasHangar;

  /// `FlyingBuilding` in `units.dat`. Marks the in transit state as valid.
  final bool isFlyingBuilding;

  /// `Burrowable` in `units.dat`. Marks the burrow state as valid.
  final bool isBurrowable;

  /// `Cloakable` in `units.dat`. Marks the cloak state as valid.
  final bool isCloakable;

  /// `Invincible` in `units.dat`. Removes the invincible state from the valid
  /// state flags because the unit is already invincible.
  final bool isInvincible;

  /// `Building` in `units.dat`. A building is never marked hallucinated.
  final bool isBuilding;

  /// The unit needs an addon or Nydus relation to be meaningful. Synthesizing
  /// such a record is out of scope until the relation rules are verified.
  final bool requiresRelationLink;

  /// The verified default `resourceAmount` for a newly synthesized record.
  int get defaultResourceAmount {
    if (!isResourceContainer) {
      return 0;
    }
    return isGasResourceContainer ? gasResourceAmount : mineralResourceAmount;
  }
}
