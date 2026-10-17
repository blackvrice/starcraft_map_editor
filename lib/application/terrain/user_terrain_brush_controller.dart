import '../../domain/chk/chk.dart';
import '../../domain/chk/chk_mixed_clipboard.dart';
import '../../domain/terrain/user_terrain_brush.dart';
import '../documents/isom_fill_controller.dart';
import '../documents/opened_map_session.dart';
import '../editing/basic_editing_controller.dart';
import '../layers/map_layer_controller.dart';
import 'solid_isom_catalog_builder.dart';

final class TerrainBrushPreview {
  TerrainBrushPreview._(this.source, this.result, this.brush, this.catalog);
  final OpenedMapSession source;
  final RawChkDocument result;
  final UserTerrainBrush brush;
  final SolidIsomCatalog? catalog;
}

final class UserTerrainBrushController {
  UserTerrainBrushController(this.editing, {this.loader});
  final BasicEditingController editing;
  final IsomFillController? loader;
  SolidIsomCatalog? _catalog;
  TerrainBrushPreview? _preview;
  bool _disposed = false;
  int _revision = 0;
  SolidIsomCatalog? get catalog =>
      !_disposed &&
          _catalog != null &&
          loader?.isClipboardCatalogCurrent(_catalog!) == true
      ? _catalog
      : null;
  TerrainBrushPreview? get preview => isPreviewCurrent ? _preview : null;
  bool get isPreviewCurrent =>
      !_disposed &&
      _preview != null &&
      identical(_preview!.source, editing.maps.state.session) &&
      (_preview!.catalog == null || identical(_preview!.catalog, catalog));
  void invalidate() => _preview = null;

  OpenedMapSession get _source {
    if (_disposed ||
        editing.maps.editHistory.isTransactionActive ||
        !editing.layers.state.statusOf(MapLayerType.terrain).isSelectable) {
      throw StateError('BRUSH_BUSY_OR_LAYER');
    }
    return editing.source;
  }

  Future<void> loadCatalog() async {
    invalidate();
    _catalog = null;
    final revision = ++_revision, source = _source, loader = this.loader;
    if (loader == null) throw StateError('BRUSH_CATALOG');
    final loaded = await loader.load();
    if (_disposed ||
        revision != _revision ||
        !identical(source, _source) ||
        !loader.isClipboardCatalogCurrent(loaded)) {
      throw StateError('BRUSH_STALE');
    }
    _catalog = loaded;
  }

  UserTerrainBrush capture(
    String name,
    ClipboardRegion region,
    TerrainBrushProfile profile,
  ) {
    invalidate();
    return UserTerrainBrush.capture(
      _source.rawDocument,
      name: name,
      region: region,
      profile: profile,
      catalog: catalog?.catalog,
      brush: catalog?.brush,
    );
  }

  TerrainBrushPreview previewPaste(
    UserTerrainBrush brush, {
    required int x,
    required int y,
    bool mirrorX = false,
    bool mirrorY = false,
  }) {
    invalidate();
    final source = _source;
    final data = brush.profile == TerrainBrushProfile.isom ? catalog : null;
    final result = brush.preview(
      source.rawDocument,
      x: x,
      y: y,
      catalog: data?.catalog,
      brush: data?.brush,
      solidShapes: data?.shapes.values.toSet() ?? {},
      mirrorX: mirrorX,
      mirrorY: mirrorY,
    );
    return _preview = TerrainBrushPreview._(source, result, brush, data);
  }

  bool apply(TerrainBrushPreview preview) {
    if (!identical(preview, _preview) ||
        !isPreviewCurrent ||
        !identical(preview.source, _source)) {
      throw StateError('BRUSH_STALE');
    }
    final changed = editing.apply(
      preview.source.rawDocument,
      preview.result,
      'Apply terrain brush',
    );
    invalidate();
    return changed;
  }

  void dispose() {
    _disposed = true;
    _revision++;
    invalidate();
    _catalog = null;
  }
}
