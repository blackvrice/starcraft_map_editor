enum PlacementPolicyRule {
  recordSafety,
  buildingAlignment,
  unitOverlap,
  terrain,
  resourceDistance,
  power,
  creep,
  eudRuntime,
  gameAcceptance,
}

/// Policy/data availability only. None of these states certifies a coordinate.
enum PlacementPolicySupportStatus {
  enforced,
  enabled,
  skipped,
  notApplicable,
  loading,
  unavailable,
  notImplemented,
  acceptancePending,
}
