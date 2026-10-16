import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_resource_gateway.dart';
import 'package:starcraft_map_editor/application/ports/unit_creep_capture_gateway.dart';
import 'package:starcraft_map_editor/application/ports/unit_creep_map_preparation_gateway.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';
import 'package:starcraft_map_editor/infrastructure/placement/unit_creep_capture_input.dart';
import 'package:starcraft_map_editor/infrastructure/placement/unit_creep_map_preparer.dart';

import '../fixtures/basic_editing_fixture.dart';
import '../fixtures/creep_capture_fixture.dart';

void main() {
  test(
    'new map exports current raw CHK and owns output until release',
    () async {
      final h = _Harness();
      final before = h.request.stateRequest.session;
      final result = await h.preparer.prepare(h.request);
      expect(result.isSuccess, isTrue, reason: result.errorDetails);
      expect(h.writes.single.sourcePath, isNull);
      expect(h.writes.single.scenarioChkBytes, h.request.scenarioChkBytes);
      expect(h.outputChk, const RawChkEncoder().encode(before.rawDocument));
      expect(h.outputChk, containsAllInOrder('ZZZZ'.codeUnits));
      expect(h.cleaned, 0);
      expect(await h.preparer.revalidate(result.prepared!), isTrue);
      expect(await h.preparer.release(h.request), isTrue);
      expect(h.cleaned, 1);
      expect(await h.preparer.revalidate(result.prepared!), isFalse);
      expect(await h.preparer.release(h.request), isFalse);
      expect(h.request.stateRequest.session, same(before));
    },
  );

  test(
    'saved map preserves baseline and untouched resources with overlay',
    () async {
      final h = _Harness(
        saved: true,
        edits: {
          'old.wav': [9],
          'new.wav': [],
          'remove.wav': null,
        },
      );
      final baseline = List<int>.of(h.sourceChk);
      final resources = Map<String, List<int>>.of(h.sourceResources);
      final result = await h.preparer.prepare(h.request);
      expect(result.isSuccess, isTrue, reason: result.errorDetails);
      expect(h.outputResources, {
        'old.wav': [9],
        'keep.wav': [2],
        'new.wav': [],
      });
      expect(h.sourceChk, baseline);
      expect(h.sourceResources, resources);
      expect(h.sourceChecks, 2);
      expect(
        result.diagnostics.map((d) => d.rawDetails),
        contains('synthetic log'),
      );
      expect(await h.preparer.release(h.request), isTrue);
    },
  );

  for (final field in ['input', 'chk', 'setup', 'resource', 'base', 'schema']) {
    test('rejects mismatched $field before any external call', () async {
      final h = _Harness();
      final r = h.request;
      final altered = UnitCreepCaptureRequest(
        stateRequest: r.stateRequest,
        inputRevision: field == 'input' ? 'other' : r.inputRevision,
        scenarioChkSha256: r.scenarioChkSha256,
        baseArchiveSha256: field == 'base' ? 'a' * 64 : r.baseArchiveSha256,
        setupRevision: r.setupRevision,
        scenarioChkBytes: field == 'chk' ? [1] : r.scenarioChkBytes,
        setupBytes: field == 'setup' ? [4] : r.setupBytes,
        setupSchema: field == 'schema' ? 'other' : r.setupSchema,
        resourceEdits: field == 'resource'
            ? {
                'x.wav': [4],
              }
            : r.resourceEdits,
      );
      final result = await h.preparer.prepare(altered);
      expect(result.errorCode, 'UNIT_CREEP_PREPARE_INPUT_INVALID');
      expect(h.created, 0);
      expect(h.opens, isEmpty);
      expect(h.writes, isEmpty);
    });
  }

  test('rejects incompatible explicit setup configuration', () async {
    final h = _Harness();
    final preparer = h.makePreparer(
      syntheticCaptureConfiguration(setupBytes: [8]),
    );
    expect(
      (await preparer.prepare(h.request)).errorCode,
      'UNIT_CREEP_PREPARE_INPUT_INVALID',
    );
    expect(h.created, 0);
  });

  for (final scenario in <String, String>{
    'sourceBefore': 'SOURCE_CHANGED',
    'sourceAfter': 'SOURCE_CHANGED',
    'sourceChk': 'SOURCE_CHANGED',
    'sourceOpen': 'OPEN_FAILED',
    'outputOpen': 'OPEN_FAILED',
    'write': 'WRITE_FAILED',
    'wrongOutputPath': 'WRITE_FAILED',
    'outputChk': 'VERIFY_FAILED',
    'corruptResource': 'VERIFY_FAILED',
    'unchangedResource': 'VERIFY_FAILED',
    'sourceRead': 'VERIFY_FAILED',
    'missingResource': 'VERIFY_FAILED',
    'extraResource': 'VERIFY_FAILED',
    'resourceRead': 'VERIFY_FAILED',
    'resourceSize': 'VERIFY_FAILED',
    'outputChanged': 'OUTPUT_CHANGED',
    'alias': 'WORKSPACE_INVALID',
    'createThrows': 'FAILED',
    'writeThrows': 'FAILED',
    'readThrows': 'FAILED',
    'fingerprintThrows': 'FAILED',
  }.entries) {
    test('fails closed and cleans up: ${scenario.key}', () async {
      final h = _Harness(
        saved: true,
        edits: {
          'old.wav': [7],
        },
      )..failure = scenario.key;
      final result = await h.preparer.prepare(h.request);
      expect(result.errorCode, 'UNIT_CREEP_PREPARE_${scenario.value}');
      expect(result.prepared, isNull);
      expect(result.cleanupPending, isFalse);
      expect(h.cleaned, h.created);
      expect(await h.preparer.release(h.request), isFalse);
    });
  }

  for (final inventory in [
    'incomplete',
    'synthetic',
    'locale',
    'duplicate',
    'slash',
    'nonWav',
    'signature',
    'entryBudget',
    'totalBudget',
  ]) {
    for (final side in ['source', 'output']) {
      test('rejects $side inventory $inventory', () async {
        final h = _Harness(saved: true)..failure = '$side-$inventory';
        final result = await h.preparer.prepare(h.request);
        expect(result.errorCode, 'UNIT_CREEP_PREPARE_UNSUPPORTED_ARCHIVE');
        expect(h.cleaned, h.created);
        if (side == 'source') expect(h.writes, isEmpty);
      });
    }
  }

  test('rejects pending aliases of existing resource names', () async {
    final h = _Harness(
      saved: true,
      edits: {
        'OLD.wav': [8],
      },
    );
    expect(
      (await h.preparer.prepare(h.request)).errorCode,
      'UNIT_CREEP_PREPARE_UNSUPPORTED_ARCHIVE',
    );
    expect(h.created, 0);
  });

  test(
    'merged resources respect inclusive total budget before write',
    () async {
      final config = syntheticCaptureConfiguration(maximumResourceBytes: 4);
      final accepted = _Harness(
        saved: true,
        edits: {
          'new.wav': [8],
        },
        config: config,
      );
      expect(
        (await accepted.preparer.prepare(accepted.request)).isSuccess,
        isTrue,
      );
      final rejected = _Harness(
        saved: true,
        edits: {
          'new.wav': [8, 9],
        },
        config: config,
      );
      expect(
        (await rejected.preparer.prepare(rejected.request)).errorCode,
        'UNIT_CREEP_PREPARE_UNSUPPORTED_ARCHIVE',
      );
      expect(rejected.created, 0);
      expect(rejected.writes, isEmpty);
    },
  );

  test(
    'active cancellation waits for in-flight write before cleanup',
    () async {
      final h = _Harness()..heldWrite = Completer<void>();
      final pending = h.preparer.prepare(h.request);
      await h.writeStarted.future;
      expect(
        (await h.preparer.prepare(h.request)).errorCode,
        'UNIT_CREEP_PREPARE_ACTIVE',
      );
      expect(await h.preparer.release(h.request), isFalse);
      await h.preparer.cancel(h.request);
      expect(h.cancelled, [h.writes.single.operationId]);
      expect(h.cleaned, 0);
      h.heldWrite!.complete();
      final result = await pending;
      expect(result.errorCode, 'UNIT_CREEP_PREPARE_CANCELLED');
      expect(h.cleaned, 1);
      expect(h.opens, isEmpty);
      h.heldWrite = null;
      expect((await h.preparer.prepare(h.request)).isSuccess, isTrue);
    },
  );

  test(
    'merged resource count accepts 512 and rejects 513 before writing',
    () async {
      for (final count in [512, 513]) {
        final h = _Harness(
          saved: true,
          edits: {
            for (var i = 0; i < count - 3; i++) 'new$i.wav': [8],
          },
        );
        final result = await h.preparer.prepare(h.request);
        expect(result.isSuccess, count == 512);
        if (count == 513) {
          expect(result.errorCode, 'UNIT_CREEP_PREPARE_UNSUPPORTED_ARCHIVE');
          expect(h.created, 0);
          expect(h.writes, isEmpty);
        }
      }
    },
  );

  test(
    'failed advisory cancellation does not bypass cleanup barrier',
    () async {
      final h = _Harness()
        ..heldWrite = Completer<void>()
        ..failure = 'cancelThrows';
      final pending = h.preparer.prepare(h.request);
      await h.writeStarted.future;
      await h.preparer.cancel(h.request);
      h.heldWrite!.complete();
      expect((await pending).errorCode, 'UNIT_CREEP_PREPARE_CANCELLED');
      expect(h.cleaned, 1);
    },
  );

  test('failed cleanup retains ownership and permits explicit retry', () async {
    final h = _Harness()
      ..failure = 'outputChk'
      ..cleanupThrows = true;
    final result = await h.preparer.prepare(h.request);
    expect(result.cleanupPending, isTrue);
    expect(await h.preparer.release(h.request), isFalse);
    expect(
      (await h.preparer.prepare(h.request)).errorCode,
      'UNIT_CREEP_PREPARE_ACTIVE',
    );
    h.cleanupThrows = false;
    expect(await h.preparer.release(h.request), isTrue);
    expect(await h.preparer.release(h.request), isFalse);
  });

  test('only the issued receipt can be revalidated', () async {
    final h = _Harness(saved: true);
    final result = await h.preparer.prepare(h.request);
    final receipt = result.prepared!;
    expect(
      await h.preparer.revalidate(
        PreparedUnitCreepMap(
          request: receipt.request,
          path: receipt.path,
          fingerprint: receipt.fingerprint,
        ),
      ),
      isFalse,
    );
    h.failure = 'sourceBefore';
    expect(await h.preparer.revalidate(receipt), isFalse);
    h.failure = 'outputChanged';
    expect(await h.preparer.revalidate(receipt), isFalse);
    h.failure = null;
    expect(await h.preparer.revalidate(receipt), isTrue);
    expect(
      (await h.preparer.prepare(h.request)).errorCode,
      'UNIT_CREEP_PREPARE_ACTIVE',
    );
  });

  test(
    'release revokes receipt immediately and excludes concurrent release',
    () async {
      final h = _Harness();
      final result = await h.preparer.prepare(h.request);
      h.heldCleanup = Completer<void>();
      final pending = h.preparer.release(h.request);
      expect(await h.preparer.revalidate(result.prepared!), isFalse);
      expect(await h.preparer.release(h.request), isFalse);
      h.heldCleanup!.complete();
      expect(await pending, isTrue);
      expect(h.cleaned, 1);
    },
  );

  test('archive timeout must be positive', () {
    final h = _Harness();
    expect(
      () => UnitCreepMapPreparer(
        archiveGateway: h,
        resourceReader: h,
        fingerprintGateway: h,
        workspaceGateway: h,
        configuration: h.config,
        archiveTimeout: Duration.zero,
      ),
      throwsArgumentError,
    );
  });
}

final class _Harness
    implements
        MapArchiveGateway,
        MapArchiveResourceReader,
        MapFileFingerprintGateway,
        CreepCaptureWorkspaceGateway {
  _Harness({
    bool saved = false,
    Map<String, List<int>?> edits = const {},
    UnitCreepCaptureConfiguration? config,
  }) : config = config ?? syntheticCaptureConfiguration() {
    final baseline = basicDocument();
    final current = baseline.appendSection(basicSection('ZZZZ', [0, 255]));
    sourceChk = const RawChkEncoder().encode(baseline);
    final state = syntheticCaptureStateRequest(
      document: current,
      baseline: baseline,
      archiveHash: saved ? 'a' * 64 : null,
      resources: edits,
    );
    request = UnitCreepCaptureInput.prepare(state, this.config);
    preparer = makePreparer(this.config);
  }
  final UnitCreepCaptureConfiguration config;
  late final UnitCreepCaptureRequest request;
  late final UnitCreepMapPreparer preparer;
  late List<int> sourceChk;
  List<int> outputChk = [];
  final sourceResources = <String, List<int>>{
    'old.wav': [1],
    'keep.wav': [2],
    'remove.wav': [3],
  };
  final outputResources = <String, List<int>>{};
  final writes = <MapArchiveWriteRequest>[];
  final opens = <String>[];
  final cancelled = <String>[];
  final writeStarted = Completer<void>();
  Completer<void>? heldWrite, heldCleanup;
  String? failure;
  bool cleanupThrows = false;
  int created = 0, cleaned = 0, sourceChecks = 0, outputChecks = 0;
  static const output = r'C:\temp\creep-owned\input.scx';
  static const log = EditorDiagnostic(
    code: 'SYNTHETIC_LOG',
    message: 'test',
    severity: DiagnosticSeverity.info,
    stage: DiagnosticStage.validate,
    rawDetails: 'synthetic log',
  );
  static const error = EditorDiagnostic(
    code: 'SYNTHETIC_ERROR',
    message: 'test',
    severity: DiagnosticSeverity.error,
    stage: DiagnosticStage.validate,
  );

  UnitCreepMapPreparer makePreparer(UnitCreepCaptureConfiguration c) =>
      UnitCreepMapPreparer(
        archiveGateway: this,
        resourceReader: this,
        fingerprintGateway: this,
        workspaceGateway: this,
        configuration: c,
      );

  @override
  Future<MapArchiveOpenResult> open(MapArchiveOpenRequest r) async {
    opens.add(r.sourcePath);
    final isOutput = r.sourcePath == output;
    final side = isOutput ? 'output' : 'source';
    if (failure == '${side}Open') {
      return MapArchiveOpenResult.failure(diagnostics: [error]);
    }
    final chk = failure == '${side}Chk'
        ? <int>[]
        : isOutput
        ? outputChk
        : sourceChk;
    final resources = isOutput ? outputResources : sourceResources;
    final entries = [
      _entry(MapArchiveEntryPaths.scenarioChk, chk.length),
      for (final e in resources.entries)
        _entry(
          e.key,
          failure == '$side-entryBudget'
              ? 16 * 1024 * 1024 + 1
              : failure == '$side-totalBudget'
              ? 16 * 1024 * 1024
              : failure == 'resourceSize' && isOutput
              ? e.value.length + 1
              : e.value.length,
          synthetic: failure == '$side-synthetic',
          locale: failure == '$side-locale' ? 1 : 0,
        ),
      if (failure == '$side-duplicate') _entry('OLD.wav', 1),
      if (failure == '$side-slash') _entry('dir/sound.wav', 1),
      if (failure == '$side-nonWav') _entry('unknown.bin', 1),
      if (failure == '$side-signature') _entry('(signature)', 1),
      if (failure == '$side-totalBudget')
        for (var i = 0; i < 2; i++) _entry('more$i.wav', 16 * 1024 * 1024),
    ];
    return MapArchiveOpenResult.success(
      map: ExtractedMap(
        sourcePath: r.sourcePath,
        scenarioChkBytes: chk,
        metadata: MapArchiveMetadata(
          archiveSizeBytes: 100,
          formatVersion: 1,
          totalEntryCount: entries.length,
          entries: entries,
          listingComplete: failure != '$side-incomplete',
        ),
      ),
      diagnostics: [log],
    );
  }

  MapArchiveEntryMetadata _entry(
    String path,
    int length, {
    bool synthetic = false,
    int locale = 0,
  }) => MapArchiveEntryMetadata(
    path: path,
    uncompressedSizeBytes: length,
    compressedSizeBytes: length,
    flags: 0,
    locale: locale,
    nameIsSynthetic: synthetic,
  );

  @override
  Future<MapArchiveWriteResult> writeTemporary(MapArchiveWriteRequest r) async {
    writes.add(r);
    if (!writeStarted.isCompleted) writeStarted.complete();
    if (heldWrite != null) await heldWrite!.future;
    if (failure == 'writeThrows') throw StateError('synthetic write');
    if (failure == 'write') {
      return MapArchiveWriteResult.failure(diagnostics: [error]);
    }
    outputChk = List.of(r.scenarioChkBytes);
    if (r.sourcePath != null) outputResources.addAll(sourceResources);
    for (final e in r.resourceEdits.entries) {
      if (e.value == null) {
        outputResources.remove(e.key);
      } else {
        outputResources[e.key] = List.of(e.value!);
      }
    }
    if (failure == 'corruptResource') outputResources['old.wav'] = [0];
    if (failure == 'unchangedResource') outputResources['keep.wav'] = [0];
    if (failure == 'missingResource') outputResources.remove('old.wav');
    if (failure == 'extraResource') outputResources['extra.wav'] = [0];
    return MapArchiveWriteResult.success(
      temporaryOutputPath: failure == 'wrongOutputPath' ? 'other.scx' : output,
      diagnostics: [log],
    );
  }

  @override
  Future<List<int>?> readResource(
    String archivePath,
    String resourcePath,
  ) async {
    if (failure == 'readThrows') throw StateError('synthetic read');
    if (failure == 'resourceRead') return null;
    if (failure == 'sourceRead' && archivePath != output) return null;
    return (archivePath == output
        ? outputResources
        : sourceResources)[resourcePath];
  }

  @override
  Future<MapFileFingerprint> fingerprint(String path) async {
    if (failure == 'fingerprintThrows') {
      throw StateError('synthetic fingerprint');
    }
    final isOutput = path == output;
    if (isOutput) {
      outputChecks++;
    } else {
      sourceChecks++;
    }
    final changed = isOutput
        ? failure == 'outputChanged' && outputChecks > 1
        : failure == 'sourceBefore' ||
              failure == 'sourceAfter' && sourceChecks > 1;
    return MapFileFingerprint(
      sizeBytes: 100,
      modifiedAt: DateTime.utc(2026),
      sha256Digest:
          (changed
              ? 'c'
              : isOutput
              ? 'b'
              : 'a') *
          64,
    );
  }

  @override
  Future<CreepCaptureWorkspace> create() async {
    if (failure == 'createThrows') throw StateError('synthetic workspace');
    created++;
    return const CreepCaptureWorkspace(
      directoryPath: r'C:\temp\creep-owned',
      mapPath: output,
    );
  }

  @override
  Future<void> cleanup(CreepCaptureWorkspace workspace) async {
    if (heldCleanup != null) await heldCleanup!.future;
    if (cleanupThrows) throw StateError('synthetic cleanup');
    cleaned++;
  }

  @override
  Future<bool> sameLocation(String left, String right) async =>
      failure == 'alias';

  @override
  Future<bool> cancel(String operationId) async {
    cancelled.add(operationId);
    if (failure == 'cancelThrows') throw StateError('synthetic cancel');
    return true;
  }
}
