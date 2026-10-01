import 'dart:async';
import 'dart:convert';
import '../../domain/chk/chk.dart';
import '../../domain/chk/chk_basic_editing.dart';
import '../documents/open_map_controller.dart';
import '../documents/opened_map_session.dart';
import '../layers/map_layer_controller.dart';
import '../terrain/terrain_editing_controller.dart';
import '../../domain/placement/doodad_placement_recipe.dart';
import '../../domain/chk/chk_editing_clipboard.dart';
import '../../domain/chk/chk_raw_terrain_clipboard.dart';
import '../../domain/placement/doodad_composite_clipboard.dart';
import '../../domain/chk/typed/chk_player_settings_editor.dart';

class BasicEditingController {
  BasicEditingController({required this.maps, required this.layers});
  final OpenMapController maps;
  final MapLayerController layers;
  final editor = const ChkBasicEditing();
  final _changes = StreamController<void>.broadcast(sync: true);
  Stream<void> get changes => _changes.stream;
  OpenedMapSession? _strokeSource;
  RawChkDocument? _stroke;
  ChkEditingClipboard? _clipboard;
  Object? _clipboardSource;
  ChkRawTerrainClipboard? _terrainClipboard;
  Object? _terrainClipboardSource;
  DoodadCompositeClipboard? _doodadClipboard;
  Object? _doodadClipboardSource;
  bool get hasDoodadClipboard =>
      _doodadClipboard != null &&
      identical(_doodadClipboardSource, maps.state.session?.extractedMap);
  bool get hasTerrainClipboard =>
      _terrainClipboard != null &&
      identical(_terrainClipboardSource, maps.state.session?.extractedMap);
  bool get hasClipboard =>
      _clipboard != null &&
      identical(_clipboardSource, maps.state.session?.extractedMap);
  List<int> get fog => editor.fog(_stroke ?? source.rawDocument);
  OpenedMapSession get source {
    final s = maps.state.session;
    if (s == null || s.requiresRestrictedEditing) {
      throw StateError('Open an editable map.');
    }
    final p = maps.operationProgressController.current;
    if (p != null && !p.isTerminal) {
      throw StateError('Another operation is active.');
    }
    editor.dimensions(s.rawDocument);
    return s;
  }

  Set<int> get selectedUnits {
    final selected = layers.state.selections;
    if (selected.isEmpty ||
        selected.any((s) => s.object.layer != MapLayerType.units) ||
        !layers.state.statusOf(MapLayerType.units).isSelectable) {
      throw StateError('Select unlocked units first.');
    }
    final unit = editor.section(source.rawDocument, 'UNIT', stride: 36);
    if (unit == null ||
        selected.any(
          (s) => source.rawDocument.sections[s.object.sectionIndex] != unit,
        )) {
      throw StateError('Unit selection is stale.');
    }
    return {for (final s in selected) s.object.recordIndex};
  }

  bool apply(RawChkDocument expected, RawChkDocument result, String label) {
    if (_stroke != null) {
      throw StateError('Finish or cancel the fog stroke first.');
    }
    maps.editHistory.ensureCanEdit(this);
    final before = source;
    if (!identical(expected, before.rawDocument)) {
      throw StateError('The map changed; refresh the preview.');
    }
    if (identical(expected, result)) return false;
    final metadata = maps.metadataViewDecoder.decode(result),
        terrain = maps.terrainViewDecoder.decode(result);
    final objects = maps.objectViewDecoder.decode(result),
        strings = maps.stringViewDecoder.decode(result);
    if (metadata.hasBlockingDiagnostics ||
        terrain.hasBlockingDiagnostics ||
        objects.hasBlockingDiagnostics ||
        strings.hasBlockingDiagnostics) {
      throw StateError('Edited map failed structural validation.');
    }
    final references = maps.objectReferenceValidator.validate(
      metadataViews: metadata,
      stringViews: strings,
      objectViews: objects,
    );
    if (references.any((d) => d.blocksOperation)) {
      throw StateError('Edited object references failed validation.');
    }
    final after = OpenedMapSession(
      extractedMap: before.extractedMap,
      rawDocument: result,
      metadataViews: metadata,
      stringViews: strings,
      terrainViews: terrain,
      objectViews: objects,
      sourceFingerprint: before.sourceFingerprint,
      diagnostics: [
        ...before.diagnostics.where(
          (d) =>
              !ChkObjectReferenceDiagnosticCodes.contains(d.code) &&
              !d.code.startsWith(ChkPlayerSettingsEditor.diagnosticPrefix),
        ),
        ...references,
        ...const ChkPlayerSettingsEditor().diagnostics(result),
      ],
      resourceEdits: before.resourceEdits,
    );
    maps.adoptEditedSession(after);
    layers.synchronizeSession(after);
    maps.editHistory.record(
      label: label,
      before: before,
      after: after,
      undo: () {
        maps.adoptEditedSession(before);
        layers.synchronizeSession(before);
        layers.clearSelection();
      },
      redo: () {
        maps.adoptEditedSession(after);
        layers.synchronizeSession(after);
        layers.clearSelection();
      },
    );
    return true;
  }

  void beginFogStroke() {
    if (_stroke != null) throw StateError('A brush stroke is already active.');
    final s = source;
    maps.editHistory.beginTransaction(this);
    _strokeSource = s;
    _stroke = s.rawDocument;
  }

  void paintFog(
    List<TerrainTileCoordinate> cells, {
    required int player,
    required bool hidden,
  }) {
    if (_stroke == null || !identical(_strokeSource, maps.state.session)) {
      throw StateError('Fog stroke is stale.');
    }
    _stroke = editor.paintFog(
      _stroke!,
      cells.map((c) => (c.x, c.y)),
      player: player,
      hidden: hidden,
    );
    _changes.add(null);
  }

  bool endFogStroke() {
    final before = _strokeSource, result = _stroke;
    _strokeSource = null;
    _stroke = null;
    if (before == null || result == null) return false;
    maps.editHistory.endTransaction(this);
    return apply(before.rawDocument, result, 'Paint initial fog');
  }

  void cancelFogStroke() {
    if (_stroke != null) {
      maps.editHistory.endTransaction(this);
    }
    _strokeSource = null;
    _stroke = null;
    _changes.add(null);
  }

  bool fillFog(
    TerrainTileRegion region, {
    required int player,
    required bool hidden,
  }) {
    final doc = source.rawDocument;
    return apply(
      doc,
      editor.paintFog(
        doc,
        [
          for (var y = region.top; y <= region.bottom; y++)
            for (var x = region.left; x <= region.right; x++) (x, y),
        ],
        player: player,
        hidden: hidden,
      ),
      'Fill initial fog',
    );
  }

  bool patchUnits({
    Map<int, bool?> states = const {},
    Map<int, bool> validFields = const {},
    int? owner,
    int? hitpoints,
    int? shields,
    int? energy,
    int? resources,
    int? hangar,
  }) {
    final doc = source.rawDocument;
    return apply(
      doc,
      editor.patchUnits(
        doc,
        selectedUnits,
        states: states,
        validFields: validFields,
        owner: owner,
        hitpoints: hitpoints,
        shields: shields,
        energy: energy,
        resources: resources,
        hangar: hangar,
      ),
      'Edit selected units',
    );
  }

  String locationName(ChkLocation location) {
    final session = maps.state.session;
    final tables = [
      ...?session?.stringViews.legacyTables,
      ...?session?.stringViews.extendedTables,
    ];
    if (location.stringId == 0) return 'Location #${location.locationId}';
    if (tables.length != 1) return 'String #${location.stringId}';
    final bytes = tables.single.entryForId(location.stringId)?.rawBytes;
    return bytes == null
        ? 'String #${location.stringId}'
        : utf8.decode(bytes, allowMalformed: true);
  }

  bool setLocationElevation(int index, int mask) {
    final doc = source.rawDocument;
    return apply(
      doc,
      editor.setLocationElevation(doc, index, mask),
      'Edit location elevation',
    );
  }

  bool setSelectedLocationElevations(int mask) {
    final selected = layers.state.selections;
    if (selected.isEmpty ||
        selected.any((s) => s.object.layer != MapLayerType.locations) ||
        !layers.state.statusOf(MapLayerType.locations).isSelectable) {
      throw StateError('Select unlocked locations first.');
    }
    final doc = source.rawDocument,
        section = editor.section(doc, 'MRGN', stride: 20);
    var result = doc;
    for (final s in selected) {
      if (doc.sections[s.object.sectionIndex] != section) {
        throw StateError('Location selection is stale.');
      }
      result = editor.setLocationElevation(result, s.object.recordIndex, mask);
    }
    return apply(doc, result, 'Edit selected location elevations');
  }

  bool setStartLocation({required int player, required int x, required int y}) {
    final doc = source.rawDocument;
    return apply(
      doc,
      editor.setStartLocation(doc, player: player, x: x, y: y),
      'Set start location',
    );
  }

  bool linkUnits({required bool addon}) {
    final doc = source.rawDocument, selected = selectedUnits.toList()..sort();
    if (selected.length != 2) throw StateError('Select exactly two units.');
    return apply(
      doc,
      editor.linkUnits(doc, selected[0], selected[1], addon: addon),
      'Link units',
    );
  }

  bool unlinkUnits() {
    final doc = source.rawDocument;
    return apply(doc, editor.unlinkUnits(doc, selectedUnits), 'Unlink units');
  }

  bool patchSprites({int? owner, bool? disabled}) {
    final doc = source.rawDocument, selections = layers.state.selections;
    final section = editor.section(doc, 'THG2', stride: 10);
    if (section == null ||
        selections.isEmpty ||
        !layers.state.statusOf(MapLayerType.sprites).isSelectable ||
        selections.any(
          (s) =>
              s.object.layer != MapLayerType.sprites ||
              doc.sections[s.object.sectionIndex] != section,
        )) {
      throw StateError('Select unlocked sprites first.');
    }
    return apply(
      doc,
      editor.patchSprites(
        doc,
        {for (final s in selections) s.object.recordIndex},
        owner: owner,
        disabled: disabled,
      ),
      'Edit selected sprites',
    );
  }

  bool setDoodadEnabled({
    required DoodadPlacementRecipe recipe,
    required int recordIndex,
    required bool enabled,
    int? overlayRecordIndex,
  }) {
    for (final layer in [
      MapLayerType.doodads,
      MapLayerType.terrain,
      if (recipe.overlay != null) MapLayerType.sprites,
    ]) {
      if (!layers.state.statusOf(layer).isSelectable) {
        throw StateError('A required Doodad layer is locked.');
      }
    }
    final doc = source.rawDocument;
    return apply(
      doc,
      editor.setDoodadEnabled(
        doc,
        recipe: recipe,
        recordIndex: recordIndex,
        enabled: enabled,
        overlayRecordIndex: overlayRecordIndex,
      ),
      'Edit Doodad enabled state',
    );
  }

  Map<String, Set<int>> _clipboardSelection() {
    final doc = source.rawDocument, selection = layers.state.selections;
    if (selection.isEmpty) throw StateError('Select objects first.');
    final selected = <String, Set<int>>{};
    for (final s in selection) {
      if (!layers.state.statusOf(s.object.layer).isSelectable) {
        throw StateError('Selected layer is locked.');
      }
      final name = switch (s.object.layer) {
        MapLayerType.units => 'UNIT',
        MapLayerType.sprites => 'THG2',
        MapLayerType.locations => 'MRGN',
        _ => throw StateError(
          'Use a verified composite tool for Doodads, or the raw terrain clipboard.',
        ),
      };
      if (doc.sections[s.object.sectionIndex] != editor.section(doc, name)) {
        throw StateError('Selection is stale.');
      }
      selected.putIfAbsent(name, () => {}).add(s.object.recordIndex);
    }
    return selected;
  }

  void copyObjects({bool cut = false}) {
    if (_stroke != null) throw StateError('Finish the brush stroke first.');
    maps.editHistory.ensureCanEdit(this);
    final before = source, selected = _clipboardSelection();
    final clip = ChkEditingClipboard.capture(before.rawDocument, selected);
    if (cut) {
      apply(
        before.rawDocument,
        ChkEditingClipboard.cut(before.rawDocument, selected),
        'Cut selected objects',
      );
      layers.clearSelection();
    }
    _clipboard = clip;
    _clipboardSource = before.extractedMap;
  }

  bool pasteObjects({required int x, required int y}) {
    if (!hasClipboard) {
      throw StateError('Copy objects from this document first.');
    }
    for (final name in _clipboard!.records.keys) {
      final layer = switch (name) {
        'UNIT' => MapLayerType.units,
        'THG2' => MapLayerType.sprites,
        _ => MapLayerType.locations,
      };
      if (!layers.state.statusOf(layer).isSelectable) {
        throw StateError('Destination layer is locked.');
      }
    }
    final doc = source.rawDocument;
    return apply(doc, _clipboard!.paste(doc, x: x, y: y), 'Paste objects');
  }

  void copyTerrain(TerrainTileRegion region, {int? cutReplacement}) {
    if (_stroke != null) throw StateError('Finish the brush stroke first.');
    maps.editHistory.ensureCanEdit(this);
    if (!layers.state.statusOf(MapLayerType.terrain).isSelectable) {
      throw StateError('Terrain layer is locked.');
    }
    final before = source;
    final clip = ChkRawTerrainClipboard.capture(
      before.rawDocument,
      left: region.left,
      top: region.top,
      right: region.right,
      bottom: region.bottom,
    );
    if (cutReplacement != null) {
      apply(
        before.rawDocument,
        ChkRawTerrainClipboard.cut(
          before.rawDocument,
          left: region.left,
          top: region.top,
          right: region.right,
          bottom: region.bottom,
          replacement: cutReplacement,
        ),
        'Cut raw terrain',
      );
    }
    _terrainClipboard = clip;
    _terrainClipboardSource = before.extractedMap;
  }

  bool pasteTerrain({required int x, required int y}) {
    if (!hasTerrainClipboard) {
      throw StateError('Copy terrain from this document first.');
    }
    if (!layers.state.statusOf(MapLayerType.terrain).isSelectable) {
      throw StateError('Terrain layer is locked.');
    }
    final doc = source.rawDocument;
    return apply(
      doc,
      _terrainClipboard!.paste(doc, x: x, y: y),
      'Paste raw terrain',
    );
  }

  void copyDoodad({
    required DoodadPlacementRecipe recipe,
    required int recordIndex,
    int? overlayRecordIndex,
    bool cut = false,
  }) {
    maps.editHistory.ensureCanEdit(this);
    final before = source;
    _requireDoodadLayers(recipe);
    final clip = DoodadCompositeClipboard.capture(
      before.rawDocument,
      recipe: recipe,
      recordIndex: recordIndex,
      overlayRecordIndex: overlayRecordIndex,
    );
    if (cut) {
      apply(
        before.rawDocument,
        DoodadCompositeClipboard.cut(
          before.rawDocument,
          recipe: recipe,
          recordIndex: recordIndex,
          overlayRecordIndex: overlayRecordIndex,
        ),
        'Cut Doodad composite',
      );
      layers.clearSelection();
    }
    _doodadClipboard = clip;
    _doodadClipboardSource = before.extractedMap;
  }

  void _requireDoodadLayers(DoodadPlacementRecipe recipe) {
    for (final layer in [
      MapLayerType.doodads,
      MapLayerType.terrain,
      if (recipe.overlay != null) MapLayerType.sprites,
    ]) {
      if (!layers.state.statusOf(layer).isSelectable) {
        throw StateError('A required composite layer is locked.');
      }
    }
  }

  bool pasteDoodad({required int tileX, required int tileY}) {
    if (!hasDoodadClipboard) {
      throw StateError('Copy a verified Doodad from this document first.');
    }
    _requireDoodadLayers(_doodadClipboard!.recipe);
    final doc = source.rawDocument;
    return apply(
      doc,
      _doodadClipboard!.paste(doc, tileX: tileX, tileY: tileY),
      'Paste Doodad composite',
    );
  }

  Future<void> dispose() async {
    cancelFogStroke();
    await _changes.close();
  }
}
