import 'dart:async';

import '../documents/opened_map_session.dart';

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
  });

  final MapLayerObjectRef object;
  final int pixelX;
  final int pixelY;
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

final class MapLayerScene {
  MapLayerScene({
    required Iterable<MapLayerPointObject> points,
    required Iterable<MapLayerRegionObject> regions,
    required Map<MapLayerType, int> objectCounts,
    required this.selection,
  }) : points = List.unmodifiable(points),
       regions = List.unmodifiable(regions),
       objectCounts = Map.unmodifiable(objectCounts);

  final List<MapLayerPointObject> points;
  final List<MapLayerRegionObject> regions;
  final Map<MapLayerType, int> objectCounts;
  final MapLayerSelection? selection;
}

final class MapLayerState {
  MapLayerState({
    this.activeLayer = MapLayerType.terrain,
    Map<MapLayerType, MapLayerStatus>? layers,
    this.selection,
  }) : layers = Map.unmodifiable(layers ?? _defaultLayerStatuses);

  final MapLayerType activeLayer;
  final Map<MapLayerType, MapLayerStatus> layers;
  final MapLayerSelection? selection;

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
  OpenedMapSession? _cachedSceneSession;
  MapLayerState? _cachedSceneState;
  MapLayerScene? _cachedScene;

  MapLayerState get state => _state;

  Stream<MapLayerState> get changes => _changes.stream;

  void synchronizeSession(OpenedMapSession? session) {
    final sourceSnapshot = session?.extractedMap;
    if (identical(sourceSnapshot, _trackedSourceSnapshot)) {
      return;
    }
    _trackedSourceSnapshot = sourceSnapshot;
    _emit(
      MapLayerState(activeLayer: _state.activeLayer, layers: _state.layers),
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
        selection: _state.selection,
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
    final selection = _state.selection?.object.layer == layer && !isVisible
        ? null
        : _state.selection;
    _emit(
      MapLayerState(
        activeLayer: _state.activeLayer,
        layers: updated,
        selection: selection,
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
    final selection = _state.selection?.object.layer == layer && isLocked
        ? null
        : _state.selection;
    _emit(
      MapLayerState(
        activeLayer: _state.activeLayer,
        layers: updated,
        selection: selection,
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
      selection: _state.selection,
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
  }) {
    final hits = orderedHitsAt(
      session: session,
      pixelX: pixelX,
      pixelY: pixelY,
    );
    final selection = hits.firstOrNull;
    if (_state.selection == selection) {
      return selection;
    }
    _emit(
      MapLayerState(
        activeLayer: _state.activeLayer,
        layers: _state.layers,
        selection: selection,
      ),
    );
    return selection;
  }

  void clearSelection() {
    if (_state.selection == null) {
      return;
    }
    _emit(
      MapLayerState(activeLayer: _state.activeLayer, layers: _state.layers),
    );
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
