enum UnitPlacementMode { checked, free, custom }

/// Runtime preferences for new catalog UNITs, not a game-validation profile.
final class UnitPlacementPolicy {
  const UnitPlacementPolicy({
    required this.checkTerrain,
    required this.allowOverlap,
  });

  static const checked = UnitPlacementPolicy(
    checkTerrain: true,
    allowOverlap: false,
  );
  static const free = UnitPlacementPolicy(
    checkTerrain: false,
    allowOverlap: true,
  );

  final bool checkTerrain;
  final bool allowOverlap;

  // Derive the mode from actual checks so individual toggles cannot leave a
  // stale preset label. Building alignment and coordinate safety are separate.
  UnitPlacementMode get mode => checkTerrain && !allowOverlap
      ? UnitPlacementMode.checked
      : !checkTerrain && allowOverlap
      ? UnitPlacementMode.free
      : UnitPlacementMode.custom;
}
