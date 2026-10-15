import 'package:starcraft_map_editor/domain/placement/unit_creep_observation.dart';

/// Synthetic declarations only. No engine or actual observation is involved.
UnitCreepObservation syntheticCreepObservation({
  int width = 32,
  int height = 32,
  String contractRevision = UnitCreepObservation.revision,
  String collectorVersion = 'synthetic-observer-v1',
  String gameVersion = 'synthetic-game-not-SCR',
  String gameSessionId = 'synthetic-game-session',
  String setupRevision = 'synthetic-setup',
  UnitCreepObservationPhase phase =
      UnitCreepObservationPhase.initializedBeforeFirstTriggerCycle,
  int simulationFrame = 0,
  int gameFrame = 17,
  UnitCreepObservationAuthority authority =
      UnitCreepObservationAuthority.fullMap,
  int? observerPlayer,
  List<bool>? observedTiles,
}) => UnitCreepObservation(
  contractRevision: contractRevision,
  collectorVersion: collectorVersion,
  gameVersion: gameVersion,
  gameSessionId: gameSessionId,
  setupRevision: setupRevision,
  phase: phase,
  gameFrame: gameFrame,
  simulationFrame: simulationFrame,
  authority: authority,
  observerPlayer: observerPlayer,
  width: width,
  height: height,
  observedTiles: observedTiles ?? List.filled(width * height, true),
);
