import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_configuration.dart';
import 'package:starcraft_map_editor/application/eud/safe_eud_build_pipeline.dart';
import 'package:starcraft_map_editor/application/ports/eud_build_file_gateway.dart';
import 'package:starcraft_map_editor/application/ports/eud_build_gateway.dart';
import 'package:starcraft_map_editor/application/ports/eud_compiler_gateway.dart';
import 'package:starcraft_map_editor/application/ports/eud_tool_inspector.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';

void main() {
  group('SafeEudBuildPipeline', () {
    test('validates and promotes output before reporting success', () async {
      final files = _FakeEudBuildFileGateway(destinationStates: [false, false]);
      final fingerprints = _successFingerprints();
      final compiler = _FakeCompilerGateway.success();
      final pipeline = _pipeline(
        files: files,
        fingerprints: fingerprints,
        compiler: compiler,
      );

      final events = await pipeline.build(_plan()).toList();

      expect(events.map((event) => event.kind), [
        EudBuildEventKind.started,
        EudBuildEventKind.stdoutLine,
        EudBuildEventKind.finalizing,
        EudBuildEventKind.succeeded,
      ]);
      expect(compiler.request?.settingsFilePath, _workspace.settingsFilePath);
      expect(files.promoteCalls, 1);
      expect(files.cleanupCalls, 1);
      expect(files.lastReplaceExisting, isFalse);
    });

    test('does not promote when exit zero has no readable output', () async {
      final files = _FakeEudBuildFileGateway(destinationStates: [false]);
      final fingerprints = _FakeFingerprintGateway({
        _basePath: [_fingerprint('1')],
        _entryPath: [_fingerprint('2')],
        _temporaryOutputPath: [FileSystemException('missing output')],
      });
      final pipeline = _pipeline(
        files: files,
        fingerprints: fingerprints,
        compiler: _FakeCompilerGateway.success(),
      );

      final events = await pipeline.build(_plan()).toList();

      expect(events.map((event) => event.kind), [
        EudBuildEventKind.started,
        EudBuildEventKind.stdoutLine,
        EudBuildEventKind.finalizing,
        EudBuildEventKind.failed,
      ]);
      expect(
        events.last.diagnostic?.code,
        EudBuildPipelineDiagnosticCodes.outputInvalid,
      );
      expect(events.last.exitCode, 0);
      expect(files.promoteCalls, 0);
      expect(files.cleanupCalls, 1);
    });

    test('does not promote output with a malformed CHK', () async {
      final files = _FakeEudBuildFileGateway(destinationStates: [false]);
      final fingerprints = _FakeFingerprintGateway({
        _basePath: [_fingerprint('1')],
        _entryPath: [_fingerprint('2')],
        _temporaryOutputPath: [_fingerprint('3', sizeBytes: 512)],
      });
      final pipeline = _pipeline(
        files: files,
        fingerprints: fingerprints,
        compiler: _FakeCompilerGateway.success(),
        archiveGateway: _FakeMapArchiveGateway.success(
          Uint8List.fromList([1, 2, 3]),
        ),
      );

      final events = await pipeline.build(_plan()).toList();

      expect(
        events.last.diagnostic?.code,
        EudBuildPipelineDiagnosticCodes.outputChkInvalid,
      );
      expect(events.last.exitCode, 0);
      expect(files.promoteCalls, 0);
      expect(files.cleanupCalls, 1);
    });

    test('does not promote when the base map changes during build', () async {
      final files = _FakeEudBuildFileGateway(destinationStates: [false]);
      final fingerprints = _FakeFingerprintGateway({
        _basePath: [_fingerprint('1'), _fingerprint('9')],
        _entryPath: [_fingerprint('2')],
        _temporaryOutputPath: [_fingerprint('3', sizeBytes: 512)],
      });
      final pipeline = _pipeline(
        files: files,
        fingerprints: fingerprints,
        compiler: _FakeCompilerGateway.success(),
      );

      final events = await pipeline.build(_plan()).toList();

      expect(
        events.last.diagnostic?.code,
        EudBuildPipelineDiagnosticCodes.inputChanged,
      );
      expect(files.promoteCalls, 0);
      expect(files.cleanupCalls, 1);
    });

    test('does not overwrite an output created during build', () async {
      final files = _FakeEudBuildFileGateway(destinationStates: [false, true]);
      final fingerprints = _successFingerprints();
      final pipeline = _pipeline(
        files: files,
        fingerprints: fingerprints,
        compiler: _FakeCompilerGateway.success(),
      );

      final events = await pipeline.build(_plan()).toList();

      expect(
        events.last.diagnostic?.code,
        EudBuildPipelineDiagnosticCodes.destinationChanged,
      );
      expect(files.promoteCalls, 0);
      expect(files.cleanupCalls, 1);
    });

    test('preserves a confirmed replacement as a recovery backup', () async {
      final files = _FakeEudBuildFileGateway(
        destinationStates: [true, true],
        backupPath: r'C:\Project\build\Output.scx.backup-eud-test.bak',
      );
      final destinationFingerprint = _fingerprint('4');
      final fingerprints = _FakeFingerprintGateway({
        _basePath: [_fingerprint('1'), _fingerprint('1')],
        _entryPath: [_fingerprint('2'), _fingerprint('2')],
        _temporaryOutputPath: [_fingerprint('3', sizeBytes: 512)],
        _outputPath: [destinationFingerprint, destinationFingerprint],
      });
      final pipeline = _pipeline(
        files: files,
        fingerprints: fingerprints,
        compiler: _FakeCompilerGateway.success(),
      );

      final events = await pipeline
          .build(_plan(replaceExistingOutput: true))
          .toList();

      expect(events[events.length - 2].kind, EudBuildEventKind.diagnostic);
      expect(
        events[events.length - 2].diagnostic?.code,
        EudBuildPipelineDiagnosticCodes.backupCreated,
      );
      expect(events.last.kind, EudBuildEventKind.succeeded);
      expect(files.promoteCalls, 1);
      expect(files.lastReplaceExisting, isTrue);
      expect(files.cleanupCalls, 1);
    });

    test(
      'cleans workspace without validating after compiler failure',
      () async {
        final files = _FakeEudBuildFileGateway(destinationStates: [false]);
        final fingerprints = _FakeFingerprintGateway({
          _basePath: [_fingerprint('1')],
          _entryPath: [_fingerprint('2')],
        });
        final pipeline = _pipeline(
          files: files,
          fingerprints: fingerprints,
          compiler: _FakeCompilerGateway.failure(),
        );

        final events = await pipeline.build(_plan()).toList();

        expect(events.last.kind, EudBuildEventKind.failed);
        expect(events.last.diagnostic?.code, 'EUD_TEST_COMPILER_FAILED');
        expect(files.promoteCalls, 0);
        expect(files.cleanupCalls, 1);
        expect(fingerprints.calls, [_basePath, _entryPath]);
      },
    );
  });
}

SafeEudBuildPipeline _pipeline({
  required _FakeEudBuildFileGateway files,
  required _FakeFingerprintGateway fingerprints,
  required _FakeCompilerGateway compiler,
  MapArchiveGateway? archiveGateway,
}) {
  return SafeEudBuildPipeline(
    toolInspector: _FakeToolInspector(),
    compilerGateway: compiler,
    archiveGateway:
        archiveGateway ?? _FakeMapArchiveGateway.success(_validChk()),
    fingerprintGateway: fingerprints,
    buildFileGateway: files,
  );
}

EudBuildPlan _plan({bool replaceExistingOutput = false}) {
  return EudBuildPlan(
    buildId: 'safe-build',
    configuration: EudBuildConfiguration(
      baseMapPath: _basePath,
      sourceRootPath: _sourceRootPath,
      entrySourcePath: _entryPath,
      outputMapPath: _outputPath,
    ),
    tool: _tool(),
    timeout: const Duration(minutes: 2),
    replaceExistingOutput: replaceExistingOutput,
  );
}

_FakeFingerprintGateway _successFingerprints() {
  return _FakeFingerprintGateway({
    _basePath: [_fingerprint('1'), _fingerprint('1')],
    _entryPath: [_fingerprint('2'), _fingerprint('2')],
    _temporaryOutputPath: [_fingerprint('3', sizeBytes: 512)],
  });
}

const _basePath = r'C:\Project\base\Base.scx';
const _sourceRootPath = r'C:\Project\src';
const _entryPath = r'C:\Project\src\main.eps';
const _outputPath = r'C:\Project\build\Output.scx';
const _temporaryOutputPath =
    r'C:\Project\build\.starcraft_map_editor_eud_test\temporary-output.scx';

final _workspace = EudBuildWorkspace(
  directoryPath: r'C:\Project\build\.starcraft_map_editor_eud_test',
  settingsFilePath:
      r'C:\Project\build\.starcraft_map_editor_eud_test\build-settings.eds',
  temporaryOutputMapPath: _temporaryOutputPath,
);

EudToolInfo _tool() {
  return EudToolInfo(
    pathSource: EudToolPathSource.projectProfile,
    installationPath: r'C:\Tools\euddraft',
    executablePath: r'C:\Tools\euddraft\euddraft.exe',
    versionFilePath: r'C:\Tools\euddraft\VERSION',
    version: EudToolVersion.parse('0.10.2.5'),
    companionPaths: const [r'C:\Tools\euddraft\python3.dll'],
  );
}

MapFileFingerprint _fingerprint(String digit, {int sizeBytes = 64}) {
  return MapFileFingerprint(
    sizeBytes: sizeBytes,
    modifiedAt: DateTime.utc(2026, 7, 26),
    sha256Digest: digit * 64,
  );
}

Uint8List _validChk() {
  final bytes = BytesBuilder(copy: false)
    ..add(_section('VER ', [206, 0]))
    ..add(_section('DIM ', [64, 0, 64, 0]))
    ..add(_section('ERA ', [0, 0]));
  return bytes.takeBytes();
}

Uint8List _section(String name, List<int> payload) {
  final result = Uint8List(8 + payload.length);
  result.setRange(0, 4, name.codeUnits);
  ByteData.sublistView(result).setUint32(4, payload.length, Endian.little);
  result.setRange(8, result.length, payload);
  return result;
}

final class _FakeToolInspector implements EudToolInspector {
  @override
  Future<EudToolInspectionResult> inspect(
    EudToolInspectionRequest request,
  ) async {
    return EudToolInspectionResult.ready(readyTool: _tool());
  }
}

final class _FakeCompilerGateway implements EudCompilerGateway {
  _FakeCompilerGateway._(this._events);

  factory _FakeCompilerGateway.success() {
    return _FakeCompilerGateway._((request) {
      return [
        EudBuildEvent.started(
          buildId: request.buildId,
          toolVersion: request.tool.version,
        ),
        EudBuildEvent.stdoutLine(
          buildId: request.buildId,
          text: 'Compiled main.eps',
        ),
        EudBuildEvent.succeeded(buildId: request.buildId, exitCode: 0),
      ];
    });
  }

  factory _FakeCompilerGateway.failure() {
    return _FakeCompilerGateway._((request) {
      return [
        EudBuildEvent.failed(
          buildId: request.buildId,
          diagnostic: const EditorDiagnostic(
            code: 'EUD_TEST_COMPILER_FAILED',
            message: 'The fake compiler failed.',
            severity: DiagnosticSeverity.error,
            stage: DiagnosticStage.compile,
          ),
          exitCode: 1,
        ),
      ];
    });
  }

  final List<EudBuildEvent> Function(EudBuildRequest request) _events;
  EudBuildRequest? request;

  @override
  Stream<EudBuildEvent> build(EudBuildRequest request) {
    this.request = request;
    return Stream.fromIterable(_events(request));
  }

  @override
  Future<bool> cancel(String buildId) async => false;
}

final class _FakeMapArchiveGateway implements MapArchiveGateway {
  _FakeMapArchiveGateway(this.result);

  factory _FakeMapArchiveGateway.success(Uint8List scenarioChkBytes) {
    return _FakeMapArchiveGateway(
      MapArchiveOpenResult.success(
        map: ExtractedMap(
          sourcePath: _temporaryOutputPath,
          scenarioChkBytes: scenarioChkBytes,
          metadata: MapArchiveMetadata(
            archiveSizeBytes: 512,
            formatVersion: 1,
            totalEntryCount: 1,
            entries: [
              MapArchiveEntryMetadata(
                path: MapArchiveEntryPaths.scenarioChk,
                uncompressedSizeBytes: scenarioChkBytes.length,
                compressedSizeBytes: scenarioChkBytes.length,
                flags: 0,
                locale: 0,
                nameIsSynthetic: false,
              ),
            ],
            listingComplete: true,
          ),
        ),
      ),
    );
  }

  final MapArchiveOpenResult result;

  @override
  Future<MapArchiveOpenResult> open(MapArchiveOpenRequest request) async {
    return result;
  }

  @override
  Future<MapArchiveWriteResult> writeTemporary(MapArchiveWriteRequest request) {
    throw StateError('The EUD pipeline never writes a map through this port.');
  }

  @override
  Future<bool> cancel(String operationId) async => false;
}

final class _FakeFingerprintGateway implements MapFileFingerprintGateway {
  _FakeFingerprintGateway(Map<String, List<Object>> results)
    : _results = {
        for (final entry in results.entries)
          entry.key: List<Object>.of(entry.value),
      };

  final Map<String, List<Object>> _results;
  final List<String> calls = [];

  @override
  Future<MapFileFingerprint> fingerprint(String path) async {
    calls.add(path);
    final values = _results[path];
    if (values == null || values.isEmpty) {
      throw StateError('No fingerprint result was configured for $path.');
    }
    final value = values.removeAt(0);
    if (value is MapFileFingerprint) {
      return value;
    }
    throw value;
  }
}

final class _FakeEudBuildFileGateway implements EudBuildFileGateway {
  _FakeEudBuildFileGateway({
    required List<bool> destinationStates,
    this.backupPath,
  }) : _destinationStates = List<bool>.of(destinationStates);

  final List<bool> _destinationStates;
  final String? backupPath;
  int promoteCalls = 0;
  int cleanupCalls = 0;
  bool? lastReplaceExisting;

  @override
  Future<void> validateInputs(EudBuildConfiguration configuration) async {}

  @override
  Future<bool> destinationExists(String path) async {
    if (_destinationStates.isEmpty) {
      throw StateError('No destination state remains.');
    }
    return _destinationStates.removeAt(0);
  }

  @override
  Future<bool> refersToSameLocation(String leftPath, String rightPath) async {
    return false;
  }

  @override
  Future<EudBuildWorkspace> createWorkspace(
    EudBuildConfiguration configuration,
  ) async {
    return _workspace;
  }

  @override
  Future<EudBuildPromotionResult> promote({
    required EudBuildWorkspace workspace,
    required String destinationPath,
    required bool replaceExisting,
  }) async {
    promoteCalls++;
    lastReplaceExisting = replaceExisting;
    return EudBuildPromotionResult(backupPath: backupPath);
  }

  @override
  Future<void> cleanup(EudBuildWorkspace workspace) async {
    cleanupCalls++;
  }
}
