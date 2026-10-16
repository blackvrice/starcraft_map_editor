import 'dart:async';
import '../../application/ports/map_archive_gateway.dart';
import '../../application/ports/map_file_fingerprint_gateway.dart';
import '../../application/ports/map_resource_gateway.dart';
import '../../application/ports/unit_creep_capture_gateway.dart';
import '../../application/ports/unit_creep_map_preparation_gateway.dart';
import '../../domain/assets/map_sound.dart';
import '../../domain/chk/chk.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';
import 'unit_creep_capture_input.dart';

/// Materializes an explicitly requested input; never starts a game/collector.
final class UnitCreepMapPreparer implements UnitCreepMapPreparationGateway {
  UnitCreepMapPreparer({
    required this.archiveGateway,
    required this.resourceReader,
    required this.fingerprintGateway,
    required this.workspaceGateway,
    required this.configuration,
    this.archiveTimeout = const Duration(seconds: 30),
  }) {
    if (archiveTimeout <= Duration.zero) {
      throw ArgumentError('Invalid archive timeout.');
    }
  }
  final MapArchiveGateway archiveGateway;
  final MapArchiveResourceReader resourceReader;
  final MapFileFingerprintGateway fingerprintGateway;
  final CreepCaptureWorkspaceGateway workspaceGateway;
  final UnitCreepCaptureConfiguration configuration;
  final Duration archiveTimeout;
  final _active = <UnitCreepCaptureRequest, _PreparationOperation>{};
  final _workspaces = <UnitCreepCaptureRequest, CreepCaptureWorkspace>{};
  final _prepared = <UnitCreepCaptureRequest, PreparedUnitCreepMap>{};
  final _releasing = <UnitCreepCaptureRequest>{};
  static int _nextInstance = 0;
  final int _instance = ++_nextInstance;
  int _serial = 0;

  @override
  Future<UnitCreepMapPreparationResult> prepare(
    UnitCreepCaptureRequest request,
  ) async {
    if (_active.containsKey(request) || _workspaces.containsKey(request)) {
      return UnitCreepMapPreparationResult(
        errorCode: 'UNIT_CREEP_PREPARE_ACTIVE',
      );
    }
    final op = _PreparationOperation(++_serial);
    _active[request] = op;
    final diagnostics = <EditorDiagnostic>[];
    PreparedUnitCreepMap? prepared;
    String? errorCode;
    var details = '';
    try {
      final expected = _validateInput(request);
      _require(
        expected.inputRevision == request.inputRevision &&
            expected.baseArchiveSha256 == request.baseArchiveSha256 &&
            expected.scenarioChkSha256 == request.scenarioChkSha256 &&
            expected.setupRevision == request.setupRevision &&
            expected.setupSchema == request.setupSchema &&
            _same(expected.scenarioChkBytes, request.scenarioChkBytes) &&
            _same(expected.setupBytes, request.setupBytes) &&
            _sameResources(expected.resourceEdits, request.resourceEdits),
        'INPUT_INVALID',
      );
      final session = request.stateRequest.session;
      _require(session.extractedMap.scenarioLocale == 0, 'UNSUPPORTED_ARCHIVE');
      await _checkSource(request);
      _checkCancelled(op);
      final sourcePath = session.sourcePath;
      final sourceEntries = <String, MapArchiveEntryMetadata>{};
      if (sourcePath != null) {
        final source = await _open(sourcePath, op, diagnostics);
        _require(
          _same(source.scenarioChkBytes, session.extractedMap.scenarioChkBytes),
          'SOURCE_CHANGED',
        );
        sourceEntries.addAll(_inventory(source));
      }
      final expectedNames = sourceEntries.keys.toSet();
      for (final entry in request.resourceEdits.entries) {
        _require(
          !expectedNames.any(
            (name) =>
                name != entry.key &&
                name.toLowerCase() == entry.key.toLowerCase(),
          ),
          'UNSUPPORTED_ARCHIVE',
        );
        if (entry.value == null) {
          expectedNames.remove(entry.key);
        } else {
          expectedNames.add(entry.key);
        }
      }
      final expectedBytes = expectedNames.fold<int>(
        0,
        (total, name) =>
            total +
            (request.resourceEdits[name]?.length ??
                sourceEntries[name]!.uncompressedSizeBytes),
      );
      _require(
        expectedNames.length <= 512 &&
            expectedBytes <= configuration.maximumResourceBytes,
        'UNSUPPORTED_ARCHIVE',
      );
      final workspace = await workspaceGateway.create();
      _workspaces[request] = workspace;
      _checkCancelled(op);
      if (sourcePath != null) {
        _require(
          !await workspaceGateway.sameLocation(sourcePath, workspace.mapPath),
          'WORKSPACE_INVALID',
        );
        _checkCancelled(op);
      }
      op.archiveId = 'creep-prepare-$_instance-${op.serial}-write';
      final written = await archiveGateway.writeTemporary(
        MapArchiveWriteRequest(
          operationId: op.archiveId!,
          sourcePath: sourcePath,
          temporaryOutputPath: workspace.mapPath,
          scenarioChkBytes: request.scenarioChkBytes,
          resourceEdits: request.resourceEdits,
          timeout: archiveTimeout,
        ),
      );
      diagnostics.addAll(written.diagnostics);
      _checkCancelled(op);
      _require(
        written.isSuccess && written.temporaryOutputPath == workspace.mapPath,
        'WRITE_FAILED',
      );
      op.archiveId = null;
      final before = await fingerprintGateway.fingerprint(workspace.mapPath);
      _checkCancelled(op);
      final reopened = await _open(workspace.mapPath, op, diagnostics);
      _require(
        _same(reopened.scenarioChkBytes, request.scenarioChkBytes) &&
            const RawChkParser().parse(reopened.scenarioChkBytes).isSuccess,
        'VERIFY_FAILED',
      );
      final outputEntries = _inventory(reopened);
      _require(
        outputEntries.keys.toSet().containsAll(expectedNames) &&
            outputEntries.length == expectedNames.length,
        'VERIFY_FAILED',
      );
      for (final name in expectedNames) {
        final actual = await resourceReader.readResource(
          workspace.mapPath,
          name,
        );
        _checkCancelled(op);
        final edited = request.resourceEdits.containsKey(name);
        final bytes = edited
            ? request.resourceEdits[name]
            : await resourceReader.readResource(sourcePath!, name);
        _checkCancelled(op);
        _require(
          bytes != null &&
              actual != null &&
              actual.length == outputEntries[name]!.uncompressedSizeBytes &&
              actual.length <= configuration.maximumResourceEntryBytes &&
              (edited ||
                  bytes.length == sourceEntries[name]!.uncompressedSizeBytes) &&
              _same(bytes, actual),
          'VERIFY_FAILED',
        );
      }
      final after = await fingerprintGateway.fingerprint(workspace.mapPath);
      _checkCancelled(op);
      _require(before == after, 'OUTPUT_CHANGED');
      await _checkSource(request);
      _checkCancelled(op);
      prepared = PreparedUnitCreepMap(
        request: request,
        path: workspace.mapPath,
        fingerprint: after,
      );
      _prepared[request] = prepared;
    } catch (error) {
      errorCode = error is _PreparationFailure
          ? error.code
          : 'UNIT_CREEP_PREPARE_FAILED';
      details = '$error';
      if (details.length > 4096) details = details.substring(0, 4096);
    } finally {
      // Await the in-flight helper before cleanup; cancellation is advisory.
      if (prepared == null && _workspaces.containsKey(request)) {
        try {
          await workspaceGateway.cleanup(_workspaces[request]!);
          _workspaces.remove(request);
        } catch (_) {
          /* Retain ownership for explicit release retry. */
        }
      }
      _active.remove(request);
    }
    return UnitCreepMapPreparationResult(
      prepared: prepared,
      errorCode: errorCode,
      errorDetails: details,
      cleanupPending: prepared == null && _workspaces.containsKey(request),
      diagnostics: diagnostics,
    );
  }

  Map<String, MapArchiveEntryMetadata> _inventory(ExtractedMap map) {
    // The resource reader supports WAV only; never skip unverifiable assets.
    _require(
      map.metadata.listingComplete &&
          map.metadata.totalEntryCount <= 516 &&
          map.scenarioLocale == 0,
      'UNSUPPORTED_ARCHIVE',
    );
    final result = <String, MapArchiveEntryMetadata>{};
    final aliases = <String>{};
    var size = 0;
    for (final entry in map.metadata.entries) {
      _require(
        !entry.nameIsSynthetic &&
            entry.locale == 0 &&
            entry.path.toLowerCase() != MapArchiveEntryPaths.signature &&
            aliases.add(entry.path.replaceAll('/', r'\').toLowerCase()),
        'UNSUPPORTED_ARCHIVE',
      );
      if (MapArchiveEntryPaths.isInternal(entry.path) ||
          MapArchiveEntryPaths.isScenarioChk(entry.path)) {
        continue;
      }
      _require(
        _supportedPath(entry.path) &&
            entry.uncompressedSizeBytes <=
                configuration.maximumResourceEntryBytes,
        'UNSUPPORTED_ARCHIVE',
      );
      size += entry.uncompressedSizeBytes;
      _require(
        size <= configuration.maximumResourceBytes && result.length < 512,
        'UNSUPPORTED_ARCHIVE',
      );
      result[entry.path] = entry;
    }
    return result;
  }

  UnitCreepCaptureRequest _validateInput(UnitCreepCaptureRequest request) {
    try {
      return UnitCreepCaptureInput.prepare(request.stateRequest, configuration);
    } catch (_) {
      throw _PreparationFailure('UNIT_CREEP_PREPARE_INPUT_INVALID');
    }
  }

  bool _supportedPath(String path) {
    try {
      return MapSound.path(path) == path;
    } on FormatException {
      return false;
    } on ArgumentError {
      return false;
    }
  }

  Future<ExtractedMap> _open(
    String path,
    _PreparationOperation op,
    List<EditorDiagnostic> diagnostics,
  ) async {
    _checkCancelled(op);
    op.archiveId = 'creep-prepare-$_instance-${op.serial}-open-${op.opens++}';
    final result = await archiveGateway.open(
      MapArchiveOpenRequest(
        operationId: op.archiveId!,
        sourcePath: path,
        timeout: archiveTimeout,
      ),
    );
    diagnostics.addAll(result.diagnostics);
    _checkCancelled(op);
    op.archiveId = null;
    _require(result.isSuccess, 'OPEN_FAILED');
    _require(result.extractedMap!.sourcePath == path, 'OPEN_FAILED');
    return result.extractedMap!;
  }

  Future<void> _checkSource(UnitCreepCaptureRequest request) async {
    final session = request.stateRequest.session;
    if (session.sourcePath != null) {
      _require(
        await fingerprintGateway.fingerprint(session.sourcePath!) ==
            session.sourceFingerprint,
        'SOURCE_CHANGED',
      );
    }
  }

  @override
  Future<bool> revalidate(PreparedUnitCreepMap prepared) async {
    if (!identical(_prepared[prepared.request], prepared)) return false;
    try {
      await _checkSource(prepared.request);
      final current = await fingerprintGateway.fingerprint(prepared.path);
      return identical(_prepared[prepared.request], prepared) &&
          current == prepared.fingerprint;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> release(UnitCreepCaptureRequest request) async {
    if (_active.containsKey(request) ||
        !_workspaces.containsKey(request) ||
        !_releasing.add(request)) {
      return false;
    }
    _prepared.remove(request);
    try {
      await workspaceGateway.cleanup(_workspaces[request]!);
      _workspaces.remove(request);
      return true;
    } catch (_) {
      return false;
    } finally {
      _releasing.remove(request);
    }
  }

  @override
  Future<void> cancel(UnitCreepCaptureRequest request) async {
    final op = _active[request];
    if (op == null) return;
    op.cancelled = true;
    final id = op.archiveId;
    if (id != null) {
      unawaited(
        Future.sync(
          () => archiveGateway.cancel(id),
        ).then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
    }
  }

  void _checkCancelled(_PreparationOperation op) =>
      _require(!op.cancelled, 'CANCELLED');
  void _require(bool condition, String suffix) {
    if (!condition) throw _PreparationFailure('UNIT_CREEP_PREPARE_$suffix');
  }

  bool _same(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  bool _sameResources(
    Map<String, List<int>?> left,
    Map<String, List<int>?> right,
  ) =>
      left.length == right.length &&
      left.entries.every(
        (entry) =>
            right.containsKey(entry.key) &&
            (entry.value == null
                ? right[entry.key] == null
                : right[entry.key] != null &&
                      _same(entry.value!, right[entry.key]!)),
      );
}

final class _PreparationOperation {
  _PreparationOperation(this.serial);
  final int serial;
  int opens = 0;
  bool cancelled = false;
  String? archiveId;
}

final class _PreparationFailure implements Exception {
  _PreparationFailure(this.code);
  final String code;
  @override
  String toString() => code;
}
