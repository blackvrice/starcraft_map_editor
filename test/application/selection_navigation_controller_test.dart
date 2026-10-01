import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/editing/basic_editing_controller.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/layers/selection_navigation_controller.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import '../fixtures/new_map_harness.dart';
import '../fixtures/basic_editing_fixture.dart';

void main() {
  late NewMapHarness h;
  late MapLayerController layers;
  late SelectionNavigationController c;
  late BasicEditingController edit;
  setUp(() {
    h = NewMapHarness();
    layers = MapLayerController();
    h.maps.createNew(
      NewMapOptions(width: 32, height: 32, rawTileValue: 1),
      expectedSession: null,
    );
    edit = BasicEditingController(maps: h.maps, layers: layers);
    edit.apply(
      edit.source.rawDocument,
      basicDocument(
        units: [
          basicUnit(id: 1),
          basicUnit(id: 2, owner: 1, x: 300),
          basicUnit(id: 3, type: 1, x: 500),
        ],
      ),
      'Fixture',
    );
    layers.setActiveLayer(MapLayerType.units);
    c = SelectionNavigationController(maps: h.maps, layers: layers);
  });
  tearDown(() async {
    await edit.dispose();
    await layers.dispose();
    await h.dispose();
  });

  test(
    'search/type/owner filters do not modify document or selection and include readonly location names',
    () {
      final source = edit.source, depth = h.maps.editHistory.undoDepth;
      expect(c.search(query: '#0').length, 2);
      expect(c.search(layer: MapLayerType.units, owner: 1).single.x, 300);
      expect(
        c.search(query: 'Anywhere').single.object.layer,
        MapLayerType.locations,
      );
      expect(c.select(c.search(query: '#0')), isTrue);
      final selected = layers.state.selections.toList();
      expect(c.search(query: 'unmatched'), isEmpty);
      expect(layers.state.selections, selected);
      expect(edit.source, same(source));
      expect(h.maps.editHistory.undoDepth, depth);
      h.maps.editHistory.undo();
      final redo = h.maps.editHistory.redoDepth, restored = edit.source;
      c.fitMap();
      c.goTo(128, 128);
      c.selectAll();
      expect(h.maps.editHistory.redoDepth, redo);
      expect(edit.source, same(restored));
    },
  );
  test(
    'all/invert/type/owner scope follows active layer and rejects hidden or locked requests atomically',
    () {
      final all = c.search(layer: MapLayerType.units);
      expect(c.select([all.first]), isTrue);
      expect(c.selectRelated(), isTrue);
      expect(layers.state.selections.length, 2);
      expect(c.invert(), isTrue);
      expect(layers.state.selection!.object, all.last.object);
      expect(c.selectRelated(byOwner: true), isTrue);
      expect(layers.state.selections.length, 2);
      expect(c.selectAll(), isTrue);
      expect(layers.state.selections.length, 3);
      layers.setLocked(MapLayerType.units, true);
      layers.setActiveLayer(MapLayerType.terrain);
      final location = c.search(layer: MapLayerType.locations).single;
      expect(c.select([location]), isTrue);
      final prior = layers.state;
      expect(c.select([location, all.first]), isFalse);
      expect(layers.state, same(prior));
      expect(c.search(layer: MapLayerType.units), isEmpty);
      expect(
        c.search(layer: MapLayerType.units, selectableOnly: false).length,
        3,
      );
      layers.setLocked(MapLayerType.units, false);
      layers.setVisible(MapLayerType.units, false);
      expect(c.select(all), isFalse);
    },
  );
  test(
    'stale results and invalid refs preserve selection, navigation validates coordinate units',
    () {
      final old = c.search(layer: MapLayerType.units);
      c.select([old.first]);
      edit.setStartLocation(player: 0, x: 600, y: 600);
      final prior = layers.state;
      expect(c.select(old), isFalse);
      expect(layers.state, same(prior));
      expect(
        layers.selectObjects(
          session: edit.source,
          objects: [
            old.first.object,
            const MapLayerObjectRef(
              layer: MapLayerType.units,
              sectionIndex: 999,
              recordIndex: 0,
            ),
          ],
        ),
        isFalse,
      );
      expect(layers.state, same(prior));
      expect(c.goTo(31, 31, tiles: true).left, 1008);
      expect(c.goTo(1023, 1023).left, 1023);
      expect(() => c.goTo(32, 0, tiles: true), throwsRangeError);
      expect(() => c.goTo(-1, 0), throwsRangeError);
      c.select(c.search(layer: MapLayerType.units, owner: 1));
      final target = c.focusSelection(fit: true)!;
      expect(
        (target.left, target.top, target.right, target.bottom),
        (284, 112, 316, 144),
      );
      expect(target.document, same(edit.source.rawDocument));
      expect(c.fitMap().right, 1024);
      layers.setActiveLayer(MapLayerType.terrain);
      layers.selectAt(session: edit.source, pixelX: 900, pixelY: 900);
      final tile = c.focusSelection()!;
      expect(
        (tile.left, tile.top, tile.right, tile.bottom),
        (896, 896, 928, 928),
      );
    },
  );
}
