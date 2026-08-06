import 'dart:async';

import '../../domain/chk/chk.dart';
import '../documents/open_map_controller.dart';
import '../documents/opened_map_session.dart';
import '../layers/map_layer_controller.dart';

final class ObjectEditingState {
  const ObjectEditingState({this.undoDepth = 0, this.redoDepth = 0});

  final int undoDepth;
  final int redoDepth;

  bool get canUndo => undoDepth > 0;
  bool get canRedo => redoDepth > 0;
}

class ObjectEditingController {
  ObjectEditingController({
    required this.openMapController,
    required this.mapLayerController,
    this.objectViewDecoder = const ChkObjectViewDecoder(),
    this.sectionEditor = const ChkObjectSectionEditor(),
    this.historyLimit = 100,
  }) {
    if (historyLimit <= 0) {
      throw ArgumentError.value(
        historyLimit,
        'historyLimit',
        'The object edit history limit must be greater than zero.',
      );
    }
  }

  final OpenMapController openMapController;
  final MapLayerController mapLayerController;
  final ChkObjectViewDecoder objectViewDecoder;
  final ChkObjectSectionEditor sectionEditor;
  final int historyLimit;
  final StreamController<ObjectEditingState> _changes =
      StreamController<ObjectEditingState>.broadcast(sync: true);
  final List<_ObjectEditCommand> _undoStack = [];
  final List<_ObjectEditCommand> _redoStack = [];

  ObjectEditingState _state = const ObjectEditingState();
  Object? _trackedSourceSnapshot;

  ObjectEditingState get state => _state;
  Stream<ObjectEditingState> get changes => _changes.stream;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  String? get undoLabel => canUndo ? _undoStack.last.label : null;
  String? get redoLabel => canRedo ? _redoStack.last.label : null;

  bool get canEditSelection {
    final session = openMapController.state.session;
    final selections = _editableSelections;
    return session != null &&
        selections.isNotEmpty &&
        !session.requiresRestrictedEditing &&
        !_containsProtectionMarker(session.rawDocument);
  }

  void synchronizeSession(OpenedMapSession? session) {
    final sourceSnapshot = session?.extractedMap;
    if (identical(sourceSnapshot, _trackedSourceSnapshot)) {
      return;
    }
    _trackedSourceSnapshot = sourceSnapshot;
    _undoStack.clear();
    _redoStack.clear();
    _emit();
  }

  bool moveSelection({required int dx, required int dy}) {
    if ((dx == 0 && dy == 0) || !canEditSelection) {
      return false;
    }
    final session = openMapController.state.session!;
    final selections = _editableSelections;
    if (!_fitsMap(session, selections, dx: dx, dy: dy)) {
      return false;
    }

    final grouped = _groupSelections(selections);
    final before = <int, RawChkSection>{};
    final after = <int, RawChkSection>{};
    final delta = ChkObjectCoordinateDelta(dx: dx, dy: dy);
    for (final entry in grouped.entries) {
      final layer = entry.key.$1;
      final sectionIndex = entry.key.$2;
      final indices = {
        for (final selection in entry.value) selection.object.recordIndex,
      };
      final replacement = switch (layer) {
        MapLayerType.units => sectionEditor.moveUnits(
          _unitSection(session, sectionIndex),
          {for (final index in indices) index: delta},
        ),
        MapLayerType.doodads => sectionEditor.moveDoodads(
          _doodadSection(session, sectionIndex),
          {for (final index in indices) index: delta},
        ),
        MapLayerType.sprites => sectionEditor.moveSprites(
          _spriteSection(session, sectionIndex),
          {for (final index in indices) index: delta},
        ),
        MapLayerType.locations => sectionEditor.moveLocations(
          _locationSection(session, sectionIndex),
          {for (final index in indices) index: delta},
        ),
        MapLayerType.terrain => throw StateError('Terrain is not an object.'),
      };
      before[sectionIndex] = session.rawDocument.sections[sectionIndex];
      after[sectionIndex] = replacement;
    }

    _applyAndRecord(
      _ObjectEditCommand(
        label: selections.length == 1
            ? 'Move object'
            : 'Move ${selections.length} objects',
        beforeSections: before,
        afterSections: after,
      ),
      clearSelection: false,
    );
    return true;
  }

  bool deleteSelection() {
    if (!canEditSelection) {
      return false;
    }
    final session = openMapController.state.session!;
    final selections = _editableSelections;
    final grouped = _groupSelections(selections);
    final before = <int, RawChkSection>{};
    final after = <int, RawChkSection>{};
    for (final entry in grouped.entries) {
      final layer = entry.key.$1;
      final sectionIndex = entry.key.$2;
      final indices = {
        for (final selection in entry.value) selection.object.recordIndex,
      };
      final replacement = switch (layer) {
        MapLayerType.units => sectionEditor.deleteUnits(
          _unitSection(session, sectionIndex),
          indices,
        ),
        MapLayerType.doodads => sectionEditor.deleteDoodads(
          _doodadSection(session, sectionIndex),
          indices,
        ),
        MapLayerType.sprites => sectionEditor.deleteSprites(
          _spriteSection(session, sectionIndex),
          indices,
        ),
        MapLayerType.locations => sectionEditor.deleteLocations(
          _locationSection(session, sectionIndex),
          indices,
        ),
        MapLayerType.terrain => throw StateError('Terrain is not an object.'),
      };
      before[sectionIndex] = session.rawDocument.sections[sectionIndex];
      after[sectionIndex] = replacement;
    }

    _applyAndRecord(
      _ObjectEditCommand(
        label: selections.length == 1
            ? 'Delete object'
            : 'Delete ${selections.length} objects',
        beforeSections: before,
        afterSections: after,
      ),
      clearSelection: true,
    );
    return true;
  }

  bool undo() {
    if (!canUndo) {
      return false;
    }
    final command = _undoStack.removeLast();
    _applySections(
      expected: command.afterSections,
      replacements: command.beforeSections,
      clearSelection: true,
    );
    _redoStack.add(command);
    _emit();
    return true;
  }

  bool redo() {
    if (!canRedo) {
      return false;
    }
    final command = _redoStack.removeLast();
    _applySections(
      expected: command.beforeSections,
      replacements: command.afterSections,
      clearSelection: true,
    );
    _undoStack.add(command);
    _emit();
    return true;
  }

  List<MapLayerSelection> get _editableSelections => mapLayerController
      .state
      .selections
      .where(
        (selection) =>
            selection.object.layer != MapLayerType.terrain &&
            mapLayerController.state
                .statusOf(selection.object.layer)
                .isSelectable,
      )
      .toList(growable: false);

  Map<(MapLayerType, int), List<MapLayerSelection>> _groupSelections(
    Iterable<MapLayerSelection> selections,
  ) {
    final grouped = <(MapLayerType, int), List<MapLayerSelection>>{};
    for (final selection in selections) {
      grouped
          .putIfAbsent((
            selection.object.layer,
            selection.object.sectionIndex,
          ), () => [])
          .add(selection);
    }
    return grouped;
  }

  bool _fitsMap(
    OpenedMapSession session,
    Iterable<MapLayerSelection> selections, {
    required int dx,
    required int dy,
  }) {
    if (session.metadataViews.dimensions.length != 1) {
      return false;
    }
    final dimensions = session.metadataViews.dimensions.single;
    final maximumX = dimensions.width * 32;
    final maximumY = dimensions.height * 32;
    for (final selection in selections) {
      final object = selection.object;
      switch (object.layer) {
        case MapLayerType.units:
        case MapLayerType.doodads:
        case MapLayerType.sprites:
          final x = selection.pixelX + dx;
          final y = selection.pixelY + dy;
          if (x < 0 || y < 0 || x >= maximumX || y >= maximumY) {
            return false;
          }
        case MapLayerType.locations:
          final location = _locationSection(
            session,
            object.sectionIndex,
          ).locations[object.recordIndex];
          if ([
                location.left + dx,
                location.right + dx,
              ].any((value) => value < 0 || value > maximumX) ||
              [
                location.top + dy,
                location.bottom + dy,
              ].any((value) => value < 0 || value > maximumY)) {
            return false;
          }
        case MapLayerType.terrain:
          return false;
      }
    }
    return true;
  }

  void _applyAndRecord(
    _ObjectEditCommand command, {
    required bool clearSelection,
  }) {
    _applySections(
      expected: command.beforeSections,
      replacements: command.afterSections,
      clearSelection: clearSelection,
    );
    _undoStack.add(command);
    if (_undoStack.length > historyLimit) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
    _emit();
  }

  void _applySections({
    required Map<int, RawChkSection> expected,
    required Map<int, RawChkSection> replacements,
    required bool clearSelection,
  }) {
    final session = openMapController.state.session;
    if (session == null) {
      throw StateError('An object edit requires an open map session.');
    }
    var document = session.rawDocument;
    for (final entry in expected.entries) {
      if (!identical(document.sections[entry.key], entry.value)) {
        throw StateError(
          'The object edit history no longer matches section ${entry.key}.',
        );
      }
      document = document.replaceSection(entry.key, replacements[entry.key]!);
    }
    final objectViews = objectViewDecoder.decode(document);
    if (objectViews.hasBlockingDiagnostics) {
      throw StateError('The edited object sections failed validation.');
    }
    if (clearSelection) {
      mapLayerController.clearSelection();
    }
    final editedSession = OpenedMapSession(
      extractedMap: session.extractedMap,
      rawDocument: document,
      metadataViews: session.metadataViews,
      terrainViews: session.terrainViews,
      objectViews: objectViews,
      sourceFingerprint: session.sourceFingerprint,
      diagnostics: session.diagnostics,
    );
    openMapController.adoptEditedSession(editedSession);
    mapLayerController.synchronizeSession(editedSession);
  }

  ChkUnitSectionView _unitSection(OpenedMapSession session, int index) =>
      session.objectViews.unitSections.singleWhere(
        (section) => section.sectionIndex == index,
      );

  ChkDoodadSectionView _doodadSection(OpenedMapSession session, int index) =>
      session.objectViews.doodadSections.singleWhere(
        (section) => section.sectionIndex == index,
      );

  ChkSpriteSectionView _spriteSection(OpenedMapSession session, int index) =>
      session.objectViews.spriteSections.singleWhere(
        (section) => section.sectionIndex == index,
      );

  ChkLocationSectionView _locationSection(
    OpenedMapSession session,
    int index,
  ) => session.objectViews.locationSections.singleWhere(
    (section) => section.sectionIndex == index,
  );

  bool _containsProtectionMarker(RawChkDocument document) =>
      document.sections.any((section) => section.isEuddraftProtectionMarker);

  void _emit() {
    _state = ObjectEditingState(
      undoDepth: _undoStack.length,
      redoDepth: _redoStack.length,
    );
    _changes.add(_state);
  }

  Future<void> dispose() => _changes.close();
}

final class _ObjectEditCommand {
  _ObjectEditCommand({
    required this.label,
    required Map<int, RawChkSection> beforeSections,
    required Map<int, RawChkSection> afterSections,
  }) : beforeSections = Map.unmodifiable(beforeSections),
       afterSections = Map.unmodifiable(afterSections);

  final String label;
  final Map<int, RawChkSection> beforeSections;
  final Map<int, RawChkSection> afterSections;
}
