import 'unit_creep_coverage.dart';

enum UnitCreepObservationPhase {
  initializedBeforeFirstTriggerCycle,
  running,
  unknown,
}

enum UnitCreepObservationAuthority { fullMap, playerVision, unverified }

/// Collector-declared evidence, not proof of SC:R compatibility or authority.
/// A real adapter must verify its phase mapping, game build, setup and visibility.
final class UnitCreepObservation {
  UnitCreepObservation({
    required this.contractRevision,
    required this.collectorVersion,
    required this.gameVersion,
    required this.gameSessionId,
    required this.setupRevision,
    required this.phase,
    required this.gameFrame,
    required this.simulationFrame,
    required this.authority,
    required this.width,
    required this.height,
    required List<bool> observedTiles,
    this.observerPlayer,
  }) : observedTiles = List.unmodifiable(observedTiles) {
    if ([
          contractRevision,
          collectorVersion,
          gameVersion,
          gameSessionId,
          setupRevision,
        ].any(
          (value) =>
              value.trim().isEmpty ||
              value.length > 256 ||
              value.codeUnits.any((v) => v < 32 || (v >= 127 && v <= 159)),
        ) ||
        gameFrame < 0 ||
        gameFrame > maximumFrame ||
        simulationFrame < 0 ||
        simulationFrame > maximumFrame ||
        width < 1 ||
        width > 256 ||
        height < 1 ||
        height > 256 ||
        this.observedTiles.length != width * height ||
        (authority == UnitCreepObservationAuthority.playerVision
            ? observerPlayer == null ||
                  observerPlayer! < 0 ||
                  observerPlayer! > 11
            : observerPlayer != null)) {
      throw ArgumentError('Invalid creep observation metadata or coverage.');
    }
  }

  static const revision = 'initial-creep-observation-v1';
  // Input budgets, not claims about engine frame numbering or duration.
  static const maximumFrame = 0xffffffff;
  final String contractRevision, collectorVersion, gameVersion;
  final String gameSessionId, setupRevision;
  final UnitCreepObservationPhase phase;
  final int gameFrame, simulationFrame;
  final UnitCreepObservationAuthority authority;
  final int? observerPlayer;
  final int width, height;
  final List<bool> observedTiles;

  /// simulationFrame counts steps after initialization; raw gameFrame may differ.
  bool get isInitialMapObservation =>
      contractRevision == revision &&
      phase == UnitCreepObservationPhase.initializedBeforeFirstTriggerCycle &&
      simulationFrame == 0 &&
      authority != UnitCreepObservationAuthority.unverified;

  /// Apply once at intake, not on each cursor query. Unobserved false is unknown,
  /// and even a full-map authority must explicitly mark sampled tiles.
  UnitCreepCoverage? restrictCoverage(UnitCreepCoverage coverage) {
    if (width != coverage.width || height != coverage.height) return null;
    if (observedTiles.every((observed) => observed)) return coverage;
    return UnitCreepCoverage(
      width: width,
      height: height,
      tiles: [
        for (var i = 0; i < observedTiles.length; i++)
          observedTiles[i] ? coverage.tiles[i] : UnitCreepTile.unknown,
      ],
    );
  }
}
