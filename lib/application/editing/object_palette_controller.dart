import 'dart:async';

import '../documents/opened_map_session.dart';
import '../layers/map_layer_controller.dart';
import 'object_editing_controller.dart';

final class ObjectPaletteEntry {
  const ObjectPaletteEntry({
    required this.layer,
    required this.typeId,
    required this.count,
    required this.template,
  });

  final MapLayerType layer;
  final int typeId;
  final int count;
  final MapLayerObjectRef template;

  String get id => '${layer.name}:$typeId';

  String get kindLabel => switch (layer) {
    MapLayerType.units => 'Unit',
    MapLayerType.doodads => 'Doodad',
    MapLayerType.sprites => 'Sprite',
    MapLayerType.terrain => 'Terrain',
    MapLayerType.locations => 'Location',
  };

  String get label => '$kindLabel type $typeId';

  bool matches(String normalizedQuery) {
    if (normalizedQuery.isEmpty) {
      return true;
    }
    final searchable =
        '${layer.name} $kindLabel ${kindLabel}s type $typeId #$typeId'
            .toLowerCase();
    return normalizedQuery.split(RegExp(r'\s+')).every(searchable.contains);
  }
}

final class ObjectPaletteState {
  ObjectPaletteState({
    Iterable<ObjectPaletteEntry> entries = const [],
    this.query = '',
    this.selectedEntryId,
  }) : entries = List.unmodifiable(entries);

  final List<ObjectPaletteEntry> entries;
  final String query;
  final String? selectedEntryId;

  List<ObjectPaletteEntry> get visibleEntries => List.unmodifiable(
    entries.where((entry) => entry.matches(query.trim().toLowerCase())),
  );

  ObjectPaletteEntry? get selectedEntry =>
      entries.where((entry) => entry.id == selectedEntryId).firstOrNull;

  bool get isPlacementActive => selectedEntry != null;
}

class ObjectPaletteController {
  ObjectPaletteController({
    required this.objectEditingController,
    required this.mapLayerController,
  });

  final ObjectEditingController objectEditingController;
  final MapLayerController mapLayerController;
  final StreamController<ObjectPaletteState> _changes =
      StreamController<ObjectPaletteState>.broadcast(sync: true);
  ObjectPaletteState _state = ObjectPaletteState();
  OpenedMapSession? _trackedSession;

  ObjectPaletteState get state => _state;
  Stream<ObjectPaletteState> get changes => _changes.stream;

  void synchronizeSession(OpenedMapSession? session) {
    if (identical(session, _trackedSession)) {
      return;
    }
    _trackedSession = session;
    final entries = session == null
        ? const <ObjectPaletteEntry>[]
        : _entriesFor(session);
    final selectedId =
        entries.any((entry) => entry.id == _state.selectedEntryId)
        ? _state.selectedEntryId
        : null;
    _emit(
      ObjectPaletteState(
        entries: entries,
        query: _state.query,
        selectedEntryId: selectedId,
      ),
    );
  }

  void setQuery(String query) {
    if (_state.query == query) {
      return;
    }
    _emit(
      ObjectPaletteState(
        entries: _state.entries,
        query: query,
        selectedEntryId: _state.selectedEntryId,
      ),
    );
  }

  bool canSelectEntry(ObjectPaletteEntry entry) =>
      objectEditingController.canPlaceTemplate(entry.template);

  bool selectEntry(ObjectPaletteEntry entry) {
    final current = _state.entries
        .where((candidate) => candidate.id == entry.id)
        .firstOrNull;
    if (current == null ||
        !objectEditingController.canPlaceTemplate(current.template)) {
      return false;
    }
    mapLayerController.setActiveLayer(current.layer);
    _emit(
      ObjectPaletteState(
        entries: _state.entries,
        query: _state.query,
        selectedEntryId: current.id,
      ),
    );
    return true;
  }

  bool placeSelected({required int pixelX, required int pixelY}) {
    final entry = _state.selectedEntry;
    if (entry == null ||
        !objectEditingController.duplicateTemplate(
          template: entry.template,
          pixelX: pixelX,
          pixelY: pixelY,
        )) {
      return false;
    }
    synchronizeSession(objectEditingController.openMapController.state.session);
    return true;
  }

  void cancelPlacement() {
    if (_state.selectedEntryId == null) {
      return;
    }
    _emit(ObjectPaletteState(entries: _state.entries, query: _state.query));
  }

  List<ObjectPaletteEntry> _entriesFor(OpenedMapSession session) {
    final builders = <(MapLayerType, int), _PaletteEntryBuilder>{};
    void add(MapLayerType layer, int typeId, MapLayerObjectRef object) {
      final key = (layer, typeId);
      final existing = builders[key];
      builders[key] = existing == null
          ? _PaletteEntryBuilder(template: object, count: 1)
          : _PaletteEntryBuilder(
              template: existing.template,
              count: existing.count + 1,
            );
    }

    for (final section in session.objectViews.unitSections) {
      for (final unit in section.units) {
        add(
          MapLayerType.units,
          unit.unitType,
          MapLayerObjectRef(
            layer: MapLayerType.units,
            sectionIndex: section.sectionIndex,
            recordIndex: unit.recordIndex,
          ),
        );
      }
    }
    for (final section in session.objectViews.doodadSections) {
      for (final doodad in section.doodads) {
        add(
          MapLayerType.doodads,
          doodad.doodadType,
          MapLayerObjectRef(
            layer: MapLayerType.doodads,
            sectionIndex: section.sectionIndex,
            recordIndex: doodad.recordIndex,
          ),
        );
      }
    }
    for (final section in session.objectViews.spriteSections) {
      for (final sprite in section.sprites) {
        add(
          MapLayerType.sprites,
          sprite.spriteType,
          MapLayerObjectRef(
            layer: MapLayerType.sprites,
            sectionIndex: section.sectionIndex,
            recordIndex: sprite.recordIndex,
          ),
        );
      }
    }

    final layerOrder = {
      MapLayerType.units: 0,
      MapLayerType.doodads: 1,
      MapLayerType.sprites: 2,
    };
    final entries =
        [
          for (final entry in builders.entries)
            ObjectPaletteEntry(
              layer: entry.key.$1,
              typeId: entry.key.$2,
              count: entry.value.count,
              template: entry.value.template,
            ),
        ]..sort((first, second) {
          final layerComparison = layerOrder[first.layer]!.compareTo(
            layerOrder[second.layer]!,
          );
          return layerComparison != 0
              ? layerComparison
              : first.typeId.compareTo(second.typeId);
        });
    return entries;
  }

  void _emit(ObjectPaletteState state) {
    _state = state;
    _changes.add(state);
  }

  Future<void> dispose() => _changes.close();
}

final class _PaletteEntryBuilder {
  const _PaletteEntryBuilder({required this.template, required this.count});

  final MapLayerObjectRef template;
  final int count;
}
