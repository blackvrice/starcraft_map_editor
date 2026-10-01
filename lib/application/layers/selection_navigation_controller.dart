import 'dart:convert';
import 'dart:math' as math;
import '../documents/open_map_controller.dart';
import '../../domain/chk/raw_chk_document.dart';
import '../../domain/chk/typed/chk_unit_settings_editor.dart';
import 'map_layer_controller.dart';

class MapNavigationTarget {
  const MapNavigationTarget({
    required this.document,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.fit = false,
  });
  final RawChkDocument document;
  final int left, top, right, bottom;
  final bool fit;
}

class MapObjectSearchEntry {
  const MapObjectSearchEntry({
    required this.document,
    required this.object,
    required this.x,
    required this.y,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.typeId,
    this.owner,
    this.name,
    this.drawsAsSprite,
  });
  final RawChkDocument document;
  final MapLayerObjectRef object;
  final int x, y, left, top, right, bottom;
  final int? typeId, owner;
  final String? name;
  final bool? drawsAsSprite;
}

/// Read-only search and UI selection/camera requests. No document/history edits.
class SelectionNavigationController {
  SelectionNavigationController({required this.maps, required this.layers});
  final OpenMapController maps;
  final MapLayerController layers;
  RawChkDocument? _cachedDocument;
  List<MapObjectSearchEntry> _cachedEntries = const [];
  List<MapObjectSearchEntry> get entries {
    final session = maps.state.session;
    if (session == null) return const [];
    final doc = session.rawDocument;
    if (identical(doc, _cachedDocument)) return _cachedEntries;
    ChkUnitSettings? settings;
    try {
      settings = const ChkUnitSettingsEditor().read(doc);
    } on Object {
      /* Missing/ambiguous settings retain numeric IDs. */
    }
    String? unitName(int id) {
      try {
        final name = settings?.name(id);
        return name == null || name.isEmpty ? null : name;
      } on Object {
        return null;
      }
    }

    final tables = [
      ...session.stringViews.legacyTables,
      ...session.stringViews.extendedTables,
    ];
    String? locationName(int id) {
      if (id == 0) return null;
      final bytes = tables.length == 1
          ? tables.single.entryForId(id)?.rawBytes
          : null;
      if (bytes == null) return 'String #$id';
      try {
        return utf8.decode(bytes);
      } on FormatException {
        return 'String #$id';
      }
    }

    final result = <MapObjectSearchEntry>[];
    void point(
      MapLayerType layer,
      int section,
      int record,
      int x,
      int y,
      int type,
      int owner, {
      String? name,
      bool? sprite,
    }) {
      result.add(
        MapObjectSearchEntry(
          document: doc,
          object: MapLayerObjectRef(
            layer: layer,
            sectionIndex: section,
            recordIndex: record,
          ),
          x: x,
          y: y,
          left: x - 16,
          top: y - 16,
          right: x + 16,
          bottom: y + 16,
          typeId: type,
          owner: owner,
          name: name,
          drawsAsSprite: sprite,
        ),
      );
    }

    for (final s in session.objectViews.unitSections) {
      for (final u in s.units) {
        point(
          MapLayerType.units,
          s.sectionIndex,
          u.recordIndex,
          u.x,
          u.y,
          u.unitType,
          u.owner,
          name: unitName(u.unitType),
        );
      }
    }
    for (final s in session.objectViews.spriteSections) {
      for (final u in s.sprites) {
        point(
          MapLayerType.sprites,
          s.sectionIndex,
          u.recordIndex,
          u.x,
          u.y,
          u.spriteType,
          u.owner,
          name: u.drawsAsSprite ? null : unitName(u.spriteType),
          sprite: u.drawsAsSprite,
        );
      }
    }
    for (final s in session.objectViews.doodadSections) {
      for (final u in s.doodads) {
        point(
          MapLayerType.doodads,
          s.sectionIndex,
          u.recordIndex,
          u.x,
          u.y,
          u.doodadType,
          u.owner,
        );
      }
    }
    for (final s in session.objectViews.locationSections) {
      for (final u in s.locations.where((v) => !v.isBlank)) {
        result.add(
          MapObjectSearchEntry(
            document: doc,
            object: MapLayerObjectRef(
              layer: MapLayerType.locations,
              sectionIndex: s.sectionIndex,
              recordIndex: u.recordIndex,
            ),
            x: (u.left + u.right) ~/ 2,
            y: (u.top + u.bottom) ~/ 2,
            left: math.min(u.left, u.right),
            top: math.min(u.top, u.bottom),
            right: math.max(u.left, u.right),
            bottom: math.max(u.top, u.bottom),
            typeId: u.locationId,
            name: locationName(u.stringId),
          ),
        );
      }
    }
    _cachedDocument = doc;
    return _cachedEntries = List.unmodifiable(result);
  }

  List<MapObjectSearchEntry> search({
    String query = '',
    MapLayerType? layer,
    int? owner,
    bool selectableOnly = true,
    String Function(MapObjectSearchEntry)? label,
  }) {
    final q = query.trim().toLowerCase();
    return List.unmodifiable(
      entries.where(
        (e) =>
            (layer == null || e.object.layer == layer) &&
            (owner == null || e.owner == owner) &&
            (!selectableOnly ||
                layers.state.statusOf(e.object.layer).isSelectable) &&
            (q.isEmpty ||
                (q.startsWith('#')
                    ? int.tryParse(q.substring(1)) == e.typeId
                    : '${e.name ?? ''} ${e.object.layer.label} ${e.typeId} ${e.x},${e.y} ${label?.call(e) ?? ''}'
                          .toLowerCase()
                          .contains(q))),
      ),
    );
  }

  bool select(
    Iterable<MapObjectSearchEntry> selected, {
    bool additive = false,
  }) {
    final values = selected.toList(), session = maps.state.session;
    if (session == null ||
        values.any((e) => !identical(e.document, session.rawDocument))) {
      return false;
    }
    return layers.selectObjects(
      session: session,
      objects: values.map((e) => e.object),
      additive: additive,
    );
  }

  List<MapObjectSearchEntry> get _scope => search(
    layer: layers.state.activeLayer == MapLayerType.terrain
        ? null
        : layers.state.activeLayer,
  );
  bool get _scopeAvailable =>
      layers.state.activeLayer == MapLayerType.terrain ||
      layers.state.statusOf(layers.state.activeLayer).isSelectable;
  bool selectAll() => _scopeAvailable && select(_scope);
  bool invert() =>
      _scopeAvailable &&
      select(
        _scope.where(
          (e) => !layers.state.selections.any((v) => v.object == e.object),
        ),
      );
  bool selectRelated({bool byOwner = false}) {
    final ref = layers.state.selection?.object;
    final current = entries.where((e) => e.object == ref).firstOrNull;
    if (current == null || (byOwner && current.owner == null)) return false;
    return select(
      search(layer: current.object.layer).where(
        (e) => byOwner
            ? e.owner == current.owner
            : e.typeId == current.typeId &&
                  e.drawsAsSprite == current.drawsAsSprite,
      ),
    );
  }

  MapNavigationTarget? focusSelection({bool fit = false}) {
    final refs = layers.state.selections.map((v) => v.object).toSet();
    final selected = entries
        .where(
          (e) =>
              refs.contains(e.object) &&
              layers.state.statusOf(e.object.layer).isSelectable,
        )
        .toList();
    if (refs.isEmpty) return null;
    final (w, h) = _dimensions();
    final session = maps.state.session!;
    for (final ref in refs.where(
      (e) =>
          e.layer == MapLayerType.terrain &&
          layers.state.statusOf(e.layer).isSelectable,
    )) {
      final grid = session.terrainViews.tileMaps
          .where(
            (e) => e.sectionIndex == ref.sectionIndex && e.hasGridDimensions,
          )
          .firstOrNull;
      if (grid == null ||
          ref.recordIndex < 0 ||
          ref.recordIndex >= grid.tileCount) {
        continue;
      }
      final x = ref.recordIndex % w * 32, y = ref.recordIndex ~/ w * 32;
      selected.add(
        MapObjectSearchEntry(
          document: session.rawDocument,
          object: ref,
          x: x + 16,
          y: y + 16,
          left: x,
          top: y,
          right: x + 32,
          bottom: y + 32,
        ),
      );
    }
    if (selected.isEmpty) return null;
    return MapNavigationTarget(
      document: maps.state.session!.rawDocument,
      left: selected.map((e) => e.left).reduce(math.min).clamp(0, w * 32),
      top: selected.map((e) => e.top).reduce(math.min).clamp(0, h * 32),
      right: selected.map((e) => e.right).reduce(math.max).clamp(0, w * 32),
      bottom: selected.map((e) => e.bottom).reduce(math.max).clamp(0, h * 32),
      fit: fit,
    );
  }

  (int, int) _dimensions() {
    final dims = maps.state.session?.metadataViews.dimensions;
    if (dims == null ||
        dims.length != 1 ||
        dims.single.width < 1 ||
        dims.single.height < 1 ||
        dims.single.width > 256 ||
        dims.single.height > 256) {
      throw StateError('A unique supported map size is required.');
    }
    return (dims.single.width, dims.single.height);
  }

  MapNavigationTarget goTo(int x, int y, {bool tiles = false}) {
    final (w, h) = _dimensions();
    RangeError.checkValueInInterval(x, 0, tiles ? w - 1 : w * 32 - 1, 'x');
    RangeError.checkValueInInterval(y, 0, tiles ? h - 1 : h * 32 - 1, 'y');
    if (tiles) {
      x = x * 32 + 16;
      y = y * 32 + 16;
    }
    return MapNavigationTarget(
      document: maps.state.session!.rawDocument,
      left: x,
      top: y,
      right: x,
      bottom: y,
    );
  }

  MapNavigationTarget fitMap() {
    final (w, h) = _dimensions();
    return MapNavigationTarget(
      document: maps.state.session!.rawDocument,
      left: 0,
      top: 0,
      right: w * 32,
      bottom: h * 32,
      fit: true,
    );
  }
}
