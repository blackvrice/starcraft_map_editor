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
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';
import 'package:starcraft_map_editor/presentation/placement/placement_catalog_dialog.dart';

void main() {
  testWidgets('lists catalog entries and keeps unplaceable ones visible', (
    tester,
  ) async {
    final fixture = await _fixture();
    addTearDown(fixture.dispose);
    await _pumpDialog(tester, fixture.controller);

    expect(find.byKey(const Key('placement-catalog-dialog')), findsOneWidget);
    expect(find.byKey(const Key('placement-catalog-tab-tile')), findsOneWidget);
    expect(
      find.byKey(const Key('placement-catalog-tab-doodad')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('placement-catalog-tab-unit')), findsOneWidget);
    expect(
      find.byKey(const Key('placement-catalog-tab-pureSprite')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('placement-catalog-tab-doodad')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('placement-catalog-grid')), findsOneWidget);
    expect(find.text('Jungle Tree'), findsOneWidget);
    expect(find.text('Doodad #101'), findsOneWidget);
  });

  testWidgets('shows why an entry cannot be placed and disables Place', (
    tester,
  ) async {
    final fixture = await _fixture();
    addTearDown(fixture.dispose);
    await _pumpDialog(tester, fixture.controller);
    await tester.tap(find.byKey(const Key('placement-catalog-tab-doodad')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Doodad #101'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('placement-catalog-detail-issue')),
      findsOneWidget,
    );
    expect(
      find.textContaining('SC_CATALOG_ITEM_DOODAD_RECIPE_INVALID'),
      findsOneWidget,
    );
    final place = tester.widget<FilledButton>(
      find.byKey(const Key('placement-catalog-place')),
    );
    expect(place.onPressed, isNull);
    expect(fixture.controller.state.selection, isNull);
  });

  testWidgets('search filters the grid by name and numeric id', (tester) async {
    final fixture = await _fixture();
    addTearDown(fixture.dispose);
    await _pumpDialog(tester, fixture.controller);
    await tester.tap(find.byKey(const Key('placement-catalog-tab-doodad')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('placement-catalog-search')),
      '#101',
    );
    await tester.pumpAndSettle();

    expect(find.text('Jungle Tree'), findsNothing);
    expect(find.text('Doodad #101'), findsOneWidget);
  });

  testWidgets('Place confirms the selection and closes the dialog', (
    tester,
  ) async {
    final fixture = await _fixture();
    addTearDown(fixture.dispose);
    await _pumpDialog(tester, fixture.controller);
    await tester.tap(find.byKey(const Key('placement-catalog-tab-doodad')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jungle Tree'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('placement-catalog-place')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('placement-catalog-dialog')), findsNothing);
    expect(fixture.controller.state.selection, isNotNull);
    expect(fixture.controller.state.selection!.displayName, 'Jungle Tree');
    expect(fixture.controller.state.isPlacementActive, isTrue);
    expect(
      fixture.openMapController.state.session!.isDirty,
      isFalse,
      reason: 'confirming a selection must not change the document',
    );
  });

  testWidgets('Cancel closes without arming a placement', (tester) async {
    final fixture = await _fixture();
    addTearDown(fixture.dispose);
    await _pumpDialog(tester, fixture.controller);
    await tester.tap(find.byKey(const Key('placement-catalog-tab-doodad')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jungle Tree'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('placement-catalog-cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('placement-catalog-dialog')), findsNothing);
    expect(fixture.controller.state.selection, isNull);
  });

  testWidgets('explains why the catalog cannot be browsed', (tester) async {
    final fixture = await _fixture(withInstallation: false);
    addTearDown(fixture.dispose);
    await _pumpDialog(tester, fixture.controller);

    expect(find.byKey(const Key('placement-catalog-blocked')), findsOneWidget);
    expect(find.byKey(const Key('placement-catalog-grid')), findsNothing);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester,
  PlacementCatalogController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPlacementCatalogDialog(
              context: context,
              controller: controller,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
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

Future<_Fixture> _fixture({bool withInstallation = true}) async {
  final chkBytes = _chkBytes();
  final map = ExtractedMap(
    sourcePath: r'C:\Maps\Dialog.scx',
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
    archiveGateway: _DialogArchiveGateway(map),
    filePicker: const _NoMapFilePicker(),
    fingerprintGateway: const _DialogFingerprintGateway(),
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
    catalogGateway: const _DialogCatalogGateway(),
  );
  if (withInstallation) {
    controller.setInstallationPath(r'C:\StarCraft');
  }
  return _Fixture(
    openMapController: openMapController,
    mapLayerController: mapLayerController,
    objectEditingController: objectEditingController,
    terrainEditingController: terrainEditingController,
    controller: controller,
    progressController: progressController,
  );
}

final class _DialogCatalogGateway implements StarCraftPlacementCatalogGateway {
  const _DialogCatalogGateway();

  @override
  Future<StarCraftPlacementCatalogPage> list(
    StarCraftPlacementCatalogRequest request,
  ) async {
    if (request.kind != StarCraftPlacementKind.doodad) {
      return StarCraftPlacementCatalogPage(request: request, totalEntries: 0);
    }
    return StarCraftPlacementCatalogPage(
      request: request,
      totalEntries: 2,
      entries: [
        StarCraftPlacementCatalogEntry(
          key: StarCraftPlacementCatalogKey.doodad(
            tileset: request.tileset,
            doodadId: 7,
            startTileGroup: 200,
          ),
          source: StarCraftPlacementCatalogSource.localData,
          availability: StarCraftPlacementAvailability.placeable,
          verifiedName: 'Jungle Tree',
          doodadRecipe: _recipe(),
        ),
        StarCraftPlacementCatalogEntry(
          key: StarCraftPlacementCatalogKey.doodad(
            tileset: request.tileset,
            doodadId: 101,
            startTileGroup: 201,
          ),
          source: StarCraftPlacementCatalogSource.localData,
          availability: StarCraftPlacementAvailability.unsupported,
          issue: StarCraftPlacementCatalogIssue(
            code: 'SC_CATALOG_ITEM_DOODAD_RECIPE_INVALID',
            message: 'The local Doodad recipe is invalid.',
          ),
          doodadRecipeIssueCode: 'SC_CASC_DOODAD_TRUNCATED',
        ),
      ],
    );
  }

  @override
  Future<void> cancel(String operationId) async {}
}

DoodadPlacementRecipe _recipe() => DoodadPlacementRecipe(
  tileset: StarCraftTilesetAssetSet.jungle,
  startTileGroup: 200,
  doodadType: 7,
  width: 1,
  height: 1,
  centerOffsetX: 16,
  centerOffsetY: 16,
  footprint: [
    DoodadFootprintCell(
      x: 0,
      y: 0,
      rawTileValue: 200 * 16,
      requiredTileGroup: 0,
    ),
  ],
);

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

final class _DialogArchiveGateway implements MapArchiveGateway {
  const _DialogArchiveGateway(this.map);

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

final class _DialogFingerprintGateway implements MapFileFingerprintGateway {
  const _DialogFingerprintGateway();

  @override
  Future<MapFileFingerprint> fingerprint(String path) async =>
      MapFileFingerprint(
        sizeBytes: 4096,
        modifiedAt: DateTime.utc(2026, 8, 6),
        sha256Digest: 'a' * 64,
      );
}
