import '../../domain/terrain/isom_terrain_fill.dart';
import '../../domain/terrain/isom_terrain_conversion.dart';
import '../../domain/terrain/isom_terrain_paint.dart';
import '../../domain/terrain/isom_doodad_overlay.dart';
import '../../domain/placement/doodad_placement_recipe.dart';
import '../../domain/chk/typed/chk_terrain_views.dart';
import '../../domain/assets/starcraft_data_asset_manifest.dart';
import '../ports/starcraft_placement_catalog_gateway.dart';
import '../terrain/terrain_tile_atlas_loader.dart';
import '../ports/terrain_connection_snapshot_gateway.dart';
import '../settings/starcraft_data_asset_settings_controller.dart';
import '../terrain/solid_isom_catalog_builder.dart';
import '../terrain/transition_isom_catalog_builder.dart';
import 'open_map_controller.dart';
import 'opened_map_session.dart';

class IsomFillController {
  IsomFillController({
    required this.maps,
    required this.assets,
    required this.gateway,
    this.placementGateway,
    this.atlasLoader,
  });
  final OpenMapController maps;
  final StarCraftDataAssetSettingsState Function() assets;
  final TerrainConnectionSnapshotGateway gateway;
  final StarCraftPlacementCatalogGateway? placementGateway;
  final TerrainTileAtlasLoader? atlasLoader;
  List<DoodadPlacementRecipe> _recipes = [];
  List<DoodadPlacementRecipe> get ramps =>
      List.unmodifiable(_recipes.where((r) => r.hasRamp));
  List<DoodadPlacementRecipe> get doodadRecipes => List.unmodifiable(_recipes);
  OpenedMapSession? get source => _source;
  static int _next = 0;
  String? _operation;
  OpenedMapSession? _source;
  StarCraftDataAssetSettingsState? _assets;
  SolidIsomCatalog? _catalog;
  IsomFillPreview? _preview;
  TerrainSnapshotReadResult? lastRead;

  void invalidate() {
    if (_operation case final String id) {
      gateway.cancel(id);
      placementGateway?.cancel(id);
    }
    _operation = null;
    _source = null;
    _assets = null;
    _catalog = null;
    _preview = null;
    _recipes = [];
  }

  void _check(OpenedMapSession source) {
    final p = maps.operationProgressController.current;
    if (!identical(source, maps.state.session) ||
        source.requiresRestrictedEditing ||
        maps.editHistory.isTransactionActive ||
        (p != null && !p.isTerminal)) {
      throw StateError('The map changed or another operation is active.');
    }
  }

  Future<SolidIsomCatalog> load() async {
    invalidate();
    final source = maps.state.session;
    if (source == null) throw StateError('Open a map first.');
    _check(source);
    final settings = assets();
    if (!settings.isReady || settings.configuredPath == null) {
      throw StateError('Configure StarCraft data in Settings first.');
    }
    final sets = source.metadataViews.tilesets;
    if (sets.length != 1 || sets.single.knownTileset == null) {
      throw StateError('A unique known tileset is required.');
    }
    final id = 'isom-fill-${++_next}';
    _operation = id;
    final read = await gateway.read(
      operationId: id,
      installationPath: settings.configuredPath!,
      tileset: sets.single.rawValue,
    );
    if (_operation != id) throw StateError('Terrain request cancelled.');
    lastRead = read;
    _check(source);
    if (!identical(settings, assets())) {
      throw StateError('StarCraft data settings changed.');
    }
    if (!read.isSuccess) {
      throw StateError(read.errorCode ?? 'Terrain data unavailable.');
    }
    if (read.snapshot!.tileset != sets.single.rawValue) {
      throw StateError('Terrain tileset mismatch.');
    }
    final catalog = const TransitionIsomCatalogBuilder().build(read.snapshot!);
    final recipes = <DoodadPlacementRecipe>[];
    if (placementGateway case final StarCraftPlacementCatalogGateway pg) {
      var offset = 0;
      do {
        final page = await pg.list(
          StarCraftPlacementCatalogRequest(
            operationId: id,
            installationPath: settings.configuredPath!,
            kind: StarCraftPlacementKind.doodad,
            tileset: StarCraftTilesetAssetSet.values[sets.single.rawValue],
            offset: offset,
            limit: 256,
          ),
        );
        if (_operation != id) throw StateError('Terrain request cancelled.');
        if (!page.isSuccess) throw StateError('Doodad metadata unavailable.');
        recipes.addAll(
          page.entries
              .map((e) => e.doodadRecipe)
              .whereType<DoodadPlacementRecipe>(),
        );
        if (page.nextOffset == null) break;
        if (page.nextOffset! <= offset) {
          throw StateError('Invalid catalog pagination.');
        }
        offset = page.nextOffset!;
      } while (true);
    }
    _operation = null;
    _check(source);
    if (!identical(settings, assets())) {
      throw StateError('StarCraft data settings changed.');
    }
    _recipes = recipes;
    _source = source;
    _assets = settings;
    _catalog = catalog;
    return catalog;
  }

  IsomFillPreview preview({required int terrainType, int seed = 0}) {
    _preview = null;
    final source = _source, catalog = _catalog;
    if (source == null || catalog == null) {
      throw StateError('Load terrain data first.');
    }
    _check(source);
    if (!identical(_assets, assets())) {
      throw StateError('StarCraft data settings changed.');
    }
    final shape = catalog.shapes[terrainType];
    if (shape == null) throw StateError('Unsupported solid terrain type.');
    return _preview = const IsomTerrainFill().preview(
      source.rawDocument,
      catalog.catalog,
      solidValue: shape << 4,
      seed: seed,
    );
  }

  bool apply(IsomFillPreview preview) {
    final before = _source;
    if (before == null || !identical(preview, _preview)) {
      throw StateError('Refresh the preview.');
    }
    _check(before);
    if (!identical(_assets, assets())) {
      throw StateError('StarCraft data settings changed.');
    }
    if (!preview.hasChanges) return false;
    final terrain = maps.terrainViewDecoder.decode(preview.result);
    if (terrain.hasBlockingDiagnostics) {
      throw StateError('Terrain validation failed.');
    }
    final after = OpenedMapSession(
      extractedMap: before.extractedMap,
      rawDocument: preview.result,
      metadataViews: before.metadataViews,
      stringViews: before.stringViews,
      terrainViews: terrain,
      objectViews: maps.objectViewDecoder.decode(preview.result),
      sourceFingerprint: before.sourceFingerprint,
      resourceEdits: before.resourceEdits,
      diagnostics: before.diagnostics,
    );
    maps.adoptEditedSession(after);
    maps.editHistory.record(
      label: 'Edit isometric terrain',
      before: before,
      after: after,
      undo: () => maps.adoptEditedSession(before),
      redo: () => maps.adoptEditedSession(after),
    );
    invalidate();
    return true;
  }

  IsomFillPreview previewConversion({int seed = 0}) {
    _preview = null;
    final source = _source, catalog = _catalog;
    if (source == null || catalog == null) {
      throw StateError('Load terrain data first.');
    }
    _check(source);
    if (!identical(_assets, assets())) {
      throw StateError('StarCraft data settings changed.');
    }
    return _preview = IsomFillPreview.fromConversion(
      const IsomTerrainConverter().preview(
        source.rawDocument,
        catalog.catalog,
        seed: seed,
        requireKnownSourcePairs: true,
      ),
    );
  }

  IsomFillPreview previewPaint({
    required int terrainType,
    required Set<IsomDiamond> diamonds,
    IsomFillPreview? basePreview,
    int seed = 0,
  }) {
    if (basePreview != null && !identical(basePreview, _preview)) {
      throw StateError('Stale brush preview.');
    }
    final source = _source, catalog = _catalog;
    if (source == null || catalog?.brush == null) {
      throw StateError('Load terrain first.');
    }
    _check(source);
    if (!identical(_assets, assets())) {
      throw StateError('StarCraft data settings changed.');
    }
    final overlay = IsomDoodadOverlay.read(
      basePreview?.result ?? source.rawDocument,
      _recipes,
    );
    final painted = const IsomTerrainPaint().preview(
      overlay.base,
      catalog!.catalog,
      catalog.brush!,
      solidShape: catalog.shapes[terrainType]!,
      diamonds: diamonds,
      seed: seed,
    );
    final result = overlay.restore(painted.result);
    final oldTiles = maps.terrainViewDecoder
        .decode(source.rawDocument)
        .tileMaps
        .single
        .rawTileValues;
    final newTiles = maps.terrainViewDecoder
        .decode(result)
        .tileMaps
        .single
        .rawTileValues;
    return _preview = IsomFillPreview.fromEdit(
      source.rawDocument,
      result,
      changedTileCount: List.generate(
        oldTiles.length,
        (i) => i,
      ).where((i) => oldTiles[i] != newTiles[i]).length,
      isomChanged: painted.isomChanged || basePreview?.isomChanged == true,
      catalogRevision: catalog.catalog.revision,
    );
  }

  IsomFillPreview previewRamp({
    required DoodadPlacementRecipe recipe,
    required int x,
    required int y,
  }) {
    _preview = null;
    final source = _source, catalog = _catalog;
    if (source == null || catalog == null || !_recipes.contains(recipe)) {
      throw StateError('Load ramps first.');
    }
    _check(source);
    if (!identical(_assets, assets())) {
      throw StateError('StarCraft data settings changed.');
    }
    final overlay = IsomDoodadOverlay.read(source.rawDocument, _recipes);
    const IsomTerrainConverter().preview(
      overlay.base,
      catalog.catalog,
      seed: 0,
      requireKnownSourcePairs: true,
    );
    final result = IsomDoodadOverlay.placeRamp(
      source.rawDocument,
      recipe,
      x: x,
      y: y,
      recipes: _recipes,
    );
    return _preview = IsomFillPreview.fromEdit(
      source.rawDocument,
      result,
      changedTileCount: recipe.footprint.where((c) => c.writesTerrain).length,
      isomChanged: false,
      catalogRevision: catalog.catalog.revision,
    );
  }

  ChkTerrainViews previewTerrainViews(IsomFillPreview? preview) {
    final source = _source;
    if (source == null) throw StateError('Load terrain first.');
    _check(source);
    return maps.terrainViewDecoder.decode(
      preview?.result ?? source.rawDocument,
    );
  }

  ChkTerrainTileMapView previewTerrain(IsomFillPreview? preview) =>
      previewTerrainViews(preview).tileMaps.single;

  void discardPreview() {
    _preview = null;
  }
}
