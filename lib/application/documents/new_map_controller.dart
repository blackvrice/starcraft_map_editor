import '../../domain/assets/starcraft_data_asset_manifest.dart';
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
  }) : expectedSession = maps.state.session;

  final OpenMapController maps;
  final TilePlacementCatalogLoader? loader;
  final StarCraftDataAssetSettingsState Function() assets;
  final OpenedMapSession? expectedSession;
  TilePlacementCatalogBatch? _batch;
  StarCraftDataAssetSettingsState? _verifiedAssets;
  static int _operationSequence = 0;
  int _revision = 0;
  bool _disposed = false;

  Future<TilePlacementCatalogBatch> loadTiles(
    StarCraftTilesetAssetSet tileset, {
    int offset = 0,
  }) async {
    final revision = ++_revision;
    _batch = null;
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
    _disposed = true;
    ++_revision;
    _batch = null;
  }
}
