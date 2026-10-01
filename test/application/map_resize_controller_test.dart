import 'package:starcraft_map_editor/application/terrain/terrain_editing_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/map_resize_controller.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/map_resize.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import '../fixtures/new_map_harness.dart';
import 'dart:async';
import 'package:starcraft_map_editor/application/documents/isom_fill_controller.dart';
import '../fixtures/solid_isom_fixture.dart';
import '../fixtures/isom_ramp_fixture.dart';
import 'package:starcraft_map_editor/application/ports/terrain_connection_snapshot_gateway.dart';
import 'package:starcraft_map_editor/application/settings/starcraft_data_asset_settings_controller.dart';

void main() {
  test(
    'installation changes reject a loaded ISOM preview before application',
    () async {
      final h = NewMapHarness();
      addTearDown(h.dispose);
      h.maps.createNew(
        NewMapOptions(width: 32, height: 32, rawTileValue: 0),
        expectedSession: null,
      );
      final loader = IsomFillController(
        maps: h.maps,
        assets: () => h.assets,
        gateway: SolidSnapshotGateway(),
      );
      await loader.load();
      loader.apply(loader.preview(terrainType: 2));
      final before = h.maps.state.session;
      final c = MapResizeController(h.maps, terrainLoader: loader);
      addTearDown(c.dispose);
      await c.loadTerrain();
      final p = c.preview(MapResizeOptions(width: 64, height: 64));
      expect(p.canApply, isTrue);
      h.assets = StarCraftDataAssetSettingsState(
        status: StarCraftDataAssetSettingsStatus.ready,
        configuredPath: r'C:\OtherStarCraft',
      );
      expect(() => c.apply(p, acceptCropping: false), throwsStateError);
      expect(h.maps.state.session, same(before));
    },
  );
  test(
    'ISOM and doodad resize loads data and applies one reversible document edit',
    () async {
      final h = NewMapHarness();
      addTearDown(h.dispose);
      h.maps.createNew(
        NewMapOptions(width: 32, height: 32, rawTileValue: 0),
        expectedSession: null,
      );
      final loader = IsomFillController(
        maps: h.maps,
        assets: () => h.assets,
        gateway: SolidSnapshotGateway(),
        placementGateway: IsomRampGateway(),
      );
      await loader.load();
      loader.apply(loader.preview(terrainType: 2));
      await loader.load();
      loader.apply(
        loader.previewRamp(recipe: loader.ramps.single, x: 8, y: 10),
      );
      final before = h.maps.state.session!,
          depth = h.maps.editHistory.undoDepth;
      final c = MapResizeController(h.maps, terrainLoader: loader);
      addTearDown(c.dispose);
      final options = MapResizeOptions(
        width: 64,
        height: 96,
        anchor: MapResizeAnchor.center,
      );
      expect(c.preview(options).canApply, isFalse);
      await c.loadTerrain();
      final p = c.preview(options);
      expect(p.blockers, isEmpty);
      expect(p.movedDoodads, 1);
      expect(h.maps.state.session, same(before));
      expect(h.maps.editHistory.undoDepth, depth);
      c.apply(p, acceptCropping: false);
      final after = h.maps.state.session!;
      expect(after.terrainViews.tileMaps.single.width, 64);
      expect(
        after.objectViews.doodadSections.single.doodads.single.x,
        288 + 512,
      );
      expect(after.resourceEdits, same(before.resourceEdits));
      expect(after.sourceFingerprint, same(before.sourceFingerprint));
      expect(h.maps.editHistory.undoDepth, depth + 1);
      h.maps.editHistory.undo();
      expect(h.maps.state.session, same(before));
      h.maps.editHistory.redo();
      expect(h.maps.state.session, same(after));
      expect(() => c.apply(p, acceptCropping: false), throwsStateError);
    },
  );
  test(
    'closing resize cancels late terrain metadata without changing the document',
    () async {
      final h = NewMapHarness();
      addTearDown(h.dispose);
      h.maps.createNew(
        NewMapOptions(width: 32, height: 32, rawTileValue: 0),
        expectedSession: null,
      );
      final gateway = SolidSnapshotGateway();
      final loader = IsomFillController(
        maps: h.maps,
        assets: () => h.assets,
        gateway: gateway,
      );
      await loader.load();
      loader.apply(loader.preview(terrainType: 2));
      final before = h.maps.state.session!;
      gateway.pending = Completer();
      final c = MapResizeController(h.maps, terrainLoader: loader);
      final loading = c.loadTerrain(),
          failed = expectLater(loading, throwsStateError);
      c.dispose();
      expect(gateway.cancelled, isNotEmpty);
      gateway.pending!.complete(
        TerrainSnapshotReadResult(snapshot: solidSnapshot()),
      );
      await failed;
      expect(h.maps.state.session, same(before));
    },
  );
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
