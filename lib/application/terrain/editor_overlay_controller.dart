import 'dart:async';
import '../../domain/placement/preplaced_unit_power_layout.dart';
import '../../domain/placement/unit_power_catalog.dart';
import '../../domain/placement/unit_range_projection.dart';
import '../../domain/terrain/terrain_analysis_view.dart';
import '../documents/opened_map_session.dart';
import '../layers/map_layer_controller.dart';
import '../placement/placement_catalog_controller.dart';

/// Explicit local-data loading; painting/selection never launches a helper.
final class EditorOverlayController {
  EditorOverlayController(this.catalog) {
    _maps = catalog.openMapController.changes.listen((_) => _notify());
    _catalog = catalog.changes.listen((_) => _notify());
  }
  final PlacementCatalogController catalog;
  late final StreamSubscription<Object?> _maps, _catalog;
  final _changes = StreamController<void>.broadcast(sync: true);
  Stream<void> get changes => _changes.stream;
  bool _disposed = false,
      loading = false,
      showRanges = false,
      showLayoutPower = false;
  TerrainAnalysisMode mode = TerrainAnalysisMode.off;
  int owner = 0;
  String? error;
  OpenedMapSession? _viewSession, _powerSession;
  TerrainAnalysisView? _view;
  UnitPowerCatalog? _powerCatalog;
  UnitPowerField? _field;
  int? _powerOwner;

  void configure({
    TerrainAnalysisMode? mode,
    bool? ranges,
    bool? power,
    int? owner,
  }) {
    if (_disposed) return;
    if (owner != null) RangeError.checkValueInInterval(owner, 0, 7, 'owner');
    this.mode = mode ?? this.mode;
    showRanges = ranges ?? showRanges;
    showLayoutPower = power ?? showLayoutPower;
    this.owner = owner ?? this.owner;
    _notify();
  }

  TerrainAnalysisView? get view {
    final session = catalog.openMapController.state.session;
    final grids = session?.terrainViews.tileMaps;
    if (_disposed ||
        session == null ||
        session.requiresRestrictedEditing ||
        grids?.length != 1) {
      return null;
    }
    final grid = grids!.single;
    if (!grid.hasGridDimensions ||
        grid.width == null ||
        grid.height == null ||
        grid.tileCount != grid.width! * grid.height!) {
      return null;
    }
    final source = catalog.inspectionTerrainSource;
    if (!identical(session, _viewSession) ||
        !identical(_view?.source, source?.snapshot)) {
      _viewSession = session;
      _view = TerrainAnalysisView(
        width: grid.width!,
        height: grid.height!,
        rawValues: grid.rawTileValues,
        source: source?.snapshot,
        revision: source?.revision,
      );
    }
    return _view;
  }

  UnitRangeProjection ranges(MapLayerState layers) {
    final session = catalog.openMapController.state.session, grid = view;
    final sections = session?.objectViews.unitSections;
    if (!showRanges ||
        grid == null ||
        sections?.length != 1 ||
        !layers.statusOf(MapLayerType.units).isVisible) {
      return UnitRangeProjection.fromDat(
        dat: null,
        selected: const [],
        mapWidth: 1,
        mapHeight: 1,
      );
    }
    final section = sections!.single;
    final selected = layers.selections.where(
      (s) =>
          s.object.layer == MapLayerType.units &&
          s.object.sectionIndex == section.sectionIndex &&
          s.object.recordIndex >= 0 &&
          s.object.recordIndex < section.units.length,
    );
    return UnitRangeProjection.fromDat(
      dat: catalog.inspectionDatSource?.snapshot,
      selected: selected.map((s) => section.units[s.object.recordIndex]),
      mapWidth: grid.width,
      mapHeight: grid.height,
    );
  }

  UnitPowerField? get powerField {
    if (_disposed || !showLayoutPower) return null;
    final session = catalog.openMapController.state.session, grid = view;
    final power = catalog.inspectionPowerCatalog;
    if (session == null ||
        grid == null ||
        power == null ||
        session.objectViews.unitSections.length > 1) {
      return null;
    }
    if (!identical(session, _powerSession) ||
        !identical(power, _powerCatalog) ||
        owner != _powerOwner) {
      _powerSession = session;
      _powerCatalog = power;
      _powerOwner = owner;
      final units = session.objectViews.unitSections.expand((s) => s.units);
      _field = units.length > 10000
          ? null
          : power.project(
              owner: owner,
              mapWidthTiles: grid.width,
              mapHeightTiles: grid.height,
              existing: PreplacedUnitPowerLayout.project(units),
            );
      if ((_field?.providers.length ?? 0) > 256) _field = null;
    }
    return _field;
  }

  Future<void> load() async {
    if (_disposed || loading) return;
    loading = true;
    error = null;
    final epoch = catalog.weaponReferenceEpoch;
    final document = catalog.openMapController.state.session?.extractedMap;
    _notify();
    try {
      if (showRanges) await catalog.loadEudData();
      if (showLayoutPower && !await catalog.loadCollisionMetadata()) {
        throw StateError('OVERLAY_UNIT_DATA_UNAVAILABLE');
      }
      if (mode == TerrainAnalysisMode.elevation ||
          mode == TerrainAnalysisMode.buildable ||
          mode == TerrainAnalysisMode.walkable) {
        if (!await catalog.loadTerrainPlacement()) {
          throw StateError('OVERLAY_TERRAIN_DATA_UNAVAILABLE');
        }
      }
    } on Object catch (e) {
      if (!_disposed &&
          epoch == catalog.weaponReferenceEpoch &&
          identical(
            document,
            catalog.openMapController.state.session?.extractedMap,
          )) {
        error = '$e';
      }
    } finally {
      if (!_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) _changes.add(null);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _maps.cancel();
    await _catalog.cancel();
    await _changes.close();
  }
}
