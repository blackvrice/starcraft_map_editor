import 'dart:typed_data';
import '../../domain/assets/starcraft_data_asset_manifest.dart';
import '../ports/terrain_connection_snapshot_gateway.dart';
import '../ports/starcraft_tile_atlas_gateway.dart';
import '../terrain/solid_isom_catalog_builder.dart';
import '../../domain/chk/new_map_factory.dart';
import '../ports/starcraft_placement_catalog_gateway.dart';
import '../settings/starcraft_data_asset_settings_controller.dart';
import '../terrain/tile_placement_catalog_loader.dart';
import 'open_map_controller.dart';
import 'opened_map_session.dart';

/// A dialog-scoped selection. Only the latest verified page can create a map.
final class NewMapController {
  NewMapController({
    required this.maps,
    required this.loader,
    required this.assets,
    this.terrainGateway,
  }) : expectedSession = maps.state.session;

  final OpenMapController maps;
  final TilePlacementCatalogLoader? loader;
  final StarCraftDataAssetSettingsState Function() assets;
  final OpenedMapSession? expectedSession;
  final TerrainConnectionSnapshotGateway? terrainGateway;
  SolidIsomCatalog? _terrain;
  Map<int, Uint8List> _terrainPreviews = const {};
  Map<int, Uint8List> get terrainPreviews => _terrainPreviews;
  String? _terrainOperation;
  TilePlacementCatalogBatch? _batch;
  StarCraftDataAssetSettingsState? _verifiedAssets;
  static int _operationSequence = 0;
  int _revision = 0;
  bool _disposed = false;

  Future<SolidIsomCatalog> loadTerrain(StarCraftTilesetAssetSet tileset) async {
    final revision = ++_revision;
    _terrain = null;
    _batch = null;
    _verifiedAssets = null;
    _terrainPreviews = const {};
    _cancelTerrain();
    final state = assets();
    if (_disposed ||
        terrainGateway == null ||
        loader == null ||
        !state.isReady ||
        state.configuredPath == null) {
      throw StateError('Configure StarCraft data before creating terrain.');
    }
    final operation = 'new-terrain-${++_operationSequence}';
    _terrainOperation = operation;
    final read = await terrainGateway!.read(
      operationId: operation,
      installationPath: state.configuredPath!,
      tileset: tileset.rawValue,
    );
    if (_disposed || revision != _revision || !identical(state, assets())) {
      throw StateError('Terrain selection changed. Reload terrain.');
    }
    if (!read.isSuccess || read.snapshot!.tileset != tileset.rawValue) {
      throw StateError(read.errorCode ?? 'Terrain verification failed.');
    }
    final terrain = const SolidIsomCatalogBuilder().build(read.snapshot!);
    final representatives = <int, int>{
      for (final type in terrain.shapes.keys)
        type:
            (terrain.catalog.pairs
                    .firstWhere((p) => p.terrainType == type)
                    .leftGroup <<
                4) |
            terrain.catalog.pairs
                .firstWhere((p) => p.terrainType == type)
                .members
                .first,
    };
    final request = StarCraftTileAtlasRequest(
      installationPath: state.configuredPath!,
      tileset: tileset,
      rawValues: representatives.values.toSet().toList()..sort(),
    );
    final atlas = await loader!.tileAtlasGateway.render(request);
    if (_disposed || revision != _revision || !identical(state, assets())) {
      throw StateError('Terrain selection changed. Reload terrain.');
    }
    if (!atlas.isSuccess ||
        atlas.request.installationPath != request.installationPath ||
        atlas.helperVersion != read.snapshot!.helperVersion ||
        atlas.storageProduct != read.snapshot!.storageProduct ||
        atlas.storageBuildNumber != read.snapshot!.storageBuildNumber ||
        atlas.unsupportedRawValues.isNotEmpty ||
        atlas.request.tileset != tileset ||
        atlas.rawValues.length != request.rawValues.length ||
        atlas.rawValues.asMap().entries.any(
          (e) => e.value != request.rawValues[e.key],
        )) {
      throw StateError('Terrain previews could not be verified.');
    }
    _terrainPreviews = Map.unmodifiable({
      for (final entry in representatives.entries)
        entry.key: _tilePixels(atlas, atlas.rawValues.indexOf(entry.value)),
    });
    _terrain = terrain;
    _verifiedAssets = state;
    _terrainOperation = null;
    return terrain;
  }

  NewMapOptions terrainOptions(NewMapOptions options, int type, int seed) {
    final terrain = _terrain;
    if (_disposed ||
        terrain == null ||
        !identical(_verifiedAssets, assets()) ||
        terrain.catalog.tileset != options.tileset.rawValue ||
        !terrain.shapes.containsKey(type)) {
      throw StateError('Select verified terrain from the current tileset.');
    }
    return NewMapOptions(
      width: options.width,
      height: options.height,
      tileset: options.tileset,
      rawTileValue: options.rawTileValue,
      humanPlayers: options.humanPlayers,
      title: options.title,
      description: options.description,
      terrainCatalog: terrain.catalog,
      solidTerrainValue: terrain.shapes[type]! << 4,
      terrainSeed: seed,
    );
  }

  Future<TilePlacementCatalogBatch> loadTiles(
    StarCraftTilesetAssetSet tileset, {
    int offset = 0,
  }) async {
    final revision = ++_revision;
    _cancelTerrain();
    _batch = null;
    _terrain = null;
    _verifiedAssets = null;
    final state = assets();
    if (_disposed ||
        loader == null ||
        !state.isReady ||
        state.configuredPath == null) {
      throw StateError(
        'Configure StarCraft Data Assets in Settings before creating a map.',
      );
    }
    final batch = await loader!.load(
      StarCraftPlacementCatalogRequest(
        operationId: 'new-map-${++_operationSequence}',
        installationPath: state.configuredPath!,
        kind: StarCraftPlacementKind.tile,
        tileset: tileset,
        offset: offset,
        limit: 64,
      ),
      isCancelled: () =>
          _disposed || revision != _revision || !identical(state, assets()),
    );
    if (_disposed || revision != _revision || !identical(state, assets())) {
      throw StateError('The tile selection changed. Reload the tiles.');
    }
    if (!batch.isSuccess || !batch.page.isSuccess) {
      throw StateError(
        'Tile verification failed. Check StarCraft Data Assets and retry.',
      );
    }
    _batch = batch;
    _verifiedAssets = state;
    return batch;
  }

  OpenedMapSession create(NewMapOptions options) {
    if (options.terrainCatalog != null) {
      if (_disposed ||
          _terrain == null ||
          !identical(options.terrainCatalog, _terrain!.catalog) ||
          !identical(_verifiedAssets, assets()) ||
          !_terrain!.shapes.values.any(
            (shape) => shape << 4 == options.solidTerrainValue,
          )) {
        throw StateError('Refresh the verified terrain selection.');
      }
      return maps.createNew(options, expectedSession: expectedSession).session!;
    }
    final batch = _batch;
    if (_disposed ||
        batch == null ||
        !identical(_verifiedAssets, assets()) ||
        batch.page.request.tileset.rawValue != options.tileset.rawValue ||
        !batch.page.entries.any(
          (e) => e.key.id == options.rawTileValue && e.isPlaceable,
        ) ||
        !batch.thumbnails.containsKey(options.rawTileValue)) {
      throw StateError('Select a verified initial tile from the current page.');
    }
    return maps.createNew(options, expectedSession: expectedSession).session!;
  }

  void dispose() {
    _cancelTerrain();
    _disposed = true;
    ++_revision;
    _batch = null;
    _terrain = null;
    _terrainPreviews = const {};
  }

  void _cancelTerrain() {
    final operation = _terrainOperation;
    if (operation != null) terrainGateway?.cancel(operation);
    _terrainOperation = null;
  }
}

Uint8List _tilePixels(StarCraftTileAtlasResult atlas, int index) {
  final pixels = Uint8List(32 * 32 * 4);
  for (var y = 0; y < 32; y++) {
    final source =
        (((index ~/ atlas.columns) * 32 + y) * atlas.columns * 32 +
            (index % atlas.columns) * 32) *
        4;
    pixels.setRange(y * 128, (y + 1) * 128, atlas.rgbaBytes, source);
  }
  return pixels.asUnmodifiableView();
}
