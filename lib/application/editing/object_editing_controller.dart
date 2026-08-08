import 'dart:async';

import '../../domain/chk/chk.dart';
import '../documents/open_map_controller.dart';
import '../documents/opened_map_session.dart';
import '../layers/map_layer_controller.dart';
import 'object_properties.dart';

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
        _isEditableSession(session);
  }

  ObjectProperties? get selectedProperties {
    final session = openMapController.state.session;
    final selections = mapLayerController.state.selections;
    if (session == null || selections.length != 1) {
      return null;
    }
    final object = selections.single.object;
    return switch (object.layer) {
      MapLayerType.units => _unitProperties(session, object),
      MapLayerType.doodads => _doodadProperties(session, object),
      MapLayerType.sprites => _spriteProperties(session, object),
      MapLayerType.locations => _locationProperties(session, object),
      MapLayerType.terrain => null,
    };
  }

  bool get canEditProperties {
    final properties = selectedProperties;
    return properties != null &&
        properties is! LocationObjectProperties &&
        canEditSelection;
  }

  bool canPlaceTemplate(MapLayerObjectRef template) {
    final session = openMapController.state.session;
    return session != null &&
        template.layer != MapLayerType.terrain &&
        template.layer != MapLayerType.locations &&
        mapLayerController.state.statusOf(template.layer).isSelectable &&
        _isEditableSession(session) &&
        _templateExists(session, template);
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

  bool duplicateTemplate({
    required MapLayerObjectRef template,
    required int pixelX,
    required int pixelY,
  }) {
    final session = openMapController.state.session;
    if (session == null ||
        !canPlaceTemplate(template) ||
        !_pointFitsMap(session, pixelX, pixelY)) {
      return false;
    }
    final sectionIndex = template.sectionIndex;
    final newRecordIndex = switch (template.layer) {
      MapLayerType.units => _unitSection(session, sectionIndex).units.length,
      MapLayerType.doodads => _doodadSection(
        session,
        sectionIndex,
      ).doodads.length,
      MapLayerType.sprites => _spriteSection(
        session,
        sectionIndex,
      ).sprites.length,
      MapLayerType.terrain || MapLayerType.locations => throw StateError(
        'This layer cannot use point-object templates.',
      ),
    };
    final replacement = switch (template.layer) {
      MapLayerType.units => sectionEditor.duplicateUnit(
        _unitSection(session, sectionIndex),
        templateRecordIndex: template.recordIndex,
        x: pixelX,
        y: pixelY,
      ),
      MapLayerType.doodads => sectionEditor.duplicateDoodad(
        _doodadSection(session, sectionIndex),
        templateRecordIndex: template.recordIndex,
        x: pixelX,
        y: pixelY,
      ),
      MapLayerType.sprites => sectionEditor.duplicateSprite(
        _spriteSection(session, sectionIndex),
        templateRecordIndex: template.recordIndex,
        x: pixelX,
        y: pixelY,
      ),
      MapLayerType.terrain || MapLayerType.locations => throw StateError(
        'This layer cannot use point-object templates.',
      ),
    };
    _applyAndRecord(
      _ObjectEditCommand(
        label:
            'Place ${template.layer.label.substring(0, template.layer.label.length - 1)}',
        beforeSections: {
          sectionIndex: session.rawDocument.sections[sectionIndex],
        },
        afterSections: {sectionIndex: replacement},
      ),
      clearSelection: true,
    );
    final editedSession = openMapController.state.session!;
    final placedObject = MapLayerObjectRef(
      layer: template.layer,
      sectionIndex: sectionIndex,
      recordIndex: newRecordIndex,
    );
    mapLayerController
      ..setActiveLayer(template.layer)
      ..selectObject(session: editedSession, object: placedObject);
    final selected = mapLayerController.state.selection;
    if (selected?.object != placedObject) {
      throw StateError('The newly placed object could not be selected.');
    }
    return true;
  }

  ObjectPropertyEditResult updateProperties(ObjectPropertyUpdate update) {
    final session = openMapController.state.session;
    final current = selectedProperties;
    if (session == null ||
        current == null ||
        current.object != update.object ||
        !canEditProperties) {
      return ObjectPropertyEditResult.unavailable();
    }
    final errors = _validatePropertyUpdate(session, update);
    if (errors.isNotEmpty) {
      return ObjectPropertyEditResult.invalid(errors);
    }
    if (_propertyUpdateHasNoChanges(current, update)) {
      return ObjectPropertyEditResult.noChanges();
    }
    final sectionIndex = update.object.sectionIndex;
    final recordIndex = update.object.recordIndex;
    final replacement = switch (update) {
      UnitObjectPropertyUpdate() => sectionEditor.updateUnitProperties(
        _unitSection(session, sectionIndex),
        recordIndex: recordIndex,
        unitType: update.typeId,
        x: update.x,
        y: update.y,
        owner: update.owner,
        hitpointPercent: update.hitpointPercent,
        shieldPercent: update.shieldPercent,
        energyPercent: update.energyPercent,
        resourceAmount: update.resourceAmount,
        hangarAmount: update.hangarAmount,
      ),
      DoodadObjectPropertyUpdate() => sectionEditor.updateDoodadProperties(
        _doodadSection(session, sectionIndex),
        recordIndex: recordIndex,
        doodadType: update.typeId,
        x: update.x,
        y: update.y,
        owner: update.owner,
        enabledValue: update.enabledValue,
      ),
      SpriteObjectPropertyUpdate() => sectionEditor.updateSpriteProperties(
        _spriteSection(session, sectionIndex),
        recordIndex: recordIndex,
        spriteType: update.typeId,
        x: update.x,
        y: update.y,
        owner: update.owner,
      ),
    };
    final kindLabel = switch (update.object.layer) {
      MapLayerType.units => 'Unit',
      MapLayerType.doodads => 'Doodad',
      MapLayerType.sprites => 'Sprite',
      MapLayerType.terrain || MapLayerType.locations => throw StateError(
        'This object does not expose editable point properties.',
      ),
    };
    _applyAndRecord(
      _ObjectEditCommand(
        label: 'Edit $kindLabel properties',
        beforeSections: {
          sectionIndex: session.rawDocument.sections[sectionIndex],
        },
        afterSections: {sectionIndex: replacement},
      ),
      clearSelection: false,
    );
    return ObjectPropertyEditResult.applied();
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

  bool _pointFitsMap(OpenedMapSession session, int x, int y) {
    if (session.metadataViews.dimensions.length != 1) {
      return false;
    }
    final dimensions = session.metadataViews.dimensions.single;
    return x >= 0 &&
        y >= 0 &&
        x < dimensions.width * 32 &&
        y < dimensions.height * 32;
  }

  UnitObjectProperties _unitProperties(
    OpenedMapSession session,
    MapLayerObjectRef object,
  ) {
    final unit = _unitSection(
      session,
      object.sectionIndex,
    ).units[object.recordIndex];
    return UnitObjectProperties(
      object: object,
      typeId: unit.unitType,
      x: unit.x,
      y: unit.y,
      owner: unit.owner,
      hitpointPercent: unit.hitpointPercent,
      shieldPercent: unit.shieldPercent,
      energyPercent: unit.energyPercent,
      resourceAmount: unit.resourceAmount,
      hangarAmount: unit.hangarAmount,
      classId: unit.classId,
      relationFlags: unit.relationFlags,
      validStateFlags: unit.validStateFlags,
      validFieldFlags: unit.validFieldFlags,
      stateFlags: unit.stateFlags,
      unused: unit.unused,
      relationClassId: unit.relationClassId,
    );
  }

  DoodadObjectProperties _doodadProperties(
    OpenedMapSession session,
    MapLayerObjectRef object,
  ) {
    final doodad = _doodadSection(
      session,
      object.sectionIndex,
    ).doodads[object.recordIndex];
    return DoodadObjectProperties(
      object: object,
      typeId: doodad.doodadType,
      x: doodad.x,
      y: doodad.y,
      owner: doodad.owner,
      enabledValue: doodad.enabledValue,
    );
  }

  SpriteObjectProperties _spriteProperties(
    OpenedMapSession session,
    MapLayerObjectRef object,
  ) {
    final sprite = _spriteSection(
      session,
      object.sectionIndex,
    ).sprites[object.recordIndex];
    return SpriteObjectProperties(
      object: object,
      typeId: sprite.spriteType,
      x: sprite.x,
      y: sprite.y,
      owner: sprite.owner,
      unused: sprite.unused,
      flags: sprite.flags,
    );
  }

  LocationObjectProperties _locationProperties(
    OpenedMapSession session,
    MapLayerObjectRef object,
  ) {
    final location = _locationSection(
      session,
      object.sectionIndex,
    ).locations[object.recordIndex];
    return LocationObjectProperties(
      object: object,
      locationId: location.locationId,
      left: location.left,
      top: location.top,
      right: location.right,
      bottom: location.bottom,
      stringId: location.stringId,
      elevationFlags: location.elevationFlags,
    );
  }

  Map<String, String> _validatePropertyUpdate(
    OpenedMapSession session,
    ObjectPropertyUpdate update,
  ) {
    final errors = <String, String>{};
    int? x;
    int? y;
    int? typeId;
    int? owner;
    switch (update) {
      case UnitObjectPropertyUpdate():
        x = update.x;
        y = update.y;
        typeId = update.typeId;
        owner = update.owner;
        _validateRange(
          errors,
          ObjectPropertyFields.hitpointPercent,
          update.hitpointPercent,
          0,
          100,
          'Use a percentage from 0 to 100.',
        );
        _validateRange(
          errors,
          ObjectPropertyFields.shieldPercent,
          update.shieldPercent,
          0,
          100,
          'Use a percentage from 0 to 100.',
        );
        _validateRange(
          errors,
          ObjectPropertyFields.energyPercent,
          update.energyPercent,
          0,
          100,
          'Use a percentage from 0 to 100.',
        );
        _validateRange(
          errors,
          ObjectPropertyFields.resourceAmount,
          update.resourceAmount,
          0,
          0xffffffff,
          'Use an unsigned 32-bit value.',
        );
        _validateRange(
          errors,
          ObjectPropertyFields.hangarAmount,
          update.hangarAmount,
          0,
          0xffff,
          'Use a value from 0 to 65535.',
        );
      case DoodadObjectPropertyUpdate():
        x = update.x;
        y = update.y;
        typeId = update.typeId;
        owner = update.owner;
        _validateRange(
          errors,
          ObjectPropertyFields.enabledValue,
          update.enabledValue,
          0,
          1,
          'Use 0 for enabled or 1 for disabled.',
        );
      case SpriteObjectPropertyUpdate():
        x = update.x;
        y = update.y;
        typeId = update.typeId;
        owner = update.owner;
    }
    _validateRange(
      errors,
      ObjectPropertyFields.typeId,
      typeId,
      0,
      0xffff,
      'Use a type ID from 0 to 65535.',
    );
    _validateRange(
      errors,
      ObjectPropertyFields.owner,
      owner,
      0,
      0xff,
      'Use a raw owner value from 0 to 255.',
    );
    if (session.metadataViews.dimensions.length != 1) {
      errors[ObjectPropertyFields.x] = 'Map dimensions are unavailable.';
      errors[ObjectPropertyFields.y] = 'Map dimensions are unavailable.';
      return errors;
    }
    final dimensions = session.metadataViews.dimensions.single;
    _validateRange(
      errors,
      ObjectPropertyFields.x,
      x,
      0,
      dimensions.width * 32 - 1,
      'X must stay inside the map.',
    );
    _validateRange(
      errors,
      ObjectPropertyFields.y,
      y,
      0,
      dimensions.height * 32 - 1,
      'Y must stay inside the map.',
    );
    return errors;
  }

  void _validateRange(
    Map<String, String> errors,
    String field,
    int? value,
    int minimum,
    int maximum,
    String message,
  ) {
    if (value == null || value < minimum || value > maximum) {
      errors[field] = message;
    }
  }

  bool _propertyUpdateHasNoChanges(
    ObjectProperties current,
    ObjectPropertyUpdate update,
  ) => switch ((current, update)) {
    (UnitObjectProperties current, UnitObjectPropertyUpdate update) =>
      current.typeId == update.typeId &&
          current.x == update.x &&
          current.y == update.y &&
          current.owner == update.owner &&
          current.hitpointPercent == update.hitpointPercent &&
          current.shieldPercent == update.shieldPercent &&
          current.energyPercent == update.energyPercent &&
          current.resourceAmount == update.resourceAmount &&
          current.hangarAmount == update.hangarAmount,
    (DoodadObjectProperties current, DoodadObjectPropertyUpdate update) =>
      current.typeId == update.typeId &&
          current.x == update.x &&
          current.y == update.y &&
          current.owner == update.owner &&
          current.enabledValue == update.enabledValue,
    (SpriteObjectProperties current, SpriteObjectPropertyUpdate update) =>
      current.typeId == update.typeId &&
          current.x == update.x &&
          current.y == update.y &&
          current.owner == update.owner,
    _ => false,
  };

  bool _templateExists(OpenedMapSession session, MapLayerObjectRef template) {
    return switch (template.layer) {
      MapLayerType.units => session.objectViews.unitSections.any(
        (section) =>
            section.sectionIndex == template.sectionIndex &&
            template.recordIndex >= 0 &&
            template.recordIndex < section.units.length,
      ),
      MapLayerType.doodads => session.objectViews.doodadSections.any(
        (section) =>
            section.sectionIndex == template.sectionIndex &&
            template.recordIndex >= 0 &&
            template.recordIndex < section.doodads.length,
      ),
      MapLayerType.sprites => session.objectViews.spriteSections.any(
        (section) =>
            section.sectionIndex == template.sectionIndex &&
            template.recordIndex >= 0 &&
            template.recordIndex < section.sprites.length,
      ),
      MapLayerType.terrain || MapLayerType.locations => false,
    };
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

  bool _isEditableSession(OpenedMapSession session) =>
      !session.requiresRestrictedEditing &&
      !_containsProtectionMarker(session.rawDocument);

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
