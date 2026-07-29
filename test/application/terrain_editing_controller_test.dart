import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_picker.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/application/terrain/terrain_editing_controller.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';

void main() {
  test('selects a raw tile and paints only the active MTXM section', () async {
    final fixture = await _openFixture(_terrainChk());
    addTearDown(fixture.dispose);
    final controller = fixture.terrainEditingController;
    final original = fixture.openMapController.state.session!;

    controller.synchronizeSession(original);
    expect(controller.canSelectTiles, isTrue);
    expect(controller.canEditTerrain, isTrue);
    expect(controller.selectTileAt(const TerrainTileCoordinate(x: 1, y: 0)), 2);
    controller.setTool(TerrainEditingTool.brush);

    expect(
      controller.paintTiles(const [
        TerrainTileCoordinate(x: 0, y: 0),
        TerrainTileCoordinate(x: 2, y: 1),
        TerrainTileCoordinate(x: 2, y: 1),
      ]),
      isTrue,
    );

    final edited = fixture.openMapController.state.session!;
    expect(edited.isDirty, isTrue);
    expect(edited.terrainViews.tileMaps.single.rawTileValues, [
      2,
      2,
      3,
      4,
      5,
      2,
    ]);
    expect(edited.rawDocument.sections[5].isDirty, isTrue);
    expect(edited.rawDocument.sections[6].isDirty, isFalse);
    expect(edited.rawDocument.sections[6].payload, [0xaa, 0xbb]);
    expect(edited.rawDocument.sections[7].isDirty, isFalse);
    expect(edited.rawDocument.sections[7].payload, [0x11, 0x22, 0x33]);
    expect(edited.rawDocument.sections[8].isDirty, isFalse);
    expect(edited.rawDocument.sections[8].payload, [0x7f]);
    expect(identical(edited.extractedMap, original.extractedMap), isTrue);
    expect(controller.state.tool, TerrainEditingTool.brush);
    expect(controller.state.selectedRawTileValue, 2);
  });

  test(
    'fills a normalized inclusive rectangle and skips a no-op edit',
    () async {
      final fixture = await _openFixture(_terrainChk());
      addTearDown(fixture.dispose);
      final controller = fixture.terrainEditingController;

      controller.synchronizeSession(fixture.openMapController.state.session);
      controller.selectTileAt(const TerrainTileCoordinate(x: 0, y: 0));
      final region = TerrainTileRegion.fromCorners(
        const TerrainTileCoordinate(x: 2, y: 1),
        const TerrainTileCoordinate(x: 1, y: 0),
      );

      expect(region.left, 1);
      expect(region.top, 0);
      expect(region.right, 2);
      expect(region.bottom, 1);
      expect(region.tileCount, 4);
      expect(controller.fillRectangle(region), isTrue);
      expect(
        fixture
            .openMapController
            .state
            .session!
            .terrainViews
            .tileMaps
            .single
            .rawTileValues,
        [1, 1, 1, 4, 1, 1],
      );
      expect(controller.fillRectangle(region), isFalse);
    },
  );

  test('rejects out-of-bounds edits without changing the session', () async {
    final fixture = await _openFixture(_terrainChk());
    addTearDown(fixture.dispose);
    final controller = fixture.terrainEditingController;

    controller.synchronizeSession(fixture.openMapController.state.session);
    controller.selectTileAt(const TerrainTileCoordinate(x: 0, y: 0));
    final originalSession = fixture.openMapController.state.session;

    expect(
      () => controller.paintTiles(const [TerrainTileCoordinate(x: 3, y: 0)]),
      throwsRangeError,
    );
    expect(fixture.openMapController.state.session, same(originalSession));
  });

  test('does not edit ambiguous or protected terrain', () async {
    final duplicate = await _openFixture(
      _terrainChk(
        extraTerrainPayload: const [9, 0, 9, 0, 9, 0, 9, 0, 9, 0, 9, 0],
      ),
    );
    addTearDown(duplicate.dispose);
    duplicate.terrainEditingController.synchronizeSession(
      duplicate.openMapController.state.session,
    );

    expect(duplicate.terrainEditingController.canSelectTiles, isFalse);
    expect(duplicate.terrainEditingController.canEditTerrain, isFalse);
    expect(
      () => duplicate.terrainEditingController.selectTileAt(
        const TerrainTileCoordinate(x: 0, y: 0),
      ),
      throwsStateError,
    );

    final protected = await _openFixture(_terrainChk(protected: true));
    addTearDown(protected.dispose);
    protected.terrainEditingController.synchronizeSession(
      protected.openMapController.state.session,
    );
    expect(protected.terrainEditingController.canSelectTiles, isTrue);
    expect(protected.terrainEditingController.canEditTerrain, isFalse);
    protected.terrainEditingController.selectTileAt(
      const TerrainTileCoordinate(x: 0, y: 0),
    );
    expect(
      protected.terrainEditingController.paintTiles(const [
        TerrainTileCoordinate(x: 1, y: 0),
      ]),
      isFalse,
    );
  });

  test('resets tool and selection for a different source snapshot', () async {
    final first = await _openFixture(_terrainChk());
    final second = await _openFixture(_terrainChk());
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final controller = first.terrainEditingController;

    controller.synchronizeSession(first.openMapController.state.session);
    controller.selectTileAt(const TerrainTileCoordinate(x: 1, y: 0));
    controller.setTool(TerrainEditingTool.brush);
    controller.synchronizeSession(second.openMapController.state.session);

    expect(controller.state.tool, TerrainEditingTool.select);
    expect(controller.state.selectedRawTileValue, isNull);
    expect(controller.state.selectedTile, isNull);
  });
}

final class _OpenedFixture {
  const _OpenedFixture({
    required this.openMapController,
    required this.terrainEditingController,
    required this.progressController,
  });

  final OpenMapController openMapController;
  final TerrainEditingController terrainEditingController;
  final OperationProgressController progressController;

  Future<void> dispose() async {
    await terrainEditingController.dispose();
    await openMapController.dispose();
    await progressController.dispose();
  }
}

Future<_OpenedFixture> _openFixture(Uint8List chkBytes) async {
  final progressController = OperationProgressController();
  final map = ExtractedMap(
    sourcePath: r'C:\Maps\Terrain.scx',
    scenarioChkBytes: chkBytes,
    metadata: MapArchiveMetadata(
      archiveSizeBytes: 4096,
      formatVersion: 1,
      totalEntryCount: 1,
      listingComplete: true,
      entries: [
        MapArchiveEntryMetadata(
          path: MapArchiveEntryPaths.scenarioChk,
          uncompressedSizeBytes: chkBytes.length,
          compressedSizeBytes: chkBytes.length,
          flags: 0x80000000,
          locale: 0,
          nameIsSynthetic: false,
        ),
      ],
    ),
  );
  final openMapController = OpenMapController(
    archiveGateway: _FixtureArchiveGateway(map),
    filePicker: const _NoMapFilePicker(),
    fingerprintGateway: const _FixtureFingerprintGateway(),
    recentProjectsService: RecentProjectsService(InMemorySettingsStore()),
    operationProgressController: progressController,
  );
  final terrainEditingController = TerrainEditingController(
    openMapController: openMapController,
  );
  final state = await openMapController.open(sourcePath: map.sourcePath);
  expect(state.status, OpenMapStatus.opened);
  return _OpenedFixture(
    openMapController: openMapController,
    terrainEditingController: terrainEditingController,
    progressController: progressController,
  );
}

Uint8List _terrainChk({
  List<int>? extraTerrainPayload,
  bool protected = false,
}) {
  final sections = <Uint8List>[
    _section('TYPE', [0x52, 0x41, 0x57, 0x53]),
    _section('VER ', [206, 0]),
    _section('IVER', [10, 0]),
    _section('DIM ', [3, 0, 2, 0]),
    _section('ERA ', [4, 0]),
    _section('MTXM', [1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, 0]),
    _section('TILE', [0xaa, 0xbb]),
    _section('ISOM', [0x11, 0x22, 0x33]),
    _section('TEST', [0x7f]),
    if (extraTerrainPayload != null) _section('MTXM', extraTerrainPayload),
    if (protected) _protectionMarker(),
  ];
  final builder = BytesBuilder(copy: false);
  for (final section in sections) {
    builder.add(section);
  }
  return builder.takeBytes();
}

Uint8List _section(String name, List<int> payload) {
  final bytes = Uint8List(RawChkParser.headerLength + payload.length);
  bytes.setRange(0, 4, name.codeUnits);
  ByteData.sublistView(bytes).setUint32(4, payload.length, Endian.little);
  bytes.setRange(RawChkParser.headerLength, bytes.length, payload);
  return bytes;
}

Uint8List _protectionMarker() {
  final bytes = Uint8List(RawChkParser.headerLength);
  bytes.setRange(0, 4, 'ISOM'.codeUnits);
  ByteData.sublistView(bytes).setUint32(4, 0x80000001, Endian.little);
  return bytes;
}

final class _FixtureArchiveGateway implements MapArchiveGateway {
  const _FixtureArchiveGateway(this.map);

  final ExtractedMap map;

  @override
  Future<MapArchiveOpenResult> open(MapArchiveOpenRequest request) async =>
      MapArchiveOpenResult.success(map: map);

  @override
  Future<MapArchiveWriteResult> writeTemporary(MapArchiveWriteRequest request) {
    throw StateError('Writing is not used by this test.');
  }

  @override
  Future<bool> cancel(String operationId) async => false;
}

final class _NoMapFilePicker implements MapFilePicker {
  const _NoMapFilePicker();

  @override
  Future<String?> pickMapPath() async => null;

  @override
  Future<String?> pickSaveMapPath({required String suggestedName}) async =>
      null;
}

final class _FixtureFingerprintGateway implements MapFileFingerprintGateway {
  const _FixtureFingerprintGateway();

  @override
  Future<MapFileFingerprint> fingerprint(String path) async =>
      MapFileFingerprint(
        sizeBytes: 4096,
        modifiedAt: DateTime.utc(2026, 7, 29),
        sha256Digest:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
}
