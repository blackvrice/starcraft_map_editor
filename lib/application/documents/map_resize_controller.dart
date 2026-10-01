import '../../domain/chk/map_resize.dart';
import '../../domain/chk/typed/chk_player_settings_editor.dart';
import 'open_map_controller.dart';
import 'opened_map_session.dart';
import 'isom_fill_controller.dart';
import '../settings/starcraft_data_asset_settings_controller.dart';
import '../../domain/terrain/map_resize_terrain.dart';

class MapResizeController {
  MapResizeController(this.maps, {this.terrainLoader})
    : source = maps.state.session {
    if (source == null) throw StateError('Open a map first.');
  }
  final OpenMapController maps;
  final OpenedMapSession? source;
  final IsomFillController? terrainLoader;
  MapResizeTerrainData? _terrainData;
  StarCraftDataAssetSettingsState? _settings;
  bool _disposed = false;
  bool get needsTerrainData => source!.rawDocument.sections.any(
    (s) => s.name == 'ISOM' || (s.name == 'DD2 ' && s.payload.isNotEmpty),
  );
  Future<void> loadTerrain() async {
    _check();
    if (!needsTerrainData) return;
    final loader = terrainLoader;
    if (loader == null) {
      throw StateError('Configure local StarCraft terrain data first.');
    }
    final settings = loader.assets();
    final catalog = await loader.load();
    _check();
    if (!identical(settings, loader.assets()) ||
        !identical(source, loader.source) ||
        catalog.brush == null) {
      throw StateError('Terrain data changed. Reopen Resize Map.');
    }
    _settings = settings;
    _terrainData = MapResizeTerrainData(
      catalog: catalog.catalog,
      brush: catalog.brush!,
      solids: catalog.shapes,
      recipes: loader.doodadRecipes,
    );
  }

  void dispose() {
    _disposed = true;
    if (needsTerrainData) terrainLoader?.invalidate();
    _preview = null;
    _terrainData = null;
  }

  MapResizePreview? _preview;

  void _check() {
    final progress = maps.operationProgressController.current;
    if (_disposed ||
        !identical(source, maps.state.session) ||
        (_settings != null && !identical(_settings, terrainLoader?.assets())) ||
        source!.requiresRestrictedEditing ||
        maps.editHistory.isTransactionActive ||
        (progress != null && !progress.isTerminal)) {
      throw StateError(
        'The document changed, is read-only, or an operation is active. Reopen Resize Map.',
      );
    }
  }

  MapResizePreview preview(MapResizeOptions options) {
    _preview = null;
    _check();
    return _preview = const MapResizeEditor().preview(
      source!.rawDocument,
      options,
      terrainData: _terrainData,
    );
  }

  void apply(MapResizePreview preview, {required bool acceptCropping}) {
    _check();
    if (!identical(_preview, preview)) {
      throw StateError('Refresh the resize preview.');
    }
    final before = source!;
    final document = preview.apply(acceptCropping: acceptCropping);
    final metadata = maps.metadataViewDecoder.decode(document);
    final strings = maps.stringViewDecoder.decode(document);
    final terrain = maps.terrainViewDecoder.decode(document);
    final objects = maps.objectViewDecoder.decode(document);
    final oldCodes = {
      ...before.metadataViews.diagnostics.map((d) => d.code),
      ...before.stringViews.diagnostics.map((d) => d.code),
      ...before.terrainViews.diagnostics.map((d) => d.code),
      ...before.objectViews.diagnostics.map((d) => d.code),
      ...maps.objectReferenceValidator
          .validate(
            metadataViews: before.metadataViews,
            stringViews: before.stringViews,
            objectViews: before.objectViews,
          )
          .map((d) => d.code),
      ...const ChkPlayerSettingsEditor()
          .diagnostics(before.rawDocument)
          .map((d) => d.code),
    };
    final diagnostics = [
      ...before.diagnostics.where((d) => !oldCodes.contains(d.code)),
      ...metadata.diagnostics,
      ...strings.diagnostics,
      ...terrain.diagnostics,
      ...objects.diagnostics,
      ...maps.objectReferenceValidator.validate(
        metadataViews: metadata,
        stringViews: strings,
        objectViews: objects,
      ),
      ...const ChkPlayerSettingsEditor().diagnostics(document),
    ];
    if (diagnostics.any((d) => d.blocksOperation)) {
      throw StateError('Resized map validation failed.');
    }
    final after = OpenedMapSession(
      extractedMap: before.extractedMap,
      rawDocument: document,
      metadataViews: metadata,
      stringViews: strings,
      terrainViews: terrain,
      objectViews: objects,
      sourceFingerprint: before.sourceFingerprint,
      diagnostics: diagnostics,
      resourceEdits: before.resourceEdits,
    );
    maps.adoptEditedSession(after);
    maps.editHistory.record(
      label: 'Resize map',
      before: before,
      after: after,
      undo: () => maps.adoptEditedSession(before),
      redo: () => maps.adoptEditedSession(after),
    );
  }
}
