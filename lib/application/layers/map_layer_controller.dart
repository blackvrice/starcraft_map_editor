import 'dart:async';

import '../documents/opened_map_session.dart';
import '../ports/starcraft_object_atlas_gateway.dart';

enum MapLayerType { terrain, locations, doodads, sprites, units }

extension MapLayerTypeLabel on MapLayerType {
  String get label => switch (this) {
    MapLayerType.terrain => 'Terrain',
    MapLayerType.locations => 'Locations',
    MapLayerType.doodads => 'Doodads',
    MapLayerType.sprites => 'Sprites',
    MapLayerType.units => 'Units',
  };
}

final class MapLayerStatus {
  const MapLayerStatus({this.isVisible = true, this.isLocked = false});

  final bool isVisible;
  final bool isLocked;

  bool get isSelectable => isVisible && !isLocked;

  MapLayerStatus copyWith({bool? isVisible, bool? isLocked}) {
    return MapLayerStatus(
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

final class MapLayerObjectRef {
  const MapLayerObjectRef({
    required this.layer,
    required this.sectionIndex,
    required this.recordIndex,
  });

  final MapLayerType layer;
  final int sectionIndex;
  final int recordIndex;

  String get label => '${layer.label} ${recordIndex + 1}';

  @override
  bool operator ==(Object other) =>
      other is MapLayerObjectRef &&
      other.layer == layer &&
      other.sectionIndex == sectionIndex &&
      other.recordIndex == recordIndex;

  @override
  int get hashCode => Object.hash(layer, sectionIndex, recordIndex);
}

final class MapLayerSelection {
  const MapLayerSelection({
    required this.object,
    required this.pixelX,
    required this.pixelY,
  });

  final MapLayerObjectRef object;
  final int pixelX;
  final int pixelY;

  @override
  bool operator ==(Object other) =>
      other is MapLayerSelection &&
      other.object == object &&
      other.pixelX == pixelX &&
      other.pixelY == pixelY;

  @override
  int get hashCode => Object.hash(object, pixelX, pixelY);
}

final class MapLayerPointObject {
  const MapLayerPointObject({
    required this.object,
    required this.pixelX,
    required this.pixelY,
    this.graphicKey,
  });

  final MapLayerObjectRef object;
  final int pixelX;
  final int pixelY;
  final StarCraftObjectGraphicKey? graphicKey;
}

final class MapLayerRegionObject {
  const MapLayerRegionObject({
    required this.object,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final MapLayerObjectRef object;
  final int left;
  final int top;
  final int right;
  final int bottom;

  int get area => (right - left).abs() * (bottom - top).abs();

  bool contains(int x, int y) {
    final minimumX = left < right ? left : right;
    final maximumX = left > right ? left : right;
    final minimumY = top < bottom ? top : bottom;
    final maximumY = top > bottom ? top : bottom;
    return x >= minimumX && x <= maximumX && y >= minimumY && y <= maximumY;
  }
}

final class MapLayerPixelRegion {
  const MapLayerPixelRegion._({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  factory MapLayerPixelRegion.fromCorners({
    required int firstX,
    required int firstY,
    required int secondX,
    required int secondY,
  }) => MapLayerPixelRegion._(
    left: firstX < secondX ? firstX : secondX,
    top: firstY < secondY ? firstY : secondY,
    right: firstX > secondX ? firstX : secondX,
    bottom: firstY > secondY ? firstY : secondY,
  );

  final int left;
  final int top;
  final int right;
  final int bottom;

  bool contains(int x, int y) =>
      x >= left && x <= right && y >= top && y <= bottom;

  bool intersects(MapLayerRegionObject region) {
    final regionLeft = region.left < region.right ? region.left : region.right;
    final regionRight = region.left > region.right ? region.left : region.right;
    final regionTop = region.top < region.bottom ? region.top : region.bottom;
    final regionBottom = region.top > region.bottom
        ? region.top
        : region.bottom;
    return left <= regionRight &&
        right >= regionLeft &&
        top <= regionBottom &&
        bottom >= regionTop;
  }
}

final class MapLayerScene {
  MapLayerScene({
    required Iterable<MapLayerPointObject> points,
    required Iterable<MapLayerRegionObject> regions,
    required Map<MapLayerType, int> objectCounts,
    MapLayerSelection? selection,
    Iterable<MapLayerSelection>? selections,
  }) : points = List.unmodifiable(points),
       regions = List.unmodifiable(regions),
       objectCounts = Map.unmodifiable(objectCounts),
       selections = List.unmodifiable(
         selections ?? (selection == null ? const [] : [selection]),
       );

  final List<MapLayerPointObject> points;
  final List<MapLayerRegionObject> regions;
  final Map<MapLayerType, int> objectCounts;
  final List<MapLayerSelection> selections;

  MapLayerSelection? get selection => selections.lastOrNull;

  Set<MapLayerObjectRef> get selectedObjects =>
      selections.map((selection) => selection.object).toSet();
}

final class MapLayerState {
  MapLayerState({
    this.activeLayer = MapLayerType.terrain,
    Map<MapLayerType, MapLayerStatus>? layers,
    MapLayerSelection? selection,
    Iterable<MapLayerSelection>? selections,
  }) : layers = Map.unmodifiable(layers ?? _defaultLayerStatuses),
       selections = List.unmodifiable(
         selections ?? (selection == null ? const [] : [selection]),
       );

  final MapLayerType activeLayer;
  final Map<MapLayerType, MapLayerStatus> layers;
  final List<MapLayerSelection> selections;

  MapLayerSelection? get selection => selections.lastOrNull;

  bool get hasObjectSelection => selections.any(
    (selection) => selection.object.layer != MapLayerType.terrain,
  );

  MapLayerStatus statusOf(MapLayerType layer) => layers[layer]!;

  List<MapLayerType> get selectionPriority {
    final selectable = <MapLayerType>[];
    if (statusOf(activeLayer).isSelectable) {
      selectable.add(activeLayer);
    }
    for (final layer in MapLayerController.defaultSelectionPriority) {
      if (layer != activeLayer && statusOf(layer).isSelectable) {
        selectable.add(layer);
      }
    }
    return List.unmodifiable(selectable);
  }
}

const _defaultLayerStatuses = <MapLayerType, MapLayerStatus>{
  MapLayerType.terrain: MapLayerStatus(),
  MapLayerType.locations: MapLayerStatus(),
  MapLayerType.doodads: MapLayerStatus(),
  MapLayerType.sprites: MapLayerStatus(),
  MapLayerType.units: MapLayerStatus(),
};

class MapLayerController {
  MapLayerController();

  static const paintOrder = <MapLayerType>[
    MapLayerType.terrain,
    MapLayerType.locations,
    MapLayerType.doodads,
    MapLayerType.sprites,
    MapLayerType.units,
  ];

  static const defaultSelectionPriority = <MapLayerType>[
    MapLayerType.units,
    MapLayerType.sprites,
    MapLayerType.doodads,
    MapLayerType.locations,
    MapLayerType.terrain,
  ];

  static const _pointHitRadius = <MapLayerType, int>{
    MapLayerType.units: 16,
    MapLayerType.sprites: 12,
    MapLayerType.doodads: 12,
  };

  final StreamController<MapLayerState> _changes =
      StreamController<MapLayerState>.broadcast(sync: true);
  MapLayerState _state = MapLayerState();
  Object? _trackedSourceSnapshot;
  OpenedMapSession? _trackedSession;
  OpenedMapSession? _cachedSceneSession;
  MapLayerState? _cachedSceneState;
  MapLayerScene? _cachedScene;

  MapLayerState get state => _state;

  Stream<MapLayerState> get changes => _changes.stream;

  void synchronizeSession(OpenedMapSession? session) {
    final sourceSnapshot = session?.extractedMap;
    if (identical(session, _trackedSession)) {
      return;
    }
    final sameSource = identical(sourceSnapshot, _trackedSourceSnapshot);
    _trackedSourceSnapshot = sourceSnapshot;
    _trackedSession = session;
    _emit(
      MapLayerState(
        activeLayer: _state.activeLayer,
        layers: _state.layers,
        selections: sameSource && session != null
            ? _resolveSelections(session, _state.selections)
            : const [],
      ),
    );
  }

  void setActiveLayer(MapLayerType layer) {
    if (_state.activeLayer == layer) {
      return;
    }
    _emit(
      MapLayerState(
        activeLayer: layer,
        layers: _state.layers,
        selections: _state.selections,
      ),
    );
  }

  void setVisible(MapLayerType layer, bool isVisible) {
    final current = _state.statusOf(layer);
    if (current.isVisible == isVisible) {
      return;
    }
    final updated = Map<MapLayerType, MapLayerStatus>.of(_state.layers);
    updated[layer] = current.copyWith(isVisible: isVisible);
    final selections = !isVisible
        ? _state.selections
              .where((selection) => selection.object.layer != layer)
              .toList(growable: false)
        : _state.selections;
    _emit(
      MapLayerState(
        activeLayer: _state.activeLayer,
        layers: updated,
        selections: selections,
      ),
    );
  }

  void setLocked(MapLayerType layer, bool isLocked) {
    final current = _state.statusOf(layer);
    if (current.isLocked == isLocked) {
      return;
    }
    final updated = Map<MapLayerType, MapLayerStatus>.of(_state.layers);
    updated[layer] = current.copyWith(isLocked: isLocked);
    final selections = isLocked
        ? _state.selections
              .where((selection) => selection.object.layer != layer)
              .toList(growable: false)
        : _state.selections;
    _emit(
      MapLayerState(
        activeLayer: _state.activeLayer,
        layers: updated,
        selections: selections,
      ),
    );
  }

  MapLayerScene sceneFor(OpenedMapSession session) {
    if (identical(session, _cachedSceneSession) &&
        identical(_state, _cachedSceneState) &&
        _cachedScene != null) {
      return _cachedScene!;
    }

    final points = <MapLayerPointObject>[];
    final regions = <MapLayerRegionObject>[];
    final counts = <MapLayerType, int>{
      for (final layer in MapLayerType.values) layer: 0,
    };
    final objects = session.objectViews;

    for (final section in objects.unitSections) {
      counts[MapLayerType.units] =
          counts[MapLayerType.units]! + section.units.length;
      if (!_state.statusOf(MapLayerType.units).isVisible) {
        continue;
      }
      for (final unit in section.units) {
        points.add(
          MapLayerPointObject(
            object: MapLayerObjectRef(
              layer: MapLayerType.units,
              sectionIndex: section.sectionIndex,
              recordIndex: unit.recordIndex,
            ),
            pixelX: unit.x,
            pixelY: unit.y,
            graphicKey: StarCraftObjectGraphicKey(
              kind: StarCraftObjectGraphicKind.unit,
              id: unit.unitType,
              playerColor: StarCraftObjectPreviewPolicy.playerColorForOwner(
                unit.owner,
              ),
            ),
          ),
        );
      }
    }
    for (final section in objects.spriteSections) {
      counts[MapLayerType.sprites] =
          counts[MapLayerType.sprites]! + section.sprites.length;
      if (!_state.statusOf(MapLayerType.sprites).isVisible) {
        continue;
      }
      for (final sprite in section.sprites) {
        points.add(
          MapLayerPointObject(
            object: MapLayerObjectRef(
              layer: MapLayerType.sprites,
              sectionIndex: section.sectionIndex,
              recordIndex: sprite.recordIndex,
            ),
            pixelX: sprite.x,
            pixelY: sprite.y,
            graphicKey: StarCraftObjectGraphicKey(
              kind: sprite.drawsAsSprite
                  ? StarCraftObjectGraphicKind.sprite
                  : StarCraftObjectGraphicKind.unit,
              id: sprite.spriteType,
              playerColor: StarCraftObjectPreviewPolicy.playerColorForOwner(
                sprite.owner,
              ),
            ),
          ),
        );
      }
    }
    for (final section in objects.doodadSections) {
      counts[MapLayerType.doodads] =
          counts[MapLayerType.doodads]! + section.doodads.length;
      if (!_state.statusOf(MapLayerType.doodads).isVisible) {
        continue;
      }
      for (final doodad in section.doodads) {
        points.add(
          MapLayerPointObject(
            object: MapLayerObjectRef(
              layer: MapLayerType.doodads,
              sectionIndex: section.sectionIndex,
              recordIndex: doodad.recordIndex,
            ),
            pixelX: doodad.x,
            pixelY: doodad.y,
          ),
        );
      }
    }
    for (final section in objects.locationSections) {
      final usedLocations = section.locations
          .where((location) => !location.isBlank)
          .toList(growable: false);
      counts[MapLayerType.locations] =
          counts[MapLayerType.locations]! + usedLocations.length;
      if (!_state.statusOf(MapLayerType.locations).isVisible) {
        continue;
      }
      for (final location in usedLocations) {
        regions.add(
          MapLayerRegionObject(
            object: MapLayerObjectRef(
              layer: MapLayerType.locations,
              sectionIndex: section.sectionIndex,
              recordIndex: location.recordIndex,
            ),
            left: location.left,
            top: location.top,
            right: location.right,
            bottom: location.bottom,
          ),
        );
      }
    }
    counts[MapLayerType.terrain] = session.terrainViews.tileMaps.fold(
      0,
      (total, terrain) => total + terrain.tileCount,
    );

    final scene = MapLayerScene(
      points: points,
      regions: regions,
      objectCounts: counts,
      selections: _state.selections,
    );
    _cachedSceneSession = session;
    _cachedSceneState = _state;
    _cachedScene = scene;
    return scene;
  }

  List<MapLayerSelection> orderedHitsAt({
    required OpenedMapSession session,
    required int pixelX,
    required int pixelY,
  }) {
    final scene = sceneFor(session);
    final hitsByLayer = <MapLayerType, List<MapLayerSelection>>{
      for (final layer in MapLayerType.values) layer: [],
    };

    for (final point in scene.points.reversed) {
      final radius = _pointHitRadius[point.object.layer]!;
      final deltaX = point.pixelX - pixelX;
      final deltaY = point.pixelY - pixelY;
      if (deltaX * deltaX + deltaY * deltaY <= radius * radius) {
        hitsByLayer[point.object.layer]!.add(
          MapLayerSelection(
            object: point.object,
            pixelX: point.pixelX,
            pixelY: point.pixelY,
          ),
        );
      }
    }

    final locationHits =
        scene.regions
            .where((region) => region.contains(pixelX, pixelY))
            .toList(growable: false)
          ..sort((first, second) {
            final areaComparison = first.area.compareTo(second.area);
            if (areaComparison != 0) {
              return areaComparison;
            }
            final sectionComparison = second.object.sectionIndex.compareTo(
              first.object.sectionIndex,
            );
            return sectionComparison != 0
                ? sectionComparison
                : second.object.recordIndex.compareTo(first.object.recordIndex);
          });
    for (final region in locationHits) {
      hitsByLayer[MapLayerType.locations]!.add(
        MapLayerSelection(
          object: region.object,
          pixelX: pixelX,
          pixelY: pixelY,
        ),
      );
    }

    final dimensions = session.metadataViews.dimensions.length == 1
        ? session.metadataViews.dimensions.single
        : null;
    final terrain = session.terrainViews.tileMaps.length == 1
        ? session.terrainViews.tileMaps.single
        : null;
    if (dimensions != null &&
        terrain != null &&
        terrain.hasGridDimensions &&
        pixelX >= 0 &&
        pixelY >= 0 &&
        pixelX < dimensions.width * 32 &&
        pixelY < dimensions.height * 32) {
      final tileX = pixelX ~/ 32;
      final tileY = pixelY ~/ 32;
      hitsByLayer[MapLayerType.terrain]!.add(
        MapLayerSelection(
          object: MapLayerObjectRef(
            layer: MapLayerType.terrain,
            sectionIndex: terrain.sectionIndex,
            recordIndex: tileY * dimensions.width + tileX,
          ),
          pixelX: pixelX,
          pixelY: pixelY,
        ),
      );
    }

    return List.unmodifiable([
      for (final layer in _state.selectionPriority) ...hitsByLayer[layer]!,
    ]);
  }

  MapLayerSelection? selectAt({
    required OpenedMapSession session,
    required int pixelX,
    required int pixelY,
    bool additive = false,
  }) {
    final hits = orderedHitsAt(
      session: session,
      pixelX: pixelX,
      pixelY: pixelY,
    );
    final selection = hits.firstOrNull;
    final selections = _updatedSelections(selection, additive: additive);
    if (_sameSelections(_state.selections, selections)) {
      return selection;
    }
    _emit(
      MapLayerState(
        activeLayer: _state.activeLayer,
        layers: _state.layers,
        selections: selections,
      ),
    );
    return selection;
  }

  MapLayerSelection? selectObject({
    required OpenedMapSession session,
    required MapLayerObjectRef object,
  }) {
    if (!_state.statusOf(object.layer).isSelectable) {
      return null;
    }
    final selection = _resolveSelection(session, object);
    if (selection == null) {
      return null;
    }
    if (!_sameSelections(_state.selections, [selection])) {
      _emit(
        MapLayerState(
          activeLayer: _state.activeLayer,
          layers: _state.layers,
          selections: [selection],
        ),
      );
    }
    return selection;
  }

  List<MapLayerSelection> selectRegion({
    required OpenedMapSession session,
    required MapLayerPixelRegion region,
    bool additive = false,
  }) {
    final scene = sceneFor(session);
    final activeLayer = _state.activeLayer;
    final restrictToActive =
        activeLayer != MapLayerType.terrain &&
        _state.statusOf(activeLayer).isSelectable;
    bool accepts(MapLayerType layer) =>
        layer != MapLayerType.terrain &&
        _state.statusOf(layer).isSelectable &&
        (!restrictToActive || layer == activeLayer);

    final selected = <MapLayerSelection>[
      for (final point in scene.points)
        if (accepts(point.object.layer) &&
            region.contains(point.pixelX, point.pixelY))
          MapLayerSelection(
            object: point.object,
            pixelX: point.pixelX,
            pixelY: point.pixelY,
          ),
      for (final location in scene.regions)
        if (accepts(MapLayerType.locations) && region.intersects(location))
          MapLayerSelection(
            object: location.object,
            pixelX: (location.left + location.right) ~/ 2,
            pixelY: (location.top + location.bottom) ~/ 2,
          ),
    ];
    final selections = additive
        ? _mergeSelections(_state.selections, selected)
        : selected;
    if (!_sameSelections(_state.selections, selections)) {
      _emit(
        MapLayerState(
          activeLayer: _state.activeLayer,
          layers: _state.layers,
          selections: selections,
        ),
      );
    }
    return List.unmodifiable(selected);
  }

  void clearSelection() {
    if (_state.selection == null) {
      return;
    }
    _emit(
      MapLayerState(activeLayer: _state.activeLayer, layers: _state.layers),
    );
  }

  List<MapLayerSelection> _updatedSelections(
    MapLayerSelection? selection, {
    required bool additive,
  }) {
    if (!additive) {
      return selection == null ? const [] : [selection];
    }
    if (selection == null) {
      return _state.selections;
    }
    final existingIndex = _state.selections.indexWhere(
      (candidate) => candidate.object == selection.object,
    );
    if (existingIndex >= 0) {
      final updated = _state.selections.toList()..removeAt(existingIndex);
      return updated;
    }
    return [..._state.selections, selection];
  }

  List<MapLayerSelection> _resolveSelections(
    OpenedMapSession session,
    Iterable<MapLayerSelection> selections,
  ) {
    return [
      for (final selection in selections)
        ?_resolveSelection(session, selection.object),
    ];
  }

  MapLayerSelection? _resolveSelection(
    OpenedMapSession session,
    MapLayerObjectRef object,
  ) {
    switch (object.layer) {
      case MapLayerType.units:
        final section = session.objectViews.unitSections
            .where((section) => section.sectionIndex == object.sectionIndex)
            .firstOrNull;
        if (section == null ||
            object.recordIndex < 0 ||
            object.recordIndex >= section.units.length) {
          return null;
        }
        final unit = section.units[object.recordIndex];
        return MapLayerSelection(
          object: object,
          pixelX: unit.x,
          pixelY: unit.y,
        );
      case MapLayerType.doodads:
        final section = session.objectViews.doodadSections
            .where((section) => section.sectionIndex == object.sectionIndex)
            .firstOrNull;
        if (section == null ||
            object.recordIndex < 0 ||
            object.recordIndex >= section.doodads.length) {
          return null;
        }
        final doodad = section.doodads[object.recordIndex];
        return MapLayerSelection(
          object: object,
          pixelX: doodad.x,
          pixelY: doodad.y,
        );
      case MapLayerType.sprites:
        final section = session.objectViews.spriteSections
            .where((section) => section.sectionIndex == object.sectionIndex)
            .firstOrNull;
        if (section == null ||
            object.recordIndex < 0 ||
            object.recordIndex >= section.sprites.length) {
          return null;
        }
        final sprite = section.sprites[object.recordIndex];
        return MapLayerSelection(
          object: object,
          pixelX: sprite.x,
          pixelY: sprite.y,
        );
      case MapLayerType.locations:
        final section = session.objectViews.locationSections
            .where((section) => section.sectionIndex == object.sectionIndex)
            .firstOrNull;
        if (section == null ||
            object.recordIndex < 0 ||
            object.recordIndex >= section.locations.length) {
          return null;
        }
        final location = section.locations[object.recordIndex];
        if (location.isBlank) {
          return null;
        }
        return MapLayerSelection(
          object: object,
          pixelX: (location.left + location.right) ~/ 2,
          pixelY: (location.top + location.bottom) ~/ 2,
        );
      case MapLayerType.terrain:
        final dimensions = session.metadataViews.dimensions.length == 1
            ? session.metadataViews.dimensions.single
            : null;
        final terrain = session.terrainViews.tileMaps
            .where((terrain) => terrain.sectionIndex == object.sectionIndex)
            .firstOrNull;
        if (dimensions == null ||
            terrain == null ||
            object.recordIndex < 0 ||
            object.recordIndex >= terrain.tileCount) {
          return null;
        }
        return MapLayerSelection(
          object: object,
          pixelX: (object.recordIndex % dimensions.width) * 32,
          pixelY: (object.recordIndex ~/ dimensions.width) * 32,
        );
    }
  }

  List<MapLayerSelection> _mergeSelections(
    Iterable<MapLayerSelection> first,
    Iterable<MapLayerSelection> second,
  ) {
    final merged = <MapLayerObjectRef, MapLayerSelection>{};
    for (final selection in [...first, ...second]) {
      merged[selection.object] = selection;
    }
    return merged.values.toList(growable: false);
  }

  bool _sameSelections(
    List<MapLayerSelection> first,
    List<MapLayerSelection> second,
  ) {
    if (first.length != second.length) {
      return false;
    }
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) {
        return false;
      }
    }
    return true;
  }

  Future<void> dispose() => _changes.close();

  void _emit(MapLayerState state) {
    _state = state;
    _cachedSceneSession = null;
    _cachedSceneState = null;
    _cachedScene = null;
    _changes.add(state);
  }
}
