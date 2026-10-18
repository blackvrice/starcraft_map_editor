import 'dart:async';
import '../../domain/terrain/terrain_analysis_view.dart';
import '../documents/open_map_controller.dart';
import '../documents/opened_map_session.dart';
import '../documents/isom_fill_controller.dart';
import '../ports/terrain_placement_snapshot_gateway.dart';
import '../settings/starcraft_data_asset_settings_controller.dart';

final class TerrainAnalysisController {
  TerrainAnalysisController({
    required this.maps,
    required this.assets,
    this.gateway,
  }) {
    _maps = maps.changes.listen((_) {
      if (_operation case final operation?) {
        _epoch++;
        gateway?.cancel(operation);
        _operation = null;
      }
      _view = null;
      _viewSession = null;
      _notify();
    });
  }
  factory TerrainAnalysisController.fromEditor(
    OpenMapController maps,
    IsomFillController? loader,
  ) => TerrainAnalysisController(
    maps: maps,
    assets:
        loader?.assets ?? () => const StarCraftDataAssetSettingsState.loading(),
    gateway: loader?.gateway is TerrainPlacementSnapshotGateway
        ? loader!.gateway as TerrainPlacementSnapshotGateway
        : null,
  );
  final OpenMapController maps;
  final StarCraftDataAssetSettingsState Function() assets;
  final TerrainPlacementSnapshotGateway? gateway;
  late final StreamSubscription<Object?> _maps;
  final _changes = StreamController<void>.broadcast(sync: true);
  Stream<void> get changes => _changes.stream;
  TerrainPlacementReadResult? lastRead;
  TerrainPlacementSource? _source;
  StarCraftDataAssetSettingsState? _loadedAssets;
  Object? _loadedMap;
  TerrainAnalysisView? _view;
  OpenedMapSession? _viewSession;
  bool _disposed = false;
  int _epoch = 0;
  static int _nextOperation = 0;
  String? _operation;
  TerrainAnalysisMode mode = TerrainAnalysisMode.off;
  bool get loading => _operation != null;
  TerrainPlacementSource? get source {
    final session = maps.state.session;
    final tilesets = session?.metadataViews.tilesets;
    return !_disposed &&
            session != null &&
            identical(session.extractedMap, _loadedMap) &&
            identical(assets(), _loadedAssets) &&
            assets().isReady &&
            tilesets?.length == 1 &&
            tilesets!.single.rawValue == _source?.snapshot.tileset
        ? _source
        : null;
  }

  TerrainAnalysisView? get view {
    final session = maps.state.session;
    if (_disposed ||
        session == null ||
        session.terrainViews.tileMaps.length != 1) {
      return null;
    }
    final grid = session.terrainViews.tileMaps.single;
    if (!grid.hasGridDimensions ||
        grid.width == null ||
        grid.height == null ||
        grid.tileCount != grid.width! * grid.height!) {
      return null;
    }
    final current = source;
    if (!identical(session, _viewSession) ||
        !identical(_view?.source, current?.snapshot)) {
      _viewSession = session;
      _view = TerrainAnalysisView(
        width: grid.width!,
        height: grid.height!,
        rawValues: grid.rawTileValues,
        source: current?.snapshot,
        revision: current?.revision,
      );
    }
    return _view;
  }

  void setMode(TerrainAnalysisMode value) {
    if (_disposed || mode == value) return;
    mode = value;
    _notify();
  }

  Future<bool> load() async {
    if (_disposed) return false;
    final old = _operation;
    if (old != null) gateway?.cancel(old);
    final epoch = ++_epoch, session = maps.state.session, settings = assets();
    _source = null;
    _loadedAssets = null;
    _view = null;
    lastRead = null;
    final tilesets = session?.metadataViews.tilesets;
    final port = gateway, path = settings.configuredPath;
    if (session == null ||
        session.requiresRestrictedEditing ||
        port == null ||
        !settings.isReady ||
        path == null ||
        path.isEmpty ||
        tilesets?.length != 1 ||
        tilesets!.single.rawValue < 0 ||
        tilesets.single.rawValue > 7) {
      _operation = null;
      _notify();
      return false;
    }
    final operation = 'terrain-analysis-${++_nextOperation}';
    _operation = operation;
    _notify();
    try {
      final result = await port.readPlacement(
        operationId: operation,
        installationPath: path,
        tileset: tilesets.single.rawValue,
      );
      if (_disposed ||
          epoch != _epoch ||
          !identical(session, maps.state.session) ||
          !identical(settings, assets())) {
        return false;
      }
      lastRead = result;
      final data = result.source;
      if (!result.isSuccess ||
          data == null ||
          data.snapshot.tileset != tilesets.single.rawValue ||
          data.revision.isEmpty ||
          data.helperVersion.isEmpty ||
          data.cascLibRevision.isEmpty ||
          data.storageProduct.isEmpty ||
          data.storageBuildNumber < 0) {
        return false;
      }
      _source = data;
      _loadedAssets = settings;
      _loadedMap = session.extractedMap;
      return true;
    } finally {
      if (!_disposed && epoch == _epoch) {
        _operation = null;
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
    _epoch++;
    if (_operation case final operation?) gateway?.cancel(operation);
    _source = null;
    _view = null;
    await _maps.cancel();
    await _changes.close();
  }
}
