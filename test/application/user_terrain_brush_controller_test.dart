import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/editing/basic_editing_controller.dart';
import 'package:starcraft_map_editor/application/documents/isom_fill_controller.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/ports/terrain_connection_snapshot_gateway.dart';
import 'package:starcraft_map_editor/application/settings/starcraft_data_asset_settings_controller.dart';
import 'package:starcraft_map_editor/application/terrain/user_terrain_brush_controller.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/chk_mixed_clipboard.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/domain/terrain/user_terrain_brush.dart';
import '../fixtures/new_map_harness.dart';
import '../fixtures/solid_isom_fixture.dart';
import '../fixtures/basic_editing_fixture.dart';
import '../fixtures/user_terrain_brush_fixture.dart';

void main() {
  late NewMapHarness h;
  late MapLayerController layers;
  late BasicEditingController editing;
  late UserTerrainBrushController c;
  setUp(() {
    h = NewMapHarness();
    layers = MapLayerController();
    h.maps.createNew(
      NewMapOptions(width: 32, height: 32, rawTileValue: 2),
      expectedSession: null,
    );
    editing = BasicEditingController(maps: h.maps, layers: layers);
    c = UserTerrainBrushController(editing);
  });
  tearDown(() async {
    c.dispose();
    await editing.dispose();
    await layers.dispose();
    await h.dispose();
  });
  test('read-only preview and explicit one-Undo apply preserve resources', () {
    final before = editing.source,
        depth = h.maps.editHistory.undoDepth,
        bytes = const RawChkEncoder().encode(before.rawDocument);
    final p = c.previewPaste(rawUserBrush(), x: 8, y: 8);
    expect(editing.source, same(before));
    expect(h.maps.editHistory.undoDepth, depth);
    expect(c.apply(p), isTrue);
    expect(h.maps.editHistory.undoDepth, depth + 1);
    expect(editing.source.resourceEdits, same(before.resourceEdits));
    expect(() => c.apply(p), throwsStateError);
    h.maps.editHistory.undo();
    expect(const RawChkEncoder().encode(editing.source.rawDocument), bytes);
    h.maps.editHistory.redo();
    expect(c.apply(c.previewPaste(rawUserBrush(), x: 8, y: 8)), isFalse);
    expect(h.maps.editHistory.undoDepth, depth + 1);
  });
  test(
    'stale session, lock, hidden layer, transaction and disposal reject atomically',
    () {
      final brush = rawUserBrush(),
          p = c.previewPaste(rawUserBrush(), x: 0, y: 0),
          before = editing.source;
      layers.setLocked(MapLayerType.terrain, true);
      expect(() => c.apply(p), throwsStateError);
      expect(editing.source, same(before));
      layers.setLocked(MapLayerType.terrain, false);
      layers.setVisible(MapLayerType.terrain, false);
      expect(() => c.previewPaste(brush, x: 0, y: 0), throwsStateError);
      layers.setVisible(MapLayerType.terrain, true);
      final next = c.previewPaste(brush, x: 0, y: 0);
      editing.beginFogStroke();
      expect(() => c.apply(next), throwsStateError);
      editing.cancelFogStroke();
      editing.apply(editing.source.rawDocument, basicDocument(), 'replace');
      expect(c.preview, isNull);
      expect(() => c.apply(next), throwsStateError);
      c.dispose();
      expect(() => c.previewPaste(brush, x: 0, y: 0), throwsStateError);
    },
  );
  test(
    'captured brush is immutable and reusable after source document closes',
    () {
      final brush = c.capture(
        'Reusable',
        ClipboardRegion(0, 0, 1, 1),
        TerrainBrushProfile.raw,
      );
      final old = editing.source;
      h.maps.createNew(
        NewMapOptions(width: 32, height: 32, rawTileValue: 3),
        expectedSession: old,
      );
      expect(c.apply(c.previewPaste(brush, x: 0, y: 0)), isTrue);
      expect(
        editing.source.terrainViews.tileMaps.single.rawTileValues.first,
        2,
      );
    },
  );
  test('late catalog and disposed loader cannot be adopted', () async {
    final gateway = SolidSnapshotGateway()
      ..pending = Completer<TerrainSnapshotReadResult>();
    final loader = IsomFillController(
      maps: h.maps,
      assets: () => h.assets,
      gateway: gateway,
    );
    c.dispose();
    c = UserTerrainBrushController(editing, loader: loader);
    final task = c.loadCatalog(),
        rejected = expectLater(task, throwsStateError);
    c.dispose();
    gateway.pending!.complete(
      TerrainSnapshotReadResult(snapshot: solidSnapshot()),
    );
    await rejected;
    expect(c.catalog, isNull);
  });
  test('asset revision invalidation drops loaded catalog', () async {
    final loader = IsomFillController(
      maps: h.maps,
      assets: () => h.assets,
      gateway: SolidSnapshotGateway(),
    );
    c.dispose();
    c = UserTerrainBrushController(editing, loader: loader);
    await c.loadCatalog();
    expect(c.catalog, isNotNull);
    h.assets = StarCraftDataAssetSettingsState(
      status: StarCraftDataAssetSettingsStatus.ready,
      configuredPath: r'C:\Other',
    );
    expect(c.catalog, isNull);
  });
}
