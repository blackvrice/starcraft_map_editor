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
    this.undoDepth = 0,
    this.redoDepth = 0,
    this.isBrushStrokeActive = false,
  });

  final TerrainEditingTool tool;
  final int? selectedRawTileValue;
  final TerrainTileCoordinate? selectedTile;
  final int undoDepth;
  final int redoDepth;
  final bool isBrushStrokeActive;

  bool get hasSelectedTile => selectedRawTileValue != null;

  bool get canUndo => undoDepth > 0 && !isBrushStrokeActive;

  bool get canRedo => redoDepth > 0 && !isBrushStrokeActive;
}

class TerrainEditingController {
  TerrainEditingController({
    required this.openMapController,
    this.terrainViewDecoder = const ChkTerrainViewDecoder(),
    this.historyLimit = 100,
  }) {
    if (historyLimit <= 0) {
      throw ArgumentError.value(
        historyLimit,
        'historyLimit',
        'The terrain edit history limit must be greater than zero.',
      );
    }
    openMapController.editHistory.constrainLimit(historyLimit);
    _historySubscription = openMapController.editHistory.changes.listen(
      (_) => _emitHistoryState(),
    );
    _sessionSubscription = openMapController.changes.listen(
      (state) => synchronizeSession(state.session),
    );
    synchronizeSession(openMapController.state.session);
  }

  final OpenMapController openMapController;
  final ChkTerrainViewDecoder terrainViewDecoder;
  final int historyLimit;
  final StreamController<TerrainEditingState> _changes =
      StreamController<TerrainEditingState>.broadcast(sync: true);
  late final StreamSubscription<void> _historySubscription;
  late final StreamSubscription<OpenMapState> _sessionSubscription;

  TerrainEditingState _state = const TerrainEditingState();
  ExtractedMap? _trackedSourceSnapshot;
  _TerrainEditCommand? _pendingBrushCommand;
  bool _isBrushStrokeActive = false;

  TerrainEditingState get state => _state;

  Stream<TerrainEditingState> get changes => _changes.stream;

  bool get canUndo =>
      openMapController.editHistory.canUndo && !_isBrushStrokeActive;

  bool get canRedo =>
      openMapController.editHistory.canRedo && !_isBrushStrokeActive;

  String? get undoLabel => openMapController.editHistory.undoLabel;

  String? get redoLabel => openMapController.editHistory.redoLabel;

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
    openMapController.editHistory.synchronizeSession(session);
    _pendingBrushCommand = null;
    _isBrushStrokeActive = false;
    _emit(const TerrainEditingState());
  }

  void setTool(TerrainEditingTool tool) {
    if (_state.tool == tool) {
      return;
    }
    if (_isBrushStrokeActive) {
      cancelBrushStroke();
    }
    _emit(
      TerrainEditingState(
        tool: tool,
        selectedRawTileValue: _state.selectedRawTileValue,
        selectedTile: _state.selectedTile,
        undoDepth: openMapController.editHistory.undoDepth,
        redoDepth: openMapController.editHistory.redoDepth,
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
        undoDepth: openMapController.editHistory.undoDepth,
        redoDepth: openMapController.editHistory.redoDepth,
        isBrushStrokeActive: _isBrushStrokeActive,
      ),
    );
    return rawValue;
  }

  /// Selects a raw tile value that does not have to exist in the map yet.
  ///
  /// The catalog popup uses this so a tile picked from local game data becomes
  /// the active brush value without first finding that tile on the canvas.
  bool selectCatalogTile(int rawTileValue) {
    RangeError.checkValueInInterval(rawTileValue, 0, 0xffff, 'rawTileValue');
    if (_activeTerrainView == null) {
      return false;
    }
    _emit(
      TerrainEditingState(
        tool: _state.tool == TerrainEditingTool.select
            ? TerrainEditingTool.brush
            : _state.tool,
        selectedRawTileValue: rawTileValue,
        selectedTile: null,
        undoDepth: openMapController.editHistory.undoDepth,
        redoDepth: openMapController.editHistory.redoDepth,
        isBrushStrokeActive: _isBrushStrokeActive,
      ),
    );
    return true;
  }

  bool beginBrushStroke() {
    if (_isBrushStrokeActive ||
        !canEditTerrain ||
        _state.selectedRawTileValue == null) {
      return false;
    }

    openMapController.editHistory.beginTransaction(this);
    _isBrushStrokeActive = true;
    _pendingBrushCommand = null;
    _emitHistoryState();
    return true;
  }

  bool commitBrushStroke() {
    if (!_isBrushStrokeActive) {
      return false;
    }

    final command = _pendingBrushCommand;
    _pendingBrushCommand = null;
    _isBrushStrokeActive = false;
    openMapController.editHistory.endTransaction(this);
    if (command != null) {
      _pushUndo(command);
    } else {
      _emitHistoryState();
    }
    return command != null;
  }

  bool cancelBrushStroke() {
    if (!_isBrushStrokeActive) {
      return false;
    }

    final command = _pendingBrushCommand;
    if (command != null) {
      _replaceTerrainSection(
        expectedSection: command.afterSection,
        replacement: command.beforeSection,
      );
    }
    _pendingBrushCommand = null;
    _isBrushStrokeActive = false;
    openMapController.editHistory.endTransaction(this);
    _emitHistoryState();
    return command != null;
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
    return changed &&
        _replaceTerrainValues(terrain, values, label: 'Brush stroke');
  }

  bool fillRectangle(TerrainTileRegion region) {
    final rawValue = _state.selectedRawTileValue;
    if (!canEditTerrain || rawValue == null) {
      return false;
    }
    if (_isBrushStrokeActive) {
      throw StateError(
        'A rectangle cannot be filled during an active brush stroke.',
      );
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
    return changed &&
        _replaceTerrainValues(terrain, values, label: 'Rectangle fill');
  }

  bool undo() => openMapController.editHistory.undo();

  bool redo() => openMapController.editHistory.redo();

  bool _replaceTerrainValues(
    ChkTerrainTileMapView terrain,
    List<int> values, {
    required String label,
  }) {
    openMapController.editHistory.ensureCanEdit(this);
    final before = openMapController.state.session!;
    final replacement = terrain.withRawTileValues(values);
    _replaceTerrainSection(
      expectedSection: terrain.rawSection,
      replacement: replacement,
    );
    _recordCommand(
      _TerrainEditCommand(
        before: before,
        after: openMapController.state.session!,
        label: label,
        sectionIndex: terrain.sectionIndex,
        beforeSection: terrain.rawSection,
        afterSection: replacement,
      ),
    );
    return true;
  }

  void _replaceTerrainSection({
    required RawChkSection expectedSection,
    required RawChkSection replacement,
  }) {
    final session = openMapController.state.session;
    if (session == null) {
      throw StateError('A terrain edit requires an open map session.');
    }
    final terrain = _activeTerrainViewFor(session);
    if (terrain == null || !identical(terrain.rawSection, expectedSection)) {
      throw StateError(
        'The terrain edit history no longer matches the active MTXM section.',
      );
    }

    final rawDocument = session.rawDocument.replaceSection(
      terrain.sectionIndex,
      replacement,
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
        resourceEdits: session.resourceEdits,
        metadataViews: session.metadataViews,
        stringViews: session.stringViews,
        terrainViews: terrainViews,
        objectViews: session.objectViews,
        sourceFingerprint: session.sourceFingerprint,
        diagnostics: session.diagnostics,
      ),
    );
  }

  void _recordCommand(_TerrainEditCommand command) {
    if (_isBrushStrokeActive) {
      final pending = _pendingBrushCommand;
      _pendingBrushCommand = pending == null
          ? command
          : pending.mergeWith(command);
      return;
    }
    _pushUndo(command);
  }

  void _pushUndo(_TerrainEditCommand command) {
    openMapController.editHistory.record(
      label: command.label,
      before: command.before,
      after: command.after,
      undo: () => _replaceTerrainSection(
        expectedSection: command.afterSection,
        replacement: command.beforeSection,
      ),
      redo: () => _replaceTerrainSection(
        expectedSection: command.beforeSection,
        replacement: command.afterSection,
      ),
    );
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

  void _emitHistoryState() {
    _emit(
      TerrainEditingState(
        tool: _state.tool,
        selectedRawTileValue: _state.selectedRawTileValue,
        selectedTile: _state.selectedTile,
        undoDepth: openMapController.editHistory.undoDepth,
        redoDepth: openMapController.editHistory.redoDepth,
        isBrushStrokeActive: _isBrushStrokeActive,
      ),
    );
  }

  void _emit(TerrainEditingState state) {
    _state = state;
    _changes.add(state);
  }

  Future<void> dispose() async {
    await _sessionSubscription.cancel();
    await _historySubscription.cancel();
    await _changes.close();
  }
}

final class _TerrainEditCommand {
  const _TerrainEditCommand({
    required this.before,
    required this.after,
    required this.label,
    required this.sectionIndex,
    required this.beforeSection,
    required this.afterSection,
  });

  final OpenedMapSession before, after;
  final String label;
  final int sectionIndex;
  final RawChkSection beforeSection;
  final RawChkSection afterSection;

  _TerrainEditCommand mergeWith(_TerrainEditCommand next) {
    if (sectionIndex != next.sectionIndex ||
        !identical(afterSection, next.beforeSection)) {
      throw StateError(
        'Only contiguous edits to the same MTXM section can be merged.',
      );
    }
    return _TerrainEditCommand(
      before: before,
      after: next.after,
      label: label,
      sectionIndex: sectionIndex,
      beforeSection: beforeSection,
      afterSection: next.afterSection,
    );
  }
}
