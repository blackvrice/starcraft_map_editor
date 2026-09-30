import '../../domain/terrain/isom_terrain_fill.dart';
import '../ports/terrain_connection_snapshot_gateway.dart';
import '../settings/starcraft_data_asset_settings_controller.dart';
import '../terrain/solid_isom_catalog_builder.dart';
import 'open_map_controller.dart';
import 'opened_map_session.dart';

class IsomFillController {
  IsomFillController({
    required this.maps,
    required this.assets,
    required this.gateway,
  });
  final OpenMapController maps;
  final StarCraftDataAssetSettingsState Function() assets;
  final TerrainConnectionSnapshotGateway gateway;
  static int _next = 0;
  String? _operation;
  OpenedMapSession? _source;
  StarCraftDataAssetSettingsState? _assets;
  SolidIsomCatalog? _catalog;
  IsomFillPreview? _preview;
  TerrainSnapshotReadResult? lastRead;

  void invalidate() {
    if (_operation case final String id) gateway.cancel(id);
    _operation = null;
    _source = null;
    _assets = null;
    _catalog = null;
    _preview = null;
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
    _operation = null;
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
    final catalog = const SolidIsomCatalogBuilder().build(read.snapshot!);
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
      objectViews: before.objectViews,
      sourceFingerprint: before.sourceFingerprint,
      resourceEdits: before.resourceEdits,
      diagnostics: before.diagnostics,
    );
    maps.adoptEditedSession(after);
    maps.editHistory.record(
      label: 'Fill isometric terrain',
      before: before,
      after: after,
      undo: () => maps.adoptEditedSession(before),
      redo: () => maps.adoptEditedSession(after),
    );
    invalidate();
    return true;
  }
}
