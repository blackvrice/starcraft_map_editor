import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/editing/object_editing_controller.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/placement/placement_catalog_controller.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_picker.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/application/terrain/terrain_editing_controller.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';
import 'package:starcraft_map_editor/presentation/placement/placement_catalog_pane.dart';

/// Measures the catalog tab against a page size larger than any real
/// tileset Doodad page, so the virtualized grid and the search filter are
/// exercised at the documented worst case.
///
/// The numbers this test prints are only a relative signal in a debug test
/// binary. The release baseline and its limits must be measured on Windows and
/// recorded in `docs/performance/`.
const _entryCount = 2000;

void main() {
  testWidgets('browses a $_entryCount entry catalog page', (tester) async {
    final fixture = await _fixture();
    addTearDown(fixture.dispose);

    final loadWatch = Stopwatch()..start();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlacementCatalogPane(controller: fixture.controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('placement-catalog-tab-doodad')));
    await tester.pumpAndSettle();
    loadWatch.stop();

    final pageSize = StarCraftPlacementCatalogRequest.maximumLimit;
    expect(fixture.controller.state.totalEntries, _entryCount);
    expect(fixture.controller.state.items, hasLength(pageSize));
    expect(find.byKey(const Key('placement-catalog-grid')), findsOneWidget);

    // A virtualized grid must build only the visible tiles, never all of them.
    final builtTiles = tester.widgetList(find.byType(InkWell)).length;
    expect(
      builtTiles,
      lessThan(pageSize ~/ 2),
      reason: 'the grid must virtualize instead of building every entry',
    );

    final searchWatch = Stopwatch()..start();
    await tester.enterText(
      find.byKey(const Key('placement-catalog-search')),
      '#255',
    );
    await tester.pumpAndSettle();
    searchWatch.stop();
    expect(find.text('Doodad #255'), findsOneWidget);

    final scrollWatch = Stopwatch()..start();
    await tester.enterText(
      find.byKey(const Key('placement-catalog-search')),
      '',
    );
    await tester.pumpAndSettle();
    for (var step = 0; step < 12; step++) {
      await tester.drag(
        find.byKey(const Key('placement-catalog-grid')),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
    }
    scrollWatch.stop();

    // Scrolling to the end of a page must pull the next one instead of
    // loading every entry up front.
    expect(
      fixture.controller.state.items.length,
      greaterThan(pageSize),
      reason: 'the grid must page as it scrolls',
    );

    debugPrint(
      'placement-catalog perf (debug test binary): '
      'firstPage=${loadWatch.elapsedMilliseconds}ms '
      'search=${searchWatch.elapsedMilliseconds}ms '
      'scroll12=${scrollWatch.elapsedMilliseconds}ms '
      'loadedEntries=${fixture.controller.state.items.length} '
      'builtTiles=$builtTiles',
    );
  });
}

final class _Fixture {
  const _Fixture({
    required this.openMapController,
    required this.mapLayerController,
    required this.objectEditingController,
    required this.terrainEditingController,
    required this.controller,
    required this.progressController,
  });

  final OpenMapController openMapController;
  final MapLayerController mapLayerController;
  final ObjectEditingController objectEditingController;
  final TerrainEditingController terrainEditingController;
  final PlacementCatalogController controller;
  final OperationProgressController progressController;

  Future<void> dispose() async {
    await controller.dispose();
    await objectEditingController.dispose();
    await terrainEditingController.dispose();
    await mapLayerController.dispose();
    await openMapController.dispose();
    await progressController.dispose();
  }
}

Future<_Fixture> _fixture() async {
  final chkBytes = _chkBytes();
  final map = ExtractedMap(
    sourcePath: r'C:\Maps\Perf.scx',
    scenarioChkBytes: chkBytes,
    metadata: MapArchiveMetadata(
      archiveSizeBytes: chkBytes.length,
      formatVersion: 1,
      totalEntryCount: 1,
      listingComplete: true,
      entries: [
        MapArchiveEntryMetadata(
          path: MapArchiveEntryPaths.scenarioChk,
          uncompressedSizeBytes: chkBytes.length,
          compressedSizeBytes: chkBytes.length,
          flags: 0,
          locale: 0,
          nameIsSynthetic: false,
        ),
      ],
    ),
  );
  final progressController = OperationProgressController();
  final openMapController = OpenMapController(
    archiveGateway: _PerfArchiveGateway(map),
    filePicker: const _NoMapFilePicker(),
    fingerprintGateway: const _PerfFingerprintGateway(),
    recentProjectsService: RecentProjectsService(InMemorySettingsStore()),
    operationProgressController: progressController,
  );
  final state = await openMapController.open(sourcePath: map.sourcePath);
  final mapLayerController = MapLayerController()
    ..synchronizeSession(state.session);
  final objectEditingController = ObjectEditingController(
    openMapController: openMapController,
    mapLayerController: mapLayerController,
  )..synchronizeSession(state.session);
  final terrainEditingController = TerrainEditingController(
    openMapController: openMapController,
  )..synchronizeSession(state.session);
  final controller = PlacementCatalogController(
    openMapController: openMapController,
    objectEditingController: objectEditingController,
    terrainEditingController: terrainEditingController,
    catalogGateway: const _PerfCatalogGateway(),
    pageSize: StarCraftPlacementCatalogRequest.maximumLimit,
  )..setInstallationPath(r'C:\StarCraft');
  return _Fixture(
    openMapController: openMapController,
    mapLayerController: mapLayerController,
    objectEditingController: objectEditingController,
    terrainEditingController: terrainEditingController,
    controller: controller,
    progressController: progressController,
  );
}

final class _PerfCatalogGateway implements StarCraftPlacementCatalogGateway {
  const _PerfCatalogGateway();

  @override
  Future<StarCraftPlacementCatalogPage> list(
    StarCraftPlacementCatalogRequest request,
  ) async {
    if (request.kind != StarCraftPlacementKind.doodad) {
      return StarCraftPlacementCatalogPage(request: request, totalEntries: 0);
    }
    final entries = <StarCraftPlacementCatalogEntry>[];
    for (
      var id = request.offset;
      id < _entryCount && entries.length < request.limit;
      id++
    ) {
      entries.add(
        StarCraftPlacementCatalogEntry(
          key: StarCraftPlacementCatalogKey.doodad(
            tileset: request.tileset,
            doodadId: id,
            startTileGroup: id,
          ),
          source: StarCraftPlacementCatalogSource.localData,
          availability: StarCraftPlacementAvailability.unsupported,
          issue: StarCraftPlacementCatalogIssue(
            code: 'SC_CATALOG_ITEM_DOODAD_RECIPE_INVALID',
            message: 'Measured entries are not placed by this test.',
          ),
          doodadRecipeIssueCode: 'SC_CASC_DOODAD_TRUNCATED',
        ),
      );
    }
    return StarCraftPlacementCatalogPage(
      request: request,
      totalEntries: _entryCount,
      entries: entries,
    );
  }

  @override
  Future<void> cancel(String operationId) async {}
}

Uint8List _chkBytes() {
  final locations = Uint8List(
    ChkLocationSectionView.originalLocationCount * ChkLocation.recordLength,
  );
  final builder = BytesBuilder(copy: false);
  for (final section in [
    _section('TYPE', [0x52, 0x41, 0x57, 0x53]),
    _section('VER ', [206, 0]),
    _section('IVER', [10, 0]),
    _section('DIM ', [8, 0, 8, 0]),
    _section('ERA ', [4, 0]),
    _section('MTXM', Uint8List(8 * 8 * 2)),
    _section('MRGN', locations),
    _section('STR ', _legacyStringTable(['Existing'])),
  ]) {
    builder.add(section);
  }
  return builder.takeBytes();
}

Uint8List _legacyStringTable(List<String> strings) {
  final encoded = strings.map(utf8.encode).toList(growable: false);
  final headerLength = 2 + strings.length * 2;
  final payloadLength =
      headerLength +
      encoded.fold<int>(0, (sum, bytes) => sum + bytes.length + 1);
  final payload = Uint8List(payloadLength);
  final data = ByteData.sublistView(payload)
    ..setUint16(0, strings.length, Endian.little);
  var offset = headerLength;
  for (var index = 0; index < encoded.length; index++) {
    data.setUint16(2 + index * 2, offset, Endian.little);
    payload.setAll(offset, encoded[index]);
    offset += encoded[index].length + 1;
  }
  return payload;
}

Uint8List _section(String name, List<int> payload) {
  final bytes = Uint8List(RawChkParser.headerLength + payload.length);
  bytes.setRange(0, 4, name.codeUnits);
  ByteData.sublistView(bytes).setUint32(4, payload.length, Endian.little);
  bytes.setRange(RawChkParser.headerLength, bytes.length, payload);
  return bytes;
}

final class _PerfArchiveGateway implements MapArchiveGateway {
  const _PerfArchiveGateway(this.map);

  final ExtractedMap map;

  @override
  Future<MapArchiveOpenResult> open(MapArchiveOpenRequest request) async =>
      MapArchiveOpenResult.success(map: map);

  @override
  Future<MapArchiveWriteResult> writeTemporary(
    MapArchiveWriteRequest request,
  ) => throw StateError('Writing is not used by this test.');

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

final class _PerfFingerprintGateway implements MapFileFingerprintGateway {
  const _PerfFingerprintGateway();

  @override
  Future<MapFileFingerprint> fingerprint(String path) async =>
      MapFileFingerprint(
        sizeBytes: 4096,
        modifiedAt: DateTime.utc(2026, 8, 6),
        sha256Digest: 'a' * 64,
      );
}
