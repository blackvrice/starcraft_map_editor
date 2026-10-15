import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/opened_map_session.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/ports/unit_creep_state_gateway.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';
import 'package:starcraft_map_editor/domain/placement/unit_creep_catalog.dart';
import 'package:starcraft_map_editor/domain/placement/unit_creep_coverage.dart';

import '../fixtures/basic_editing_fixture.dart';

void main() {
  late OpenedMapSession session;
  late UnitCreepStateRequest request;
  setUp(() {
    session = _session(basicDocument(units: [basicUnit(type: 131)]));
    request = _request(session);
  });

  test('exact initial-map request retains provenance and unknown tiles', () {
    final coverage = _coverage();
    final snapshot = _snapshot(request, coverage: coverage);
    expect(snapshot.coverageFor(request), same(coverage));
    expect(
      snapshot.coverageFor(request)!.tileAt(x: 0, y: 0),
      UnitCreepTile.unknown,
    );
    expect(snapshot.providerId, 'test-observer');
    expect(snapshot.revision, 'observation-7');
    expect(snapshot.request.dataIdentity, _source);
  });
  test(
    'identical bytes or equal request fields are not the same observation',
    () {
      final snapshot = _snapshot(request);
      final duplicateRequest = _request(session);
      expect(snapshot.coverageFor(duplicateRequest), isNull);
      final reopened = _session(session.rawDocument);
      expect(
        const RawChkEncoder().encode(reopened.rawDocument),
        const RawChkEncoder().encode(session.rawDocument),
      );
      expect(snapshot.coverageFor(_request(reopened)), isNull);
    },
  );
  test(
    'document/source/revision changes and Undo token reject stale requests',
    () {
      bool current({
        OpenedMapSession? map,
        int revision = 4,
        String? path = r'C:\StarCraft',
        UnitCreepDataIdentity? source = _source,
      }) => request.isCurrentFor(
        session: map ?? session,
        documentRevision: revision,
        installationPath: path,
        dataIdentity: source,
      );
      expect(current(), isTrue);
      expect(current(map: _session(session.rawDocument)), isFalse);
      expect(current(revision: 5), isFalse);
      expect(
        current(revision: 6),
        isFalse,
      ); // Undo restored bytes, not revision.
      expect(current(path: r'D:\StarCraft'), isFalse);
      expect(current(path: null), isFalse);
      for (final source in [
        ('other', _source.$2, _source.$3, _source.$4),
        (_source.$1, 2, _source.$3, _source.$4),
        (_source.$1, _source.$2, 'other', _source.$4),
        (_source.$1, _source.$2, _source.$3, 'other'),
        null,
      ]) {
        expect(current(source: source), isFalse);
      }
      expect(
        request.isCurrentFor(
          session: null,
          documentRevision: 4,
          installationPath: r'C:\StarCraft',
          dataIdentity: _source,
        ),
        isFalse,
      );
    },
  );
  test('live is reserved, cannot fall back to an initial-map snapshot', () {
    final live = _request(session, model: UnitCreepStateModel.live);
    expect(_snapshot(live).coverageFor(live), isNull);
    expect(
      _snapshot(request, model: UnitCreepStateModel.live).coverageFor(request),
      isNull,
    );
    expect(
      _snapshot(live, model: UnitCreepStateModel.live).coverageFor(live),
      isNull,
    );
  });
  for (final invalid in ['provider', 'revision', 'rules', 'width', 'height']) {
    test('invalid snapshot $invalid refused', () {
      final snapshot = _snapshot(
        request,
        providerId: invalid == 'provider' ? ' ' : 'observer',
        revision: invalid == 'revision' ? '\t' : 'state-1',
        rules: invalid == 'rules' ? 'unknown-v2' : UnitCreepCatalog.revision,
        coverage: _coverage(
          width: invalid == 'width' ? 31 : 32,
          height: invalid == 'height' ? 31 : 32,
        ),
      );
      expect(snapshot.coverageFor(request), isNull);
    });
  }
  for (final invalid in [
    'operation',
    'document revision',
    'path',
    'product',
    'build',
    'helper',
    'CascLib',
  ]) {
    test('incomplete request provenance $invalid refused', () {
      final r = _request(
        session,
        operation: invalid == 'operation' ? ' ' : 'collect-1',
        documentRevision: invalid == 'document revision' ? -1 : 4,
        path: invalid == 'path' ? ' ' : r'C:\StarCraft',
        source: (
          invalid == 'product' ? '' : _source.$1,
          invalid == 'build' ? -1 : _source.$2,
          invalid == 'helper' ? '' : _source.$3,
          invalid == 'CascLib' ? '' : _source.$4,
        ),
      );
      expect(_snapshot(r).coverageFor(r), isNull);
    });
  }
  for (final count in [0, 2]) {
    test('missing or duplicate DIM cannot be bound: $count', () {
      final doc = basicDocument();
      final dim = doc.sections.singleWhere((s) => s.name == 'DIM ');
      final changed = RawChkDocument(
        sourceLength: doc.sourceLength,
        sections: [
          for (final s in doc.sections)
            if (s.name != 'DIM ') s,
          for (var i = 0; i < count; i++) dim,
        ],
      );
      final r = _request(_session(changed));
      expect(_snapshot(r).coverageFor(r), isNull);
    });
  }
  test('restricted document is not a trusted initial-map request', () {
    final r = _request(_session(basicDocument(), restricted: true));
    expect(_snapshot(r).coverageFor(r), isNull);
  });
  test('transport success does not authorize malformed or stale coverage', () {
    final invalid = _snapshot(request, rules: 'other');
    final result = UnitCreepStateReadResult(
      snapshot: invalid,
      exitCode: 0,
      stdout: 'raw output',
      stderr: 'raw diagnostic',
    );
    expect(result.isSuccess, isTrue);
    expect(result.snapshot!.coverageFor(request), isNull);
    expect(result.stdout, 'raw output');
    expect(result.stderr, 'raw diagnostic');
    expect(const UnitCreepStateReadResult().isSuccess, isFalse);
    expect(
      UnitCreepStateReadResult(
        snapshot: _snapshot(request),
        errorCode: 'COLLECT_FAILED',
      ).isSuccess,
      isFalse,
    );
    expect(
      UnitCreepStateReadResult(
        snapshot: _snapshot(request),
        exitCode: 1,
      ).isSuccess,
      isFalse,
    );
  });
  test(
    'read-only port retains current UNIT/unknown/string bytes and dirty state',
    () async {
      final before = const RawChkEncoder().encode(session.rawDocument);
      final wasDirty = session.isDirty;
      final gateway = _Gateway();
      final result = await gateway.read(request);
      expect(result.snapshot!.coverageFor(request), isNotNull);
      await gateway.cancel(request.operationId);
      expect(gateway.cancelled, 'collect-1');
      expect(const RawChkEncoder().encode(session.rawDocument), before);
      expect(session.isDirty, wasDirty);
      expect(
        session.objectViews.unitSections.single.units.single.unitType,
        131,
      );
      expect(
        session.rawDocument.sections
            .singleWhere((s) => s.name == 'ZZZZ')
            .payload,
        [255, 0, 17],
      );
    },
  );
}

const UnitCreepDataIdentity _source = (
  'product',
  1,
  'helper-0.13',
  'CascLib-id',
);

UnitCreepStateRequest _request(
  OpenedMapSession session, {
  String operation = 'collect-1',
  int documentRevision = 4,
  String path = r'C:\StarCraft',
  UnitCreepDataIdentity source = _source,
  UnitCreepStateModel model = UnitCreepStateModel.initialMap,
}) => UnitCreepStateRequest(
  operationId: operation,
  session: session,
  documentRevision: documentRevision,
  installationPath: path,
  dataIdentity: source,
  model: model,
);

UnitCreepStateSnapshot _snapshot(
  UnitCreepStateRequest request, {
  String providerId = 'test-observer',
  String revision = 'observation-7',
  String rules = UnitCreepCatalog.revision,
  UnitCreepStateModel model = UnitCreepStateModel.initialMap,
  UnitCreepCoverage? coverage,
}) => UnitCreepStateSnapshot(
  request: request,
  providerId: providerId,
  revision: revision,
  model: model,
  creepModelRevision: rules,
  coverage: coverage ?? _coverage(),
);

UnitCreepCoverage _coverage({int width = 32, int height = 32}) =>
    UnitCreepCoverage(
      width: width,
      height: height,
      tiles: List.filled(width * height, UnitCreepTile.unknown),
    );

OpenedMapSession _session(RawChkDocument document, {bool restricted = false}) =>
    OpenedMapSession(
      extractedMap: ExtractedMap.inMemory(
        scenarioChkBytes: const RawChkEncoder().encode(document),
      ),
      rawDocument: document,
      metadataViews: const ChkMetadataViewDecoder().decode(document),
      stringViews: const ChkStringViewDecoder().decode(document),
      terrainViews: const ChkTerrainViewDecoder().decode(document),
      objectViews: const ChkObjectViewDecoder().decode(document),
      sourceFingerprint: null,
      diagnostics: [
        if (restricted)
          const EditorDiagnostic(
            code: 'TEST_RESTRICTED',
            message: 'Synthetic restricted document',
            severity: DiagnosticSeverity.error,
            stage: DiagnosticStage.validate,
          ),
      ],
    );

final class _Gateway implements UnitCreepStateGateway {
  String? cancelled;
  @override
  Future<UnitCreepStateReadResult> read(UnitCreepStateRequest request) async =>
      UnitCreepStateReadResult(snapshot: _snapshot(request));
  @override
  Future<void> cancel(String operationId) async {
    cancelled = operationId;
  }
}
