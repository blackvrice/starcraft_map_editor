import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/editing/basic_editing_controller.dart';
import 'package:starcraft_map_editor/application/editing/object_editing_controller.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/terrain/terrain_editing_controller.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import '../fixtures/new_map_harness.dart';
import '../fixtures/basic_editing_fixture.dart';

void main() {
  test(
    'linked-unit deletion clears the retained peer and undo restores the complete relationship',
    () async {
      final h = NewMapHarness();
      addTearDown(h.dispose);
      final layers = MapLayerController();
      addTearDown(layers.dispose);
      h.maps.createNew(
        NewMapOptions(width: 32, height: 32, rawTileValue: 1),
        expectedSession: null,
      );
      final c = BasicEditingController(maps: h.maps, layers: layers);
      addTearDown(c.dispose);
      final objects = ObjectEditingController(
        openMapController: h.maps,
        mapLayerController: layers,
      );
      addTearDown(objects.dispose);
      c.apply(
        c.source.rawDocument,
        basicDocument(
          units: [
            basicUnit(type: 134, id: 1, x: 128, y: 128),
            basicUnit(type: 134, id: 2, x: 192, y: 128),
          ],
        ),
        'Fixture',
      );
      layers.setActiveLayer(MapLayerType.units);
      layers.selectAt(session: c.source, pixelX: 128, pixelY: 128);
      layers.selectAt(
        session: c.source,
        pixelX: 192,
        pixelY: 128,
        additive: true,
      );
      c.linkUnits(addon: false);
      final linked = c.source;
      layers.selectAt(session: c.source, pixelX: 128, pixelY: 128);
      expect(objects.moveSelection(dx: 1, dy: 1), isFalse);
      expect(
        objects.duplicateTemplate(
          template: layers.state.selection!.object,
          pixelX: 300,
          pixelY: 300,
        ),
        isFalse,
      );
      expect(objects.deleteSelection(), isTrue);
      final remaining = c.source.objectViews.unitSections.single.units.single;
      expect(remaining.classId, 2);
      expect(remaining.relationFlags, 0);
      expect(remaining.relationClassId, 0);
      expect(h.maps.editHistory.undo(), isTrue);
      expect(
        c.source.rawDocument.sections,
        orderedEquals(linked.rawDocument.sections),
      );
      c.copyTerrain(
        TerrainTileRegion.fromCorners(
          TerrainTileCoordinate(x: 0, y: 0),
          TerrainTileCoordinate(x: 1, y: 1),
        ),
      );
      expect(c.hasTerrainClipboard, isTrue);
      h.maps.createNew(
        NewMapOptions(width: 32, height: 32, rawTileValue: 1),
        expectedSession: c.source,
      );
      expect(c.hasTerrainClipboard, isFalse);
    },
  );
  test(
    'fog preview cancels without changes or lost redo; committed stroke is one command',
    () async {
      final h = NewMapHarness();
      addTearDown(h.dispose);
      final layers = MapLayerController();
      addTearDown(layers.dispose);
      h.maps.createNew(
        NewMapOptions(width: 32, height: 32, rawTileValue: 1),
        expectedSession: null,
      );
      final c = BasicEditingController(maps: h.maps, layers: layers);
      addTearDown(c.dispose);
      final original = c.source;
      c.beginFogStroke();
      c.paintFog([TerrainTileCoordinate(x: 1, y: 1)], player: 2, hidden: false);
      expect(c.source, same(original));
      expect(c.fog[33], 251);
      expect(
        () => c.setStartLocation(player: 1, x: 10, y: 10),
        throwsStateError,
      );
      c.cancelFogStroke();
      expect(c.source, same(original));
      expect(h.maps.editHistory.canUndo, isFalse);
      c.beginFogStroke();
      c.paintFog(
        [TerrainTileCoordinate(x: 1, y: 1), TerrainTileCoordinate(x: 2, y: 1)],
        player: 2,
        hidden: false,
      );
      c.endFogStroke();
      expect(h.maps.editHistory.undo(), isTrue);
      expect(c.source, same(original));
      c.beginFogStroke();
      c.paintFog([TerrainTileCoordinate(x: 4, y: 1)], player: 2, hidden: false);
      c.cancelFogStroke();
      expect(h.maps.editHistory.canRedo, isTrue);
      expect(h.maps.editHistory.redo(), isTrue);
      expect(c.fog[33], 251);
      expect(c.fog[34], 251);
      c.setStartLocation(player: 1, x: 20, y: 30);
      expect(c.source.objectViews.unitSections.single.units.length, 2);
      h.maps.editHistory.undo();
      expect(c.source.objectViews.unitSections.single.units.length, 1);
      h.maps.editHistory.undo();
      expect(c.source, same(original));
    },
  );
  test(
    'stale expected snapshots and invalid rectangles never mutate the map',
    () async {
      final h = NewMapHarness();
      addTearDown(h.dispose);
      final layers = MapLayerController();
      addTearDown(layers.dispose);
      h.maps.createNew(
        NewMapOptions(width: 32, height: 32, rawTileValue: 1),
        expectedSession: null,
      );
      final c = BasicEditingController(maps: h.maps, layers: layers);
      addTearDown(c.dispose);
      final original = c.source;
      c.setStartLocation(player: 0, x: 20, y: 30);
      expect(
        () => c.apply(original.rawDocument, original.rawDocument, 'Stale'),
        throwsStateError,
      );
      final before = c.source;
      expect(
        () => c.fillFog(
          TerrainTileRegion.fromCorners(
            TerrainTileCoordinate(x: 0, y: 0),
            TerrainTileCoordinate(x: 32, y: 32),
          ),
          player: 0,
          hidden: false,
        ),
        throwsRangeError,
      );
      expect(c.source, same(before));
    },
  );
}
