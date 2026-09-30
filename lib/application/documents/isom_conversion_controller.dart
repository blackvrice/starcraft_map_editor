import '../../domain/terrain/isom_terrain_conversion.dart';
import '../ports/isom_terrain_catalog_gateway.dart';
import 'open_map_controller.dart';
import 'opened_map_session.dart';

/// Explicit preview/application boundary; not enabled in UI without a verified
/// local-data provider. No archive or process I/O is performed by this class.
class IsomConversionController {
  IsomConversionController({required this.maps, required this.catalogs});
  final OpenMapController maps;
  final IsomTerrainCatalogGateway catalogs;
  int _generation = 0;
  OpenedMapSession? _source;
  IsomConversionPreview? _preview;

  void invalidate() {
    _generation++;
    _source = null;
    _preview = null;
  }

  void _check(OpenedMapSession source) {
    final progress = maps.operationProgressController.current;
    if (!identical(source, maps.state.session) ||
        source.requiresRestrictedEditing ||
        maps.editHistory.isTransactionActive ||
        (progress != null && !progress.isTerminal)) {
      throw StateError('The map changed or another operation is active.');
    }
  }

  Future<IsomConversionPreview> preview({required int seed}) async {
    invalidate();
    final generation = _generation;
    final source = maps.state.session;
    if (source == null) throw StateError('Open a map first.');
    _check(source);
    final sets = source.metadataViews.tilesets;
    if (sets.length != 1 || sets.single.knownTileset == null) {
      throw StateError('A known unique tileset is required.');
    }
    final catalog = await catalogs.load(tileset: sets.single.rawValue);
    _check(source);
    if (generation != _generation) {
      throw StateError('The conversion request was replaced.');
    }
    final preview = const IsomTerrainConverter().preview(
      source.rawDocument,
      catalog,
      seed: seed,
    );
    _source = source;
    _preview = preview;
    return preview;
  }

  bool apply(IsomConversionPreview preview) {
    final before = _source;
    if (before == null || !identical(preview, _preview)) {
      throw StateError('Refresh the conversion preview.');
    }
    _check(before);
    if (preview.changedTileCount == 0) {
      invalidate();
      return false;
    }
    final terrain = maps.terrainViewDecoder.decode(preview.result);
    if (terrain.hasBlockingDiagnostics) {
      throw StateError('Converted terrain failed validation.');
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
      label: 'Convert ISOM terrain',
      before: before,
      after: after,
      undo: () => maps.adoptEditedSession(before),
      redo: () => maps.adoptEditedSession(after),
    );
    invalidate();
    return true;
  }
}
