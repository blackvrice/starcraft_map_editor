enum UnitPlacementMode { checked, free, custom }

/// Runtime preferences for new catalog UNITs, not a game-validation profile.
final class UnitPlacementPolicy {
  const UnitPlacementPolicy({
    required this.checkTerrain,
    required this.allowOverlap,
    this.checkResourceDistance = false,
  });

  static const checked = UnitPlacementPolicy(
    checkTerrain: true,
    allowOverlap: false,
    checkResourceDistance: true,
  );
  static const free = UnitPlacementPolicy(
    checkTerrain: false,
    allowOverlap: true,
  );

  final bool checkTerrain;
  final bool allowOverlap;
  final bool checkResourceDistance;

  // Derive the mode from actual checks so individual toggles cannot leave a
  // stale preset label. Building alignment and coordinate safety are separate.
  UnitPlacementMode get mode =>
      checkTerrain && !allowOverlap && checkResourceDistance
      ? UnitPlacementMode.checked
      : !checkTerrain && allowOverlap && !checkResourceDistance
      ? UnitPlacementMode.free
      : UnitPlacementMode.custom;
}
