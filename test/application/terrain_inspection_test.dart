import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/terrain/terrain_editing_controller.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import '../fixtures/new_map_harness.dart';

void main() {
  test(
    'inspection follows raw edits and Undo without changing TILE or dirtying the document',
    () async {
      final h = NewMapHarness();
      addTearDown(h.dispose);
      h.maps.createNew(NewMapOptions(rawTileValue: 32), expectedSession: null);
      final terrain = TerrainEditingController(openMapController: h.maps);
      addTearDown(terrain.dispose);
      final initial = h.maps.state.session!;
      final report = initial.editorTerrain;
      expect(initial.editorTerrain, same(report));
      expect(report.differentTileCount, 0);
      terrain.selectCatalogTile(33);
      terrain.paintTiles([const TerrainTileCoordinate(x: 0, y: 0)]);
      expect(h.maps.state.session!.editorTerrain.differentTileCount, 1);
      h.maps.editHistory.undo();
      expect(h.maps.state.session!.editorTerrain.differentTileCount, 0);
      h.maps.editHistory.redo();
      expect(h.maps.state.session!.editorTerrain.differentTileCount, 1);
    },
  );
}
