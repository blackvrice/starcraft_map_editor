import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';

void main() {
  group('MapArchiveGateway contract', () {
    test(
      'supports a fake gateway without native or file dependencies',
      () async {
        final extractedMap = _createExtractedMap();
        final gateway = _RecordingMapArchiveGateway(
          openResult: MapArchiveOpenResult.success(map: extractedMap),
          writeResult: MapArchiveWriteResult.success(
            temporaryOutputPath: r'C:\Temp\output.scx',
          ),
        );
        final openRequest = MapArchiveOpenRequest(
          operationId: 'open-map-1',
          sourcePath: r'C:\Maps\input.scx',
          timeout: const Duration(seconds: 30),
        );
        final writeRequest = MapArchiveWriteRequest(
          operationId: 'save-map-1',
          sourcePath: r'C:\Maps\input.scx',
          temporaryOutputPath: r'C:\Temp\output.scx',
          scenarioChkBytes: [1, 2, 3],
          timeout: const Duration(seconds: 30),
        );

        final openResult = await gateway.open(openRequest);
        final writeResult = await gateway.writeTemporary(writeRequest);
        final cancelled = await gateway.cancel('save-map-1');

        expect(openResult.extractedMap, same(extractedMap));
        expect(writeResult.temporaryOutputPath, r'C:\Temp\output.scx');
        expect(cancelled, isTrue);
        expect(gateway.openRequests, [same(openRequest)]);
        expect(gateway.writeRequests, [same(writeRequest)]);
        expect(gateway.cancelledOperationIds, ['save-map-1']);
      },
    );

    test('copies binary request and result data into unmodifiable views', () {
      final sourceBytes = <int>[1, 2, 3];
      final writeRequest = MapArchiveWriteRequest(
        operationId: 'save-map-1',
        sourcePath: r'C:\Maps\input.scx',
        temporaryOutputPath: r'C:\Temp\output.scx',
        scenarioChkBytes: sourceBytes,
        timeout: const Duration(seconds: 30),
      );
      final extractedMap = _createExtractedMap(bytes: sourceBytes);

      sourceBytes[0] = 99;

      expect(writeRequest.scenarioChkBytes, [1, 2, 3]);
      expect(extractedMap.scenarioChkBytes, [1, 2, 3]);
      expect(
        () => writeRequest.scenarioChkBytes[0] = 4,
        throwsUnsupportedError,
      );
      expect(
        () => extractedMap.scenarioChkBytes[0] = 4,
        throwsUnsupportedError,
      );
      expect(
        () => MapArchiveWriteRequest(
          operationId: 'save-map-2',
          sourcePath: r'C:\Maps\input.scx',
          temporaryOutputPath: r'C:\Temp\output.scx',
          scenarioChkBytes: const [256],
          timeout: const Duration(seconds: 30),
        ),
        throwsRangeError,
      );
    });

    test('requires explicit nonblank paths, operation ids, and timeouts', () {
      expect(
        () => MapArchiveOpenRequest(
          operationId: ' ',
          sourcePath: r'C:\Maps\input.scx',
          timeout: const Duration(seconds: 30),
        ),
        throwsArgumentError,
      );
      expect(
        () => MapArchiveOpenRequest(
          operationId: 'open-map-1',
          sourcePath: '',
          timeout: const Duration(seconds: 30),
        ),
        throwsArgumentError,
      );
      expect(
        () => MapArchiveOpenRequest(
          operationId: 'open-map-1',
          sourcePath: r'C:\Maps\input.scx',
          timeout: Duration.zero,
        ),
        throwsArgumentError,
      );
      expect(
        () => MapArchiveWriteRequest(
          operationId: 'save-map-1',
          sourcePath: r'C:\Maps\input.scx',
          temporaryOutputPath: r'C:\Maps\input.scx',
          scenarioChkBytes: const [],
          timeout: const Duration(seconds: 30),
        ),
        throwsArgumentError,
      );
    });

    test('keeps archive metadata immutable and internally consistent', () {
      final entries = <MapArchiveEntryMetadata>[
        MapArchiveEntryMetadata(
          path: MapArchiveEntryPaths.scenarioChk,
          uncompressedSizeBytes: 3,
          compressedSizeBytes: 2,
          flags: 0x80000200,
          locale: 0,
          nameIsSynthetic: false,
        ),
      ];
      final metadata = MapArchiveMetadata(
        archiveSizeBytes: 100,
        formatVersion: 1,
        totalEntryCount: 2,
        entries: entries,
        listingComplete: false,
      );

      entries.add(
        MapArchiveEntryMetadata(
          path: '(listfile)',
          uncompressedSizeBytes: 10,
          compressedSizeBytes: 8,
          flags: 0x80000200,
          locale: 0,
          nameIsSynthetic: false,
        ),
      );

      expect(metadata.entries, hasLength(1));
      expect(metadata.entries.single.isEncrypted, isFalse);
      expect(MapArchiveEntryPaths.isInternal('(LISTFILE)'), isTrue);
      expect(() => metadata.entries.clear(), throwsUnsupportedError);
      expect(
        () => MapArchiveMetadata(
          archiveSizeBytes: 100,
          formatVersion: 1,
          totalEntryCount: 0,
          entries: metadata.entries,
          listingComplete: false,
        ),
        throwsArgumentError,
      );
      expect(
        () => MapArchiveEntryMetadata(
          path: '(listfile)',
          uncompressedSizeBytes: -1,
          compressedSizeBytes: 0,
          flags: 0,
          locale: 0,
          nameIsSynthetic: false,
        ),
        throwsRangeError,
      );
      expect(
        () => MapArchiveMetadata(
          archiveSizeBytes: 100,
          formatVersion: 1,
          totalEntryCount: 2,
          entries: metadata.entries,
          listingComplete: true,
        ),
        throwsArgumentError,
      );
      expect(
        () => MapArchiveMetadata(
          archiveSizeBytes: 100,
          formatVersion: 1,
          totalEntryCount: 2,
          entries: metadata.entries,
          listingComplete: false,
          listingNativeError: 0,
        ),
        throwsRangeError,
      );
      expect(
        () => MapArchiveEntryMetadata(
          path: '(listfile)',
          uncompressedSizeBytes: 1,
          compressedSizeBytes: 1,
          flags: 0x100000000,
          locale: 0,
          nameIsSynthetic: false,
        ),
        throwsRangeError,
      );
    });

    test('requires exactly one matching scenario entry and byte size', () {
      final noScenarioMetadata = MapArchiveMetadata(
        archiveSizeBytes: 100,
        formatVersion: 1,
        totalEntryCount: 0,
        entries: const [],
        listingComplete: true,
      );
      final wrongSizeMetadata = MapArchiveMetadata(
        archiveSizeBytes: 100,
        formatVersion: 1,
        totalEntryCount: 1,
        entries: [
          MapArchiveEntryMetadata(
            path: MapArchiveEntryPaths.scenarioChk,
            uncompressedSizeBytes: 4,
            compressedSizeBytes: 4,
            flags: 0x80000000,
            locale: 0,
            nameIsSynthetic: false,
          ),
        ],
        listingComplete: true,
      );
      final caseVariantMetadata = MapArchiveMetadata(
        archiveSizeBytes: 100,
        formatVersion: 1,
        totalEntryCount: 1,
        entries: [
          MapArchiveEntryMetadata(
            path: r'STAREDIT/SCENARIO.CHK',
            uncompressedSizeBytes: 3,
            compressedSizeBytes: 3,
            flags: 0x80000000,
            locale: 0,
            nameIsSynthetic: false,
          ),
        ],
        listingComplete: true,
      );

      expect(
        () => ExtractedMap(
          sourcePath: r'C:\Maps\input.scx',
          scenarioChkBytes: const [1, 2, 3],
          metadata: noScenarioMetadata,
        ),
        throwsArgumentError,
      );
      expect(
        () => ExtractedMap(
          sourcePath: r'C:\Maps\input.scx',
          scenarioChkBytes: const [1, 2, 3],
          metadata: wrongSizeMetadata,
        ),
        throwsArgumentError,
      );
      expect(
        ExtractedMap(
          sourcePath: r'C:\Maps\input.scx',
          scenarioChkBytes: const [1, 2, 3],
          metadata: caseVariantMetadata,
        ).scenarioChkBytes,
        [1, 2, 3],
      );
    });

    test('allows warnings on success and requires errors on failure', () {
      final warning = _diagnostic(
        severity: DiagnosticSeverity.warning,
        code: 'ARCHIVE_WARNING',
      );
      final error = _diagnostic(
        severity: DiagnosticSeverity.error,
        code: 'ARCHIVE_ERROR',
      );
      final openSuccess = MapArchiveOpenResult.success(
        map: _createExtractedMap(),
        diagnostics: [warning],
      );
      final openFailure = MapArchiveOpenResult.failure(
        diagnostics: [warning, error],
      );
      final writeSuccess = MapArchiveWriteResult.success(
        temporaryOutputPath: r'C:\Temp\output.scx',
        diagnostics: [warning],
      );
      final writeFailure = MapArchiveWriteResult.failure(diagnostics: [error]);

      expect(openSuccess.isSuccess, isTrue);
      expect(openSuccess.diagnostics, [warning]);
      expect(openFailure.isSuccess, isFalse);
      expect(openFailure.extractedMap, isNull);
      expect(writeSuccess.isSuccess, isTrue);
      expect(writeFailure.isSuccess, isFalse);
      expect(writeFailure.temporaryOutputPath, isNull);
      expect(
        () => MapArchiveOpenResult.success(
          map: _createExtractedMap(),
          diagnostics: [error],
        ),
        throwsArgumentError,
      );
      expect(
        () => MapArchiveWriteResult.failure(diagnostics: [warning]),
        throwsArgumentError,
      );
    });
  });
}

ExtractedMap _createExtractedMap({List<int> bytes = const [1, 2, 3]}) {
  return ExtractedMap(
    sourcePath: r'C:\Maps\input.scx',
    scenarioChkBytes: bytes,
    metadata: MapArchiveMetadata(
      archiveSizeBytes: 100,
      formatVersion: 1,
      totalEntryCount: 1,
      entries: [
        MapArchiveEntryMetadata(
          path: MapArchiveEntryPaths.scenarioChk,
          uncompressedSizeBytes: bytes.length,
          compressedSizeBytes: bytes.length,
          flags: 0x80000200,
          locale: 0,
          nameIsSynthetic: false,
        ),
      ],
      listingComplete: true,
    ),
  );
}

EditorDiagnostic _diagnostic({
  required DiagnosticSeverity severity,
  required String code,
}) {
  return EditorDiagnostic(
    code: code,
    message: code,
    severity: severity,
    stage: DiagnosticStage.archive,
  );
}

class _RecordingMapArchiveGateway implements MapArchiveGateway {
  _RecordingMapArchiveGateway({
    required this.openResult,
    required this.writeResult,
  });

  final MapArchiveOpenResult openResult;
  final MapArchiveWriteResult writeResult;
  final List<MapArchiveOpenRequest> openRequests = [];
  final List<MapArchiveWriteRequest> writeRequests = [];
  final List<String> cancelledOperationIds = [];

  @override
  Future<MapArchiveOpenResult> open(MapArchiveOpenRequest request) async {
    openRequests.add(request);
    return openResult;
  }

  @override
  Future<MapArchiveWriteResult> writeTemporary(
    MapArchiveWriteRequest request,
  ) async {
    writeRequests.add(request);
    return writeResult;
  }

  @override
  Future<bool> cancel(String operationId) async {
    cancelledOperationIds.add(operationId);
    return true;
  }
}
