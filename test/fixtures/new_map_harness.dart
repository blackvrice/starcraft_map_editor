import 'dart:typed_data';
import 'package:starcraft_map_editor/application/documents/new_map_controller.dart';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_picker.dart';
import 'package:starcraft_map_editor/application/ports/map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_tile_atlas_gateway.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/application/settings/starcraft_data_asset_settings_controller.dart';
import 'package:starcraft_map_editor/application/terrain/tile_placement_catalog_loader.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';

class NewMapHarness {
  final progress = OperationProgressController();
  final picker = NewMapPicker();
  final catalog = NewMapCatalog();
  var assets = StarCraftDataAssetSettingsState(
    status: StarCraftDataAssetSettingsStatus.ready,
    configuredPath: r'C:\StarCraft',
  );
  late final maps = OpenMapController(
    archiveGateway: _NoArchive(),
    filePicker: picker,
    fingerprintGateway: _NoFingerprint(),
    recentProjectsService: RecentProjectsService(InMemorySettingsStore()),
    operationProgressController: progress,
  );
  NewMapController controller() => NewMapController(
    maps: maps,
    assets: () => assets,
    loader: TilePlacementCatalogLoader(
      catalogGateway: catalog,
      tileAtlasGateway: _Atlas(),
    ),
  );
  Future<void> dispose() async {
    await maps.dispose();
    await progress.dispose();
  }
}

class NewMapPicker implements MapFilePicker {
  String? path;
  @override
  Future<String?> pickMapPath() async => path;
  @override
  Future<String?> pickSaveMapPath({required String suggestedName}) async =>
      path;
}

class _NoArchive implements MapArchiveGateway {
  @override
  Future<MapArchiveOpenResult> open(MapArchiveOpenRequest request) =>
      throw StateError('No source archive should be opened.');
  @override
  Future<MapArchiveWriteResult> writeTemporary(
    MapArchiveWriteRequest request,
  ) => throw UnimplementedError();
  @override
  Future<bool> cancel(String operationId) async => false;
}

class _NoFingerprint implements MapFileFingerprintGateway {
  @override
  Future<MapFileFingerprint> fingerprint(String path) =>
      throw StateError('No source fingerprint should be requested.');
}

class NewMapCatalog implements StarCraftPlacementCatalogGateway {
  Future<void> Function()? beforeReturn;
  bool fail = false;
  @override
  Future<void> cancel(String operationId) async {}
  @override
  Future<StarCraftPlacementCatalogPage> list(
    StarCraftPlacementCatalogRequest request,
  ) async {
    await beforeReturn?.call();
    if (fail) throw StateError('catalog failed');
    return StarCraftPlacementCatalogPage(
      request: request,
      totalEntries: 128,
      entries: [
        for (var id = request.offset; id < request.offset + request.limit; id++)
          StarCraftPlacementCatalogEntry(
            key: StarCraftPlacementCatalogKey.tile(
              tileset: request.tileset,
              rawValue: id,
            ),
            source: StarCraftPlacementCatalogSource.localData,
            availability: StarCraftPlacementAvailability.placeable,
          ),
      ],
      storageProduct: 's1',
      storageBuildNumber: 13515,
      helperVersion: '0.11.0',
      cascLibRevision: 'test',
    );
  }
}

class _Atlas implements StarCraftTileAtlasGateway {
  @override
  Future<StarCraftTileAtlasResult> render(
    StarCraftTileAtlasRequest request,
  ) async => StarCraftTileAtlasResult(
    request: request,
    tileSize: 32,
    columns: request.rawValues.length,
    rows: 1,
    rawValues: request.rawValues,
    rgbaBytes: Uint8List(request.rawValues.length * 4096),
    unsupportedRawValues: const [],
    storageProduct: 's1',
    storageBuildNumber: 13515,
    helperVersion: '0.11.0',
    cascLibRevision: 'test',
  );
}
