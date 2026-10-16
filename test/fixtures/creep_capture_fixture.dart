import 'dart:async';
import 'package:starcraft_map_editor/application/documents/opened_map_session.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/application/ports/unit_creep_capture_gateway.dart';
import 'package:starcraft_map_editor/application/ports/unit_creep_state_gateway.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';
import 'package:starcraft_map_editor/domain/placement/unit_creep_coverage.dart';
import 'package:starcraft_map_editor/domain/placement/unit_creep_observation.dart';
import 'package:starcraft_map_editor/infrastructure/placement/unit_creep_capture_input.dart';
import 'basic_editing_fixture.dart';
import 'creep_observation_fixture.dart';

UnitCreepCaptureConfiguration syntheticCaptureConfiguration({
  List<int> setupBytes = const [1, 2, 3],
  String setupSchema = 'synthetic-setup-v1',
  int maximumChkBytes = UnitCreepCaptureInput.maximumChkBytes,
  int maximumResourceBytes = UnitCreepCaptureInput.maximumResourceBytes,
  int maximumResourceEntryBytes = 16 * 1024 * 1024,
}) => UnitCreepCaptureConfiguration(
  providerId: 'synthetic-capture',
  collectorVersion: 'synthetic-observer-v1',
  gameSessionId: 'synthetic-game-session',
  setupSchema: setupSchema,
  supportedGameVersions: {'synthetic-game-not-SCR'},
  setupBytes: setupBytes,
  maximumChkBytes: maximumChkBytes,
  maximumResourceBytes: maximumResourceBytes,
  maximumResourceEntryBytes: maximumResourceEntryBytes,
);

UnitCreepStateRequest syntheticCaptureStateRequest({
  RawChkDocument? document,
  RawChkDocument? baseline,
  Map<String, List<int>?> resources = const {},
  String? archiveHash,
  String sourcePath = r'C:\maps\input.scx',
  int archiveSize = 100,
  DateTime? modified,
  String operationId = 'capture-test',
  int documentRevision = 1,
  String installationPath = r'C:\StarCraft',
  UnitCreepDataIdentity dataIdentity = ('s1', 13515, 'helper', 'CascLib'),
  UnitCreepStateModel model = UnitCreepStateModel.initialMap,
  bool restricted = false,
}) {
  final doc = document ?? basicDocument();
  final bytes = const RawChkEncoder().encode(baseline ?? doc);
  final session = OpenedMapSession(
    extractedMap: archiveHash == null
        ? ExtractedMap.inMemory(scenarioChkBytes: bytes)
        : ExtractedMap(
            sourcePath: sourcePath,
            scenarioChkBytes: bytes,
            metadata: MapArchiveMetadata(
              archiveSizeBytes: archiveSize,
              formatVersion: 1,
              totalEntryCount: 1,
              entries: [
                MapArchiveEntryMetadata(
                  path: MapArchiveEntryPaths.scenarioChk,
                  uncompressedSizeBytes: bytes.length,
                  compressedSizeBytes: bytes.length,
                  flags: 0,
                  locale: 0,
                  nameIsSynthetic: false,
                ),
              ],
              listingComplete: true,
            ),
          ),
    rawDocument: doc,
    metadataViews: const ChkMetadataViewDecoder().decode(doc),
    stringViews: const ChkStringViewDecoder().decode(doc),
    terrainViews: const ChkTerrainViewDecoder().decode(doc),
    objectViews: const ChkObjectViewDecoder().decode(doc),
    sourceFingerprint: archiveHash == null
        ? null
        : MapFileFingerprint(
            sizeBytes: archiveSize,
            modifiedAt: modified ?? DateTime.utc(2026),
            sha256Digest: archiveHash,
          ),
    diagnostics: [
      if (restricted)
        const EditorDiagnostic(
          code: 'SYNTHETIC_RESTRICTED',
          message: 'Synthetic restricted input',
          severity: DiagnosticSeverity.error,
          stage: DiagnosticStage.validate,
        ),
    ],
    resourceEdits: resources,
  );
  return UnitCreepStateRequest(
    operationId: operationId,
    session: session,
    documentRevision: documentRevision,
    installationPath: installationPath,
    dataIdentity: dataIdentity,
    model: model,
  );
}

/// No game or process is executed. Every report and version is synthetic.
final class SyntheticCreepCaptureGateway implements UnitCreepCaptureGateway {
  String? failure;
  bool hold = false;
  String? cancelFailure;
  bool visible = true;
  int frame = 17;
  UnitCreepTile fill = UnitCreepTile.present;
  final requests = <UnitCreepCaptureRequest>[];
  final cancelled = <UnitCreepCaptureRequest>[];
  final _pending = <UnitCreepCaptureRequest, Completer<void>>{};

  void release(UnitCreepCaptureRequest request) =>
      _pending.remove(request)!.complete();
  void releaseAll() {
    for (final request in _pending.keys.toList()) {
      release(request);
    }
  }

  @override
  Future<UnitCreepCaptureReadResult> capture(UnitCreepCaptureRequest request) {
    requests.add(request);
    if (failure == 'sync') throw StateError('Synthetic synchronous error');
    return () async {
      if (hold) await (_pending[request] = Completer<void>()).future;
      if (failure == 'throw') throw StateError('Synthetic asynchronous error');
      final dim = request.stateRequest.session.metadataViews.dimensions.single;
      final width = failure == 'dimensions' ? dim.width - 1 : dim.width;
      return UnitCreepCaptureReadResult(
        capture: failure == 'empty'
            ? null
            : UnitCreepCapture(
                request: failure == 'request'
                    ? UnitCreepCaptureInput.prepare(
                        request.stateRequest,
                        syntheticCaptureConfiguration(),
                      )
                    : request,
                capturedInputRevision: failure == 'input'
                    ? 'other'
                    : request.inputRevision,
                providerId: failure == 'provider'
                    ? 'other'
                    : 'synthetic-capture',
                revision: failure == 'revision' ? '' : 'synthetic-report-v1',
                observation: syntheticCreepObservation(
                  width: width,
                  height: dim.height,
                  collectorVersion: failure == 'collector'
                      ? 'unsupported'
                      : 'synthetic-observer-v1',
                  gameVersion: failure == 'game'
                      ? 'unsupported'
                      : 'synthetic-game-not-SCR',
                  gameSessionId: failure == 'session'
                      ? 'other'
                      : 'synthetic-game-session',
                  setupRevision: failure == 'setup'
                      ? 'other'
                      : request.setupRevision,
                  contractRevision: failure == 'contract'
                      ? 'other'
                      : UnitCreepObservation.revision,
                  phase: failure == 'phase'
                      ? UnitCreepObservationPhase.running
                      : UnitCreepObservationPhase
                            .initializedBeforeFirstTriggerCycle,
                  simulationFrame: failure == 'simulation' ? 1 : 0,
                  authority: failure == 'authority'
                      ? UnitCreepObservationAuthority.unverified
                      : UnitCreepObservationAuthority.fullMap,
                  gameFrame: frame,
                  observedTiles: List.filled(width * dim.height, visible),
                ),
                coverage: UnitCreepCoverage(
                  width: width,
                  height: dim.height,
                  tiles: List.filled(width * dim.height, fill),
                ),
              ),
        errorCode: failure == 'error' ? 'SYNTHETIC_FAILURE' : null,
        exitCode: failure == 'exit' ? 1 : 0,
        stdout: failure == 'output'
            ? 'x' * 65537
            : 'synthetic capture, not game evidence',
        stderr: 'synthetic diagnostic',
      );
    }();
  }

  @override
  Future<void> cancel(UnitCreepCaptureRequest request) {
    cancelled.add(request);
    if (cancelFailure == 'sync') throw StateError('Synthetic cancel failure');
    if (cancelFailure == 'async') {
      return Future.error(StateError('Synthetic cancel failure'));
    }
    return Future.value();
  }
}
