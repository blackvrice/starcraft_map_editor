import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/isom_fill_controller.dart';
import 'package:starcraft_map_editor/application/ports/terrain_connection_snapshot_gateway.dart';
import 'package:starcraft_map_editor/application/settings/starcraft_data_asset_settings_controller.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import '../fixtures/new_map_harness.dart';
import '../fixtures/solid_isom_fixture.dart';

void main() {
  NewMapHarness harness() {
    final h = NewMapHarness();
    addTearDown(h.dispose);
    h.maps.createNew(
      NewMapOptions(width: 32, height: 32, rawTileValue: 0),
      expectedSession: null,
    );
    return h;
  }

  test(
    'preview, single Undo/Redo and no-op follow the shared document history',
    () async {
      final h = harness();
      final c = IsomFillController(
        maps: h.maps,
        assets: () => h.assets,
        gateway: SolidSnapshotGateway(),
      );
      final before = h.maps.state.session!;
      await c.load();
      final p = c.preview(terrainType: 2);
      expect(h.maps.state.session, same(before));
      expect(h.maps.editHistory.undoDepth, 0);
      expect(c.apply(p), isTrue);
      final after = h.maps.state.session!;
      expect(after.resourceEdits, same(before.resourceEdits));
      expect(after.extractedMap, same(before.extractedMap));
      expect(h.maps.editHistory.undoDepth, 1);
      expect(() => c.apply(p), throwsStateError);
      h.maps.editHistory.undo();
      expect(h.maps.state.session, same(before));
      h.maps.editHistory.redo();
      expect(h.maps.state.session, same(after));
      await c.load();
      expect(c.apply(c.preview(terrainType: 2)), isFalse);
      expect(h.maps.editHistory.undoDepth, 1);
    },
  );
  test('cancellation and late data cannot replace the current map', () async {
    final h = harness(), g = SolidSnapshotGateway()..pending = Completer();
    final c = IsomFillController(
      maps: h.maps,
      assets: () => h.assets,
      gateway: g,
    );
    final f = c.load();
    final failed = expectLater(f, throwsStateError);
    c.invalidate();
    expect(g.cancelled, [g.operation]);
    g.pending!.complete(TerrainSnapshotReadResult(snapshot: solidSnapshot()));
    await failed;
    g.pending = null;
    await c.load();
    final p = c.preview(terrainType: 2);
    final owner = Object();
    h.maps.editHistory.beginTransaction(owner);
    expect(() => c.apply(p), throwsStateError);
    h.maps.editHistory.endTransaction(owner);
    h.assets = StarCraftDataAssetSettingsState(
      status: StarCraftDataAssetSettingsStatus.ready,
      configuredPath: r'C:\Other',
    );
    expect(() => c.apply(p), throwsStateError);
  });
}
