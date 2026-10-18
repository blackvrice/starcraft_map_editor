import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/terrain/terrain_analysis_controller.dart';
import 'package:starcraft_map_editor/application/editing/basic_editing_controller.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/ports/terrain_placement_snapshot_gateway.dart';
import 'package:starcraft_map_editor/application/settings/starcraft_data_asset_settings_controller.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/domain/terrain/terrain_analysis_view.dart';
import '../fixtures/new_map_harness.dart';
import '../fixtures/terrain_analysis_fixture.dart';
import '../fixtures/basic_editing_fixture.dart';

void main() {
  late NewMapHarness h;
  late AnalysisGateway gateway;
  late TerrainAnalysisController c;
  setUp(() {
    h = NewMapHarness();
    gateway = AnalysisGateway();
    h.maps.createNew(
      NewMapOptions(width: 32, height: 32, rawTileValue: 0),
      expectedSession: null,
    );
    c = TerrainAnalysisController(
      maps: h.maps,
      assets: () => h.assets,
      gateway: gateway,
    );
  });
  tearDown(() async {
    await c.dispose();
    await h.dispose();
  });
  test(
    'explicit load only; no document, history or resource mutation',
    () async {
      final session = h.maps.state.session!,
          bytes = const RawChkEncoder().encode(session.rawDocument),
          depth = h.maps.editHistory.undoDepth;
      expect(c.view!.tileAt(0, 0), isNull);
      expect(gateway.requests, isEmpty);
      c.setMode(TerrainAnalysisMode.elevation);
      expect(gateway.requests, isEmpty);
      expect(await c.load(), isTrue);
      expect(c.view!.tileAt(0, 0)!.elevation(1), 1);
      expect(h.maps.state.session, same(session));
      expect(h.maps.editHistory.undoDepth, depth);
      expect(const RawChkEncoder().encode(session.rawDocument), bytes);
      expect(c.lastRead!.source, same(c.source));
    },
  );
  test(
    'edit and Undo create new views while preserving usable source assets',
    () async {
      await c.load();
      final source = c.source, before = c.view;
      final layers = MapLayerController();
      addTearDown(layers.dispose);
      final editing = BasicEditingController(maps: h.maps, layers: layers);
      addTearDown(editing.dispose);
      editing.apply(editing.source.rawDocument, basicDocument(), 'Fixture');
      expect(c.source, same(source));
      expect(c.view, isNot(same(before)));
      expect(c.view!.rawValues.first, 1);
      h.maps.editHistory.undo();
      expect(c.view, isNot(same(before)));
      expect(gateway.requests.length, 1);
    },
  );
  test(
    'asset identity and map replacement invalidate facts rather than reuse stale cache',
    () async {
      await c.load();
      final before = c.view;
      h.assets = StarCraftDataAssetSettingsState(
        status: StarCraftDataAssetSettingsStatus.ready,
        configuredPath: r'C:\Other',
      );
      expect(c.source, isNull);
      expect(c.view, isNot(same(before)));
      expect(c.view!.tileAt(0, 0), isNull);
      await c.load();
      h.maps.createNew(
        NewMapOptions(width: 32, height: 32, rawTileValue: 0),
        expectedSession: h.maps.state.session,
      );
      expect(c.source, isNull);
      expect(c.view!.tileAt(0, 0), isNull);
    },
  );
  test(
    'late old reply, changed map and disposal cannot adopt metadata',
    () async {
      gateway.delay = true;
      final old = c.load(), next = c.load();
      gateway.pending[1].complete(
        TerrainPlacementReadResult(source: analysisSource()),
      );
      expect(await next, isTrue);
      final current = c.source;
      gateway.pending[0].complete(
        const TerrainPlacementReadResult(errorCode: 'old'),
      );
      expect(await old, isFalse);
      expect(c.source, same(current));
      expect(gateway.cancelled.length, 1);
      final changed = c.load();
      h.maps.createNew(
        NewMapOptions(width: 32, height: 32, rawTileValue: 0),
        expectedSession: h.maps.state.session,
      );
      gateway.pending[2].complete(
        TerrainPlacementReadResult(source: analysisSource()),
      );
      expect(await changed, isFalse);
      expect(c.loading, isFalse);
      final disposed = c.load();
      await c.dispose();
      gateway.pending[3].complete(
        TerrainPlacementReadResult(source: analysisSource()),
      );
      expect(await disposed, isFalse);
      expect(c.source, isNull);
      expect(c.view, isNull);
    },
  );
  test(
    'failed reload clears old facts and is retryable; missing settings never spawn',
    () async {
      await c.load();
      gateway.fail = true;
      expect(await c.load(), isFalse);
      expect(c.source, isNull);
      expect(c.lastRead!.errorCode, 'fixture-failed');
      gateway.fail = false;
      expect(await c.load(), isTrue);
      final count = gateway.requests.length;
      h.assets = const StarCraftDataAssetSettingsState.loading();
      expect(await c.load(), isFalse);
      expect(gateway.requests.length, count);
    },
  );
}
