import 'dart:async';

import '../../domain/chk/chk.dart';
import '../documents/open_map_controller.dart';
import '../documents/opened_map_session.dart';
import '../ports/map_archive_gateway.dart';

enum TerrainEditingTool { select, brush, rectangle }

final class TerrainTileCoordinate {
  const TerrainTileCoordinate({required this.x, required this.y});

  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is TerrainTileCoordinate && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

final class TerrainTileRegion {
  const TerrainTileRegion._({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  factory TerrainTileRegion.fromCorners(
    TerrainTileCoordinate first,
    TerrainTileCoordinate second,
  ) {
    return TerrainTileRegion._(
      left: first.x < second.x ? first.x : second.x,
      top: first.y < second.y ? first.y : second.y,
      right: first.x > second.x ? first.x : second.x,
      bottom: first.y > second.y ? first.y : second.y,
    );
  }

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get tileCount => (right - left + 1) * (bottom - top + 1);
}

final class TerrainEditingState {
  const TerrainEditingState({
    this.tool = TerrainEditingTool.select,
    this.selectedRawTileValue,
    this.selectedTile,
  });

  final TerrainEditingTool tool;
  final int? selectedRawTileValue;
  final TerrainTileCoordinate? selectedTile;

  bool get hasSelectedTile => selectedRawTileValue != null;
}

class TerrainEditingController {
  TerrainEditingController({
    required this.openMapController,
    this.terrainViewDecoder = const ChkTerrainViewDecoder(),
  });

  final OpenMapController openMapController;
  final ChkTerrainViewDecoder terrainViewDecoder;
  final StreamController<TerrainEditingState> _changes =
      StreamController<TerrainEditingState>.broadcast(sync: true);

  TerrainEditingState _state = const TerrainEditingState();
  ExtractedMap? _trackedSourceSnapshot;

  TerrainEditingState get state => _state;

  Stream<TerrainEditingState> get changes => _changes.stream;

  bool get canSelectTiles => _activeTerrainView != null;

  bool get canEditTerrain {
    final session = openMapController.state.session;
    return session != null &&
        !session.requiresRestrictedEditing &&
        !_containsProtectionMarker(session.rawDocument) &&
        _activeTerrainViewFor(session) != null;
  }

  void synchronizeSession(OpenedMapSession? session) {
    final sourceSnapshot = session?.extractedMap;
    if (identical(sourceSnapshot, _trackedSourceSnapshot)) {
      return;
    }

    _trackedSourceSnapshot = sourceSnapshot;
    _emit(const TerrainEditingState());
  }

  void setTool(TerrainEditingTool tool) {
    if (_state.tool == tool) {
      return;
    }
    _emit(
      TerrainEditingState(
        tool: tool,
        selectedRawTileValue: _state.selectedRawTileValue,
        selectedTile: _state.selectedTile,
      ),
    );
  }

  int selectTileAt(TerrainTileCoordinate coordinate) {
    final terrain = _activeTerrainView;
    if (terrain == null) {
      throw StateError(
        'Tile selection requires one MTXM grid with valid dimensions.',
      );
    }

    final rawValue = terrain.rawTileValueAt(x: coordinate.x, y: coordinate.y);
    _emit(
      TerrainEditingState(
        tool: _state.tool,
        selectedRawTileValue: rawValue,
        selectedTile: coordinate,
      ),
    );
    return rawValue;
  }

  bool paintTiles(Iterable<TerrainTileCoordinate> coordinates) {
    final rawValue = _state.selectedRawTileValue;
    if (!canEditTerrain || rawValue == null) {
      return false;
    }

    final terrain = _activeTerrainView!;
    final values = terrain.rawTileValues.toList();
    var changed = false;
    for (final coordinate in coordinates.toSet()) {
      final index = _checkedIndex(terrain, coordinate);
      if (values[index] != rawValue) {
        values[index] = rawValue;
        changed = true;
      }
    }
    return changed && _replaceTerrainValues(terrain, values);
  }

  bool fillRectangle(TerrainTileRegion region) {
    final rawValue = _state.selectedRawTileValue;
    if (!canEditTerrain || rawValue == null) {
      return false;
    }

    final terrain = _activeTerrainView!;
    _checkedIndex(
      terrain,
      TerrainTileCoordinate(x: region.left, y: region.top),
    );
    _checkedIndex(
      terrain,
      TerrainTileCoordinate(x: region.right, y: region.bottom),
    );

    final values = terrain.rawTileValues.toList();
    var changed = false;
    for (var y = region.top; y <= region.bottom; y++) {
      for (var x = region.left; x <= region.right; x++) {
        final index = y * terrain.width! + x;
        if (values[index] != rawValue) {
          values[index] = rawValue;
          changed = true;
        }
      }
    }
    return changed && _replaceTerrainValues(terrain, values);
  }

  bool _replaceTerrainValues(ChkTerrainTileMapView terrain, List<int> values) {
    final session = openMapController.state.session;
    if (session == null) {
      return false;
    }

    final rawDocument = session.rawDocument.replaceSection(
      terrain.sectionIndex,
      terrain.withRawTileValues(values),
    );
    final terrainViews = terrainViewDecoder.decode(rawDocument);
    if (terrainViews.hasBlockingDiagnostics ||
        terrainViews.tileMaps.length != 1) {
      throw StateError('The edited MTXM section failed terrain validation.');
    }

    openMapController.adoptEditedSession(
      OpenedMapSession(
        extractedMap: session.extractedMap,
        rawDocument: rawDocument,
        metadataViews: session.metadataViews,
        terrainViews: terrainViews,
        sourceFingerprint: session.sourceFingerprint,
        diagnostics: session.diagnostics,
      ),
    );
    return true;
  }

  ChkTerrainTileMapView? get _activeTerrainView {
    final session = openMapController.state.session;
    return session == null ? null : _activeTerrainViewFor(session);
  }

  ChkTerrainTileMapView? _activeTerrainViewFor(OpenedMapSession session) {
    if (session.terrainViews.tileMaps.length != 1) {
      return null;
    }
    final terrain = session.terrainViews.tileMaps.single;
    if (!terrain.hasGridDimensions ||
        terrain.width == null ||
        terrain.height == null) {
      return null;
    }
    return terrain;
  }

  int _checkedIndex(
    ChkTerrainTileMapView terrain,
    TerrainTileCoordinate coordinate,
  ) {
    terrain.rawTileValueAt(x: coordinate.x, y: coordinate.y);
    return coordinate.y * terrain.width! + coordinate.x;
  }

  bool _containsProtectionMarker(RawChkDocument document) =>
      document.sections.any((section) => section.isEuddraftProtectionMarker);

  void _emit(TerrainEditingState state) {
    _state = state;
    _changes.add(state);
  }

  Future<void> dispose() => _changes.close();
}
