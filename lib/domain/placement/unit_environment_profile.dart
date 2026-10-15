/// Local classic DAT requirements, not power coverage or current creep.
/// Absence of this optional profile means unknown, not two false flags.
final class UnitEnvironmentProfile {
  const UnitEnvironmentProfile({
    required this.requiresPsi,
    required this.requiresCreep,
  });

  static const version = 1;

  /// DAT RequiredPsi (bit 19), independent of race or shield support.
  final bool requiresPsi;

  /// DAT CreepBuilding (bit 17); does not mean the unit produces creep.
  /// A false value does not authorize placing other buildings on creep.
  final bool requiresCreep;
}
