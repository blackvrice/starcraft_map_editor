import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/application/settings/starcraft_data_asset_settings_controller.dart';
import '../fixtures/new_map_harness.dart';
import '../fixtures/new_map_terrain_fixture.dart';
import '../fixtures/solid_isom_fixture.dart';
import 'package:starcraft_map_editor/application/ports/terrain_connection_snapshot_gateway.dart';

void main() {
  test(
    'verified terrain creates ISOM map and rejects stale asset selections',
    () async {
      final h = NewMapHarness();
      addTearDown(h.dispose);
      final c = h.controller(terrainGateway: NewMapTerrainGateway());
      addTearDown(c.dispose);
      final terrain = await c.loadTerrain(StarCraftTilesetAssetSet.badlands);
      expect(terrain.shapes.keys, containsAll([2, 3]));
      expect(c.terrainPreviews[2], hasLength(4096));
      final options = c.terrainOptions(
        NewMapOptions(width: 32, height: 32, rawTileValue: 0),
        2,
        91,
      );
      final session = c.create(options);
      expect(session.sourcePath, isNull);
      expect(session.rawDocument.sections.any((s) => s.name == 'ISOM'), isTrue);
      expect(() => c.create(options), throwsStateError);
      final next = h.controller(terrainGateway: NewMapTerrainGateway());
      addTearDown(next.dispose);
      await next.loadTerrain(StarCraftTilesetAssetSet.badlands);
      final stale = next.terrainOptions(NewMapOptions(rawTileValue: 0), 2, 92);
      h.assets = StarCraftDataAssetSettingsState(
        status: StarCraftDataAssetSettingsStatus.unconfigured,
      );
      expect(() => next.create(stale), throwsStateError);
      expect(h.maps.state.session, same(session));
    },
  );

  test(
    'terrain cancellation and inconsistent atlas never replace map',
    () async {
      final h = NewMapHarness();
      addTearDown(h.dispose);
      final gateway = NewMapTerrainGateway()
        ..pending = Completer<TerrainSnapshotReadResult>();
      final c = h.controller(terrainGateway: gateway);
      final pending = expectLater(
        c.loadTerrain(StarCraftTilesetAssetSet.badlands),
        throwsStateError,
      );
      c.dispose();
      expect(gateway.cancelled, [gateway.operation]);
      gateway.pending!.complete(
        TerrainSnapshotReadResult(snapshot: solidSnapshot()),
      );
      await pending;
      final mismatch = h.controller(terrainGateway: SolidSnapshotGateway());
      addTearDown(mismatch.dispose);
      await expectLater(
        mismatch.loadTerrain(StarCraftTilesetAssetSet.badlands),
        throwsStateError,
      );
      expect(
        () => mismatch.create(NewMapOptions(rawTileValue: 0)),
        throwsStateError,
      );
      expect(h.maps.state.session, isNull);
    },
  );
  test(
    'creates unsaved map only from verified current tiles without file IO',
    () async {
      final h = NewMapHarness();
      addTearDown(h.dispose);
      final c = h.controller();
      addTearDown(c.dispose);
      expect(() => c.create(NewMapOptions(rawTileValue: 0)), throwsStateError);
      await c.loadTiles(StarCraftTilesetAssetSet.badlands);
      expect(
        () => c.create(NewMapOptions(rawTileValue: 100)),
        throwsStateError,
      );
      final session = c.create(
        NewMapOptions(rawTileValue: 1, width: 32, height: 64),
      );
      expect(session.isNewMap, isTrue);
      expect(session.isDirty, isTrue);
      expect(session.sourcePath, isNull);
      expect(session.sourceFingerprint, isNull);
      expect(h.maps.editHistory.canUndo, isFalse);
      expect(() => c.create(NewMapOptions(rawTileValue: 1)), throwsStateError);
      expect(h.maps.state.session, same(session));
    },
  );
  test(
    'new page invalidates old selection and settings changes reject creation',
    () async {
      final h = NewMapHarness();
      addTearDown(h.dispose);
      final c = h.controller();
      addTearDown(c.dispose);
      await c.loadTiles(StarCraftTilesetAssetSet.badlands);
      await c.loadTiles(StarCraftTilesetAssetSet.badlands, offset: 64);
      expect(() => c.create(NewMapOptions(rawTileValue: 1)), throwsStateError);
      h.assets = StarCraftDataAssetSettingsState(
        status: StarCraftDataAssetSettingsStatus.unconfigured,
      );
      expect(() => c.create(NewMapOptions(rawTileValue: 65)), throwsStateError);
      await expectLater(
        c.loadTiles(StarCraftTilesetAssetSet.badlands),
        throwsStateError,
      );
      expect(h.maps.state.session, isNull);
    },
  );
  test(
    'late catalog and failed reload cannot create or replace a document',
    () async {
      final h = NewMapHarness();
      addTearDown(h.dispose);
      final c = h.controller();
      addTearDown(c.dispose);
      final pending = Completer<void>();
      h.catalog.beforeReturn = () => pending.future;
      final load = c.loadTiles(StarCraftTilesetAssetSet.badlands);
      final failure = expectLater(load, throwsStateError);
      c.dispose();
      pending.complete();
      await failure;
      expect(h.maps.state.session, isNull);
      final next = h.controller();
      addTearDown(next.dispose);
      h.catalog.beforeReturn = null;
      await next.loadTiles(StarCraftTilesetAssetSet.badlands);
      h.catalog.fail = true;
      await expectLater(
        next.loadTiles(StarCraftTilesetAssetSet.badlands),
        throwsStateError,
      );
      expect(
        () => next.create(NewMapOptions(rawTileValue: 0)),
        throwsStateError,
      );
    },
  );
}
