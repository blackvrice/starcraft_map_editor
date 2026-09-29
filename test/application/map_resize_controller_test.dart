import 'package:starcraft_map_editor/application/terrain/terrain_editing_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/map_resize_controller.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/map_resize.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import '../fixtures/new_map_harness.dart';

void main() {
  test(
    'preview is read-only; resize is a single reversible edit with stale preview protection',
    () async {
      final h = NewMapHarness();
      addTearDown(h.dispose);
      h.maps.createNew(
        NewMapOptions(width: 64, height: 64, rawTileValue: 1),
        expectedSession: null,
      );
      final terrainController = TerrainEditingController(
        openMapController: h.maps,
      );
      addTearDown(terrainController.dispose);
      terrainController.selectTileAt(const TerrainTileCoordinate(x: 63, y: 63));
      final before = h.maps.state.session!;
      final bytes = const RawChkEncoder().encode(before.rawDocument);
      final c = MapResizeController(h.maps);
      final p = c.preview(
        MapResizeOptions(
          width: 96,
          height: 128,
          anchor: MapResizeAnchor.center,
        ),
      );
      expect(h.maps.state.session, same(before));
      expect(h.maps.editHistory.undoDepth, 0);
      c.apply(p, acceptCropping: false);
      final after = h.maps.state.session!;
      expect(terrainController.state.selectedTile, isNull);
      expect(after.terrainViews.tileMaps.single.width, 96);
      expect(after.terrainViews.tileMaps.single.height, 128);
      expect(after.extractedMap, same(before.extractedMap));
      expect(after.resourceEdits, same(before.resourceEdits));
      expect(h.maps.editHistory.undoDepth, 1);
      expect(() => c.apply(p, acceptCropping: false), throwsStateError);
      h.maps.editHistory.undo();
      expect(
        const RawChkEncoder().encode(h.maps.state.session!.rawDocument),
        bytes,
      );
      h.maps.editHistory.redo();
      expect(h.maps.state.session, same(after));
    },
  );
  test(
    'busy transaction and changed document reject preview/application',
    () async {
      final h = NewMapHarness();
      addTearDown(h.dispose);
      h.maps.createNew(NewMapOptions(rawTileValue: 1), expectedSession: null);
      final c = MapResizeController(h.maps);
      final options = MapResizeOptions(width: 160, height: 160);
      final p = c.preview(options);
      final owner = Object();
      h.maps.editHistory.beginTransaction(owner);
      expect(() => c.apply(p, acceptCropping: true), throwsStateError);
      h.maps.editHistory.endTransaction(owner);
      h.maps.createNew(
        NewMapOptions(rawTileValue: 2),
        expectedSession: h.maps.state.session,
      );
      expect(() => c.preview(options), throwsStateError);
      expect(() => c.apply(p, acceptCropping: true), throwsStateError);
    },
  );
}
