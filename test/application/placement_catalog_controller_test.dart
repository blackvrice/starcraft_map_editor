import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/editing/object_editing_controller.dart';
import 'package:starcraft_map_editor/application/editing/object_placement.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/placement/placement_catalog_controller.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_picker.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_object_atlas_gateway.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_tile_atlas_gateway.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/application/terrain/terrain_editing_controller.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';
import 'package:starcraft_map_editor/domain/placement/unit_placement_capability.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';

const _installationPath = r'C:\StarCraft';

void main() {
  test('invalidates cached choices when the installation changes', () async {
    final fixture = await _openFixture();
    addTearDown(fixture.dispose);
    fixture.controller.setInstallationPath(_installationPath);
    await fixture.controller.load(StarCraftPlacementKind.doodad);
    fixture.controller.confirm(fixture.controller.state.items.first.key);
    fixture.controller.setInstallationPath(r'C:\OtherStarCraft');
    expect(fixture.controller.state.items, isEmpty);
    expect(fixture.controller.state.selection, isNull);
    expect(await fixture.controller.loadMore(), isFalse);
  });

  test('reopening even the same map invalidates a pending catalog', () async {
    final gateway = _DeferredCatalogGateway();
    final fixture = await _openFixture(catalogGateway: gateway);
    addTearDown(fixture.dispose);
    fixture.controller.synchronizeSession(
      fixture.openMapController.state.session,
    );
    fixture.controller.setInstallationPath(_installationPath);
    final pending = fixture.controller.load(StarCraftPlacementKind.doodad);
    final state = await fixture.openMapController.open(
      sourcePath: r'C:\Maps\Catalog.scx',
    );
    // A newly opened map has its own extracted snapshot, even at the same path.
    fixture.controller.synchronizeSession(state.session);
    gateway.complete();
    expect(await pending, isFalse);
    expect(fixture.controller.state.items, isEmpty);
    expect(fixture.controller.state.isLoading, isFalse);
  });

  test('pending catalog completion after disposal is ignored', () async {
    final gateway = _DeferredCatalogGateway();
    final fixture = await _openFixture(catalogGateway: gateway);
    fixture.controller.setInstallationPath(_installationPath);
    final pending = fixture.controller.load(StarCraftPlacementKind.doodad);
    await fixture.dispose();
    gateway.complete();
    expect(await pending, isFalse);
  });

  test('refuses to browse without an installation path', () async {
    final fixture = await _openFixture();
    addTearDown(fixture.dispose);

    expect(
      await fixture.controller.load(StarCraftPlacementKind.doodad),
      isFalse,
    );
    expect(
      fixture.controller.state.diagnostics.single.code,
      PlacementCatalogDiagnosticCodes.installationMissing,
    );
    expect(fixture.controller.state.items, isEmpty);
  });

  test(
    'loads a Doodad page and keeps browsing free of document changes',
    () async {
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);
      fixture.controller.setInstallationPath(_installationPath);

      expect(
        await fixture.controller.load(StarCraftPlacementKind.doodad),
        isTrue,
      );

      final state = fixture.controller.state;
      expect(state.kind, StarCraftPlacementKind.doodad);
      expect(state.items, hasLength(2));
      expect(state.tileset, StarCraftTilesetAssetSet.jungle);
      expect(state.items.first.isPlaceable, isTrue);
      expect(state.items.last.isPlaceable, isFalse);
      expect(
        state.items.last.issueCode,
        'SC_CATALOG_ITEM_DOODAD_RECIPE_INVALID',
      );

      fixture.controller.preview(state.items.first.key);
      expect(fixture.controller.state.previewItem?.key, state.items.first.key);
      expect(fixture.openMapController.state.session!.isDirty, isFalse);
      expect(fixture.objectEditingController.state.undoDepth, 0);
    },
  );

  test('filters by display name and numeric id', () async {
    final fixture = await _openFixture();
    addTearDown(fixture.dispose);
    fixture.controller.setInstallationPath(_installationPath);
    await fixture.controller.load(StarCraftPlacementKind.doodad);

    fixture.controller.setQuery('#7');
    expect(fixture.controller.state.visibleItems, hasLength(1));
    expect(fixture.controller.state.visibleItems.single.key.id, 7);

    fixture.controller.setQuery('jungle tree');
    expect(fixture.controller.state.visibleItems, hasLength(1));
    expect(fixture.controller.state.visibleItems.single.key.id, 7);

    fixture.controller.setQuery('');
    expect(fixture.controller.state.visibleItems, hasLength(2));
  });

  test('refuses to confirm an unplaceable entry', () async {
    final fixture = await _openFixture();
    addTearDown(fixture.dispose);
    fixture.controller.setInstallationPath(_installationPath);
    await fixture.controller.load(StarCraftPlacementKind.doodad);
    final broken = fixture.controller.state.items.last;

    expect(fixture.controller.confirm(broken.key), isFalse);
    expect(fixture.controller.state.selection, isNull);
    expect(
      fixture.controller.state.lastPlacementIssueCode,
      'SC_CATALOG_ITEM_DOODAD_RECIPE_INVALID',
    );
  });

  test('places a confirmed Doodad centred on the clicked tile', () async {
    final fixture = await _openFixture();
    addTearDown(fixture.dispose);
    fixture.controller.setInstallationPath(_installationPath);
    await fixture.controller.load(StarCraftPlacementKind.doodad);
    final entry = fixture.controller.state.items.first;

    expect(fixture.controller.confirm(entry.key), isTrue);
    expect(fixture.controller.state.isPlacementActive, isTrue);
    expect(fixture.controller.state.recentKeys, [entry.key]);

    final result = fixture.controller.placeAt(
      pixelX: 3 * 32 + 16,
      pixelY: 2 * 32 + 16,
      tileX: 3,
      tileY: 2,
    );

    expect(result.isPlaced, isTrue);
    final session = fixture.openMapController.state.session!;
    expect(
      session.objectViews.doodadSections.single.doodads.last.doodadType,
      7,
    );
    final tiles = session.terrainViews.tileMaps.single.rawTileValues;
    // A two tile wide footprint centred on tile 3 starts at tile 2.
    expect(tiles[2 * 8 + 2], 200 * 16);
    expect(tiles[2 * 8 + 3], 200 * 16 + 1);
    expect(fixture.controller.state.selection, isNull, reason: 'single place');
  });

  test('keeps the selection while continuous placement is on', () async {
    final fixture = await _openFixture();
    addTearDown(fixture.dispose);
    fixture.controller.setInstallationPath(_installationPath);
    await fixture.controller.load(StarCraftPlacementKind.doodad);
    fixture.controller
      ..setContinuous(true)
      ..confirm(fixture.controller.state.items.first.key);

    expect(
      fixture.controller
          .placeAt(pixelX: 112, pixelY: 80, tileX: 3, tileY: 2)
          .isPlaced,
      isTrue,
    );
    expect(fixture.controller.state.selection, isNotNull);

    expect(
      fixture.controller
          .placeAt(pixelX: 176, pixelY: 144, tileX: 5, tileY: 4)
          .isPlaced,
      isTrue,
    );
    expect(
      fixture
          .openMapController
          .state
          .session!
          .objectViews
          .doodadSections
          .single
          .doodads,
      hasLength(3),
    );

    fixture.controller.cancelSelection();
    expect(fixture.controller.state.selection, isNull);
  });

  test('reports a refusal without changing the document', () async {
    final fixture = await _openFixture();
    addTearDown(fixture.dispose);
    fixture.controller.setInstallationPath(_installationPath);
    await fixture.controller.load(StarCraftPlacementKind.doodad);
    fixture.controller.confirm(fixture.controller.state.items.first.key);

    final result = fixture.controller.placeAt(
      pixelX: 0,
      pixelY: 0,
      tileX: 0,
      tileY: 0,
    );

    expect(result.isPlaced, isFalse);
    expect(result.issueCode, ObjectPlacementDiagnosticCodes.outOfBounds);
    expect(
      fixture.controller.state.lastPlacementIssueCode,
      ObjectPlacementDiagnosticCodes.outOfBounds,
    );
    expect(fixture.openMapController.state.session!.isDirty, isFalse);
  });

  test(
    'confirming a Tile arms the terrain brush instead of the cursor',
    () async {
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);
      fixture.controller.setInstallationPath(_installationPath);

      expect(
        await fixture.controller.load(StarCraftPlacementKind.tile),
        isTrue,
      );
      final tile = fixture.controller.state.items.single;
      expect(tile.hasThumbnail, isTrue);

      expect(fixture.controller.confirm(tile.key), isTrue);
      expect(fixture.controller.state.isPlacementActive, isFalse);
      expect(
        fixture.terrainEditingController.state.selectedRawTileValue,
        tile.key.id,
      );
      expect(
        fixture.terrainEditingController.state.tool,
        TerrainEditingTool.brush,
      );
    },
  );

  test('places a Unit once the helper reports its capability', () async {
    final fixture = await _openFixture(unitCapabilityAvailable: true);
    addTearDown(fixture.dispose);
    fixture.controller.setInstallationPath(_installationPath);
    await fixture.controller.load(StarCraftPlacementKind.unit);

    final unit = fixture.controller.state.items.single;
    expect(unit.isPlaceable, isTrue);
    expect(unit.displayName, 'Terran Marine');
    expect(fixture.controller.confirm(unit.key), isTrue);

    final result = fixture.controller.placeAt(
      pixelX: 96,
      pixelY: 64,
      tileX: 3,
      tileY: 2,
    );

    expect(result.isPlaced, isTrue);
    final placed = fixture
        .openMapController
        .state
        .session!
        .objectViews
        .unitSections
        .single
        .units
        .single;
    expect(placed.unitType, unit.key.id);
    expect(placed.x, 96);
    expect(placed.y, 64);
    expect(placed.hitpointPercent, 100);
  });

  test(
    'keeps Unit entries visible but unplaceable until capability lands',
    () async {
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);
      fixture.controller.setInstallationPath(_installationPath);

      await fixture.controller.load(StarCraftPlacementKind.unit);
      final unit = fixture.controller.state.items.single;

      expect(unit.isPlaceable, isFalse);
      expect(unit.issueCode, 'SC_CATALOG_ITEM_UNIT_CAPABILITY_UNAVAILABLE');
      expect(fixture.controller.confirm(unit.key), isFalse);
    },
  );

  test('appends the next page when the grid asks for more', () async {
    final fixture = await _openFixture(doodadTotal: 4);
    addTearDown(fixture.dispose);
    fixture.controller.setInstallationPath(_installationPath);
    await fixture.controller.load(StarCraftPlacementKind.doodad);

    expect(fixture.controller.state.items, hasLength(2));
    expect(fixture.controller.state.hasMore, isTrue);

    expect(await fixture.controller.loadMore(), isTrue);
    expect(fixture.controller.state.items, hasLength(4));
    expect(fixture.controller.state.hasMore, isFalse);
    expect(await fixture.controller.loadMore(), isFalse);
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

Future<_Fixture> _openFixture({
  int doodadTotal = 2,
  bool unitCapabilityAvailable = false,
  StarCraftPlacementCatalogGateway? catalogGateway,
}) async {
  final chkBytes = _chkBytes();
  final map = ExtractedMap(
    sourcePath: r'C:\Maps\Catalog.scx',
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
    archiveGateway: _FixtureArchiveGateway(map),
    filePicker: const _NoMapFilePicker(),
    fingerprintGateway: const _FixtureFingerprintGateway(),
    recentProjectsService: RecentProjectsService(InMemorySettingsStore()),
    operationProgressController: progressController,
  );
  final state = await openMapController.open(sourcePath: map.sourcePath);
  expect(state.status, OpenMapStatus.opened);
  final mapLayerController = MapLayerController()
    ..synchronizeSession(state.session);
  final objectEditingController = ObjectEditingController(
    openMapController: openMapController,
    mapLayerController: mapLayerController,
  )..synchronizeSession(state.session);
  final terrainEditingController = TerrainEditingController(
    openMapController: openMapController,
  )..synchronizeSession(state.session);
  final gateway = _FakeCatalogGateway(
    doodadTotal: doodadTotal,
    unitCapabilityAvailable: unitCapabilityAvailable,
  );
  final controller = PlacementCatalogController(
    openMapController: openMapController,
    objectEditingController: objectEditingController,
    terrainEditingController: terrainEditingController,
    catalogGateway: catalogGateway ?? gateway,
    tileAtlasGateway: const _FakeTileAtlasGateway(),
    objectAtlasGateway: const _FakeObjectAtlasGateway(),
    pageSize: 2,
  );
  return _Fixture(
    openMapController: openMapController,
    mapLayerController: mapLayerController,
    objectEditingController: objectEditingController,
    terrainEditingController: terrainEditingController,
    controller: controller,
    progressController: progressController,
  );
}

DoodadPlacementRecipe _recipe({int doodadType = 7, int startTileGroup = 200}) =>
    DoodadPlacementRecipe(
      tileset: StarCraftTilesetAssetSet.jungle,
      startTileGroup: startTileGroup,
      doodadType: doodadType,
      width: 2,
      height: 1,
      centerOffsetX: 32,
      centerOffsetY: 16,
      footprint: [
        DoodadFootprintCell(
          x: 0,
          y: 0,
          rawTileValue: startTileGroup * 16,
          requiredTileGroup: 0,
        ),
        DoodadFootprintCell(
          x: 1,
          y: 0,
          rawTileValue: startTileGroup * 16 + 1,
          requiredTileGroup: 0,
        ),
      ],
    );

final class _DeferredCatalogGateway
    implements StarCraftPlacementCatalogGateway {
  final result = Completer<StarCraftPlacementCatalogPage>();
  late StarCraftPlacementCatalogRequest request;

  @override
  Future<StarCraftPlacementCatalogPage> list(
    StarCraftPlacementCatalogRequest value,
  ) {
    request = value;
    return result.future;
  }

  void complete() => result.complete(
    StarCraftPlacementCatalogPage(
      request: request,
      totalEntries: 0,
      entries: const [],
      storageProduct: 's1',
      storageBuildNumber: 13515,
      helperVersion: '0.8.0',
      cascLibRevision: 'abc',
    ),
  );

  @override
  Future<void> cancel(String operationId) async {}
}

final class _FakeCatalogGateway implements StarCraftPlacementCatalogGateway {
  _FakeCatalogGateway({
    required this.doodadTotal,
    required this.unitCapabilityAvailable,
  });

  final int doodadTotal;
  final bool unitCapabilityAvailable;

  @override
  Future<StarCraftPlacementCatalogPage> list(
    StarCraftPlacementCatalogRequest request,
  ) async {
    final entries = <StarCraftPlacementCatalogEntry>[];
    final total = switch (request.kind) {
      StarCraftPlacementKind.doodad => doodadTotal,
      _ => 1,
    };
    for (
      var index = request.offset;
      index < total && entries.length < request.limit;
      index++
    ) {
      entries.add(_entry(request.kind, request.tileset, index));
    }
    return StarCraftPlacementCatalogPage(
      request: request,
      totalEntries: total,
      entries: entries,
      storageProduct: 's1',
      storageBuildNumber: 13515,
      helperVersion: '0.7.0',
      cascLibRevision: 'abc',
    );
  }

  @override
  Future<void> cancel(String operationId) async {}

  StarCraftPlacementCatalogEntry _entry(
    StarCraftPlacementKind kind,
    StarCraftTilesetAssetSet tileset,
    int index,
  ) {
    switch (kind) {
      case StarCraftPlacementKind.doodad:
        final broken = index == 1;
        final doodadId = index == 0 ? 7 : 100 + index;
        final startTileGroup = 200 + index;
        return StarCraftPlacementCatalogEntry(
          key: StarCraftPlacementCatalogKey.doodad(
            tileset: tileset,
            doodadId: doodadId,
            startTileGroup: startTileGroup,
          ),
          source: StarCraftPlacementCatalogSource.localData,
          availability: broken
              ? StarCraftPlacementAvailability.unsupported
              : StarCraftPlacementAvailability.placeable,
          verifiedName: broken ? null : 'Jungle Tree',
          issue: broken
              ? StarCraftPlacementCatalogIssue(
                  code: 'SC_CATALOG_ITEM_DOODAD_RECIPE_INVALID',
                  message: 'The local Doodad recipe is invalid.',
                )
              : null,
          doodadRecipe: broken
              ? null
              : _recipe(doodadType: doodadId, startTileGroup: startTileGroup),
          doodadRecipeIssueCode: broken ? 'SC_CASC_DOODAD_TRUNCATED' : null,
        );
      case StarCraftPlacementKind.tile:
        return StarCraftPlacementCatalogEntry(
          key: StarCraftPlacementCatalogKey.tile(
            tileset: tileset,
            rawValue: 3200 + index,
          ),
          source: StarCraftPlacementCatalogSource.localData,
          availability: StarCraftPlacementAvailability.placeable,
        );
      case StarCraftPlacementKind.unit:
        if (unitCapabilityAvailable) {
          return StarCraftPlacementCatalogEntry(
            key: StarCraftPlacementCatalogKey.unit(index),
            source: StarCraftPlacementCatalogSource.localData,
            availability: StarCraftPlacementAvailability.placeable,
            verifiedName: 'Terran Marine',
            unitCapability: UnitPlacementCapability(
              unitId: index,
              isSpellcaster: false,
              hasShields: false,
              isResourceContainer: false,
              isGasResourceContainer: false,
              hasHangar: false,
              isFlyingBuilding: false,
              isBurrowable: false,
              isCloakable: false,
              isInvincible: false,
              isBuilding: false,
              requiresRelationLink: false,
            ),
          );
        }
        return StarCraftPlacementCatalogEntry(
          key: StarCraftPlacementCatalogKey.unit(index),
          source: StarCraftPlacementCatalogSource.localData,
          availability: StarCraftPlacementAvailability.unsupported,
          issue: StarCraftPlacementCatalogIssue(
            code: 'SC_CATALOG_ITEM_UNIT_CAPABILITY_UNAVAILABLE',
            message: 'Verified unit capability data is unavailable.',
          ),
          previewIssueCode: 'SC_CASC_OBJECT_PREVIEW_UNAVAILABLE',
        );
      case StarCraftPlacementKind.pureSprite:
      case StarCraftPlacementKind.spriteUnit:
        return StarCraftPlacementCatalogEntry(
          key: StarCraftPlacementCatalogKey.pureSprite(index),
          source: StarCraftPlacementCatalogSource.localData,
          availability: StarCraftPlacementAvailability.placeable,
        );
    }
  }
}

final class _FakeTileAtlasGateway implements StarCraftTileAtlasGateway {
  const _FakeTileAtlasGateway();

  @override
  Future<StarCraftTileAtlasResult> render(
    StarCraftTileAtlasRequest request,
  ) async {
    final count = request.rawValues.length;
    return StarCraftTileAtlasResult(
      request: request,
      tileSize: StarCraftTileAtlasResult.expectedTileSize,
      columns: count,
      rows: count == 0 ? 0 : 1,
      rawValues: request.rawValues,
      rgbaBytes: Uint8List(
        count *
            StarCraftTileAtlasResult.expectedTileSize *
            StarCraftTileAtlasResult.expectedTileSize *
            StarCraftTileAtlasResult.bytesPerPixel,
      ),
      unsupportedRawValues: const [],
      storageProduct: 's1',
      storageBuildNumber: 13515,
      helperVersion: '0.7.0',
      cascLibRevision: 'abc',
    );
  }
}

final class _FakeObjectAtlasGateway implements StarCraftObjectAtlasGateway {
  const _FakeObjectAtlasGateway();

  @override
  Future<StarCraftObjectAtlasResult> render(
    StarCraftObjectAtlasRequest request,
  ) async => StarCraftObjectAtlasResult(
    request: request,
    entries: [
      for (final key in request.objects)
        StarCraftObjectAtlasEntry(
          key: key,
          spriteId: key.id,
          imageId: key.id,
          width: 2,
          height: 2,
          anchorX: 1,
          anchorY: 1,
          frameIndex: StarCraftObjectPreviewPolicy.framePolicy.frameIndex,
          rgbaBytes: Uint8List(2 * 2 * 4),
        ),
    ],
    unsupportedObjects: const [],
    storageProduct: 's1',
    storageBuildNumber: 13515,
    helperVersion: '0.7.0',
    cascLibRevision: 'abc',
  );

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
    _section('DD2 ', Uint8List(ChkDoodadPlacement.recordLength)),
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

final class _FixtureArchiveGateway implements MapArchiveGateway {
  const _FixtureArchiveGateway(this.map);

  final ExtractedMap map;

  @override
  Future<MapArchiveOpenResult> open(MapArchiveOpenRequest request) async =>
      MapArchiveOpenResult.success(
        map: ExtractedMap(
          sourcePath: request.sourcePath,
          scenarioChkBytes: map.scenarioChkBytes,
          metadata: map.metadata,
        ),
      );

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

final class _FixtureFingerprintGateway implements MapFileFingerprintGateway {
  const _FixtureFingerprintGateway();

  @override
  Future<MapFileFingerprint> fingerprint(String path) async =>
      MapFileFingerprint(
        sizeBytes: 4096,
        modifiedAt: DateTime.utc(2026, 8, 6),
        sha256Digest: 'a' * 64,
      );
}
