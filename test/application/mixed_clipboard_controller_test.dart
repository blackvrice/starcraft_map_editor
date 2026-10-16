import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/terrain_connection_snapshot_gateway.dart';
import 'package:starcraft_map_editor/application/documents/isom_fill_controller.dart';
import 'package:starcraft_map_editor/application/editing/basic_editing_controller.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/settings/starcraft_data_asset_settings_controller.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/chk_mixed_clipboard.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import '../fixtures/new_map_harness.dart';
import '../fixtures/solid_isom_fixture.dart';
import '../fixtures/mixed_clipboard_fixture.dart';
import '../fixtures/isom_ramp_fixture.dart';

void main() {
  late NewMapHarness h;
  late MapLayerController layers;
  late BasicEditingController c;
  setUp(() {
    h = NewMapHarness();
    layers = MapLayerController();
    h.maps.createNew(
      NewMapOptions(width: 32, height: 32, rawTileValue: 1),
      expectedSession: null,
    );
    c = BasicEditingController(maps: h.maps, layers: layers);
  });
  tearDown(() async {
    await c.dispose();
    await layers.dispose();
    h.dispose();
  });
  void capture() => c.mixedClipboard.capture(
    region: ClipboardRegion(0, 0, 7, 5),
    profile: MixedClipboardProfile.raw,
    kinds: {'UNIT', 'MRGN', 'THG2', 'DD2 '},
    overlays: {},
  );
  test(
    'a late older catalog cannot replace the latest explicitly loaded data',
    () async {
      final pending = SolidSnapshotGateway()
        ..pending = Completer<TerrainSnapshotReadResult>();
      final old = IsomFillController(
        maps: h.maps,
        assets: () => h.assets,
        gateway: pending,
      );
      final first = c.mixedClipboard.load(old),
          rejected = expectLater(first, throwsStateError);
      final latest = IsomFillController(
        maps: h.maps,
        assets: () => h.assets,
        gateway: SolidSnapshotGateway(),
        placementGateway: MixedDoodadGateway(),
      );
      await c.mixedClipboard.load(latest);
      final expected = c.mixedClipboard.catalog;
      pending.pending!.complete(
        TerrainSnapshotReadResult(snapshot: solidSnapshot()),
      );
      await rejected;
      expect(c.mixedClipboard.catalog, same(expected));
      expect(c.mixedClipboard.hasData, isTrue);
    },
  );
  test(
    'read-only preview, one apply/Undo/Redo, repeat paste and stale preview guards',
    () async {
      // Raw terrain-only payload requires no external metadata.
      capture();
      final before = c.source,
          bytes = const RawChkEncoder().encode(c.source.rawDocument),
          depth = h.maps.editHistory.undoDepth;
      final p = c.mixedClipboard.previewPaste(x: 16, y: 16);
      expect(c.source, same(before));
      expect(h.maps.editHistory.undoDepth, depth);
      expect(
        c.mixedClipboard.applyPreview(p),
        isFalse,
      ); // Same tiles and no objects.
      expect(h.maps.editHistory.undoDepth, depth);
      expect(() => c.mixedClipboard.applyPreview(p), throwsStateError);
      c.apply(
        c.source.rawDocument,
        mixedPut(c.source.rawDocument, 'THG2', [
          130,
          0,
          32,
          0,
          32,
          0,
          0,
          0,
          0,
          16,
        ]),
        'Sprite',
      );
      capture();
      final captured = c.source,
          original = const RawChkEncoder().encode(c.source.rawDocument);
      final paste = c.mixedClipboard.previewPaste(x: 16, y: 16);
      expect(c.source, same(captured));
      expect(paste.changedSections, 1);
      expect(c.mixedClipboard.applyPreview(paste), isTrue);
      expect(h.maps.editHistory.undoDepth, depth + 2);
      final after = const RawChkEncoder().encode(c.source.rawDocument);
      expect(h.maps.editHistory.undo(), isTrue);
      expect(const RawChkEncoder().encode(c.source.rawDocument), original);
      expect(h.maps.editHistory.redo(), isTrue);
      expect(const RawChkEncoder().encode(c.source.rawDocument), after);
      expect(c.mixedClipboard.clipboard, isNotNull);
      final repeat = c.mixedClipboard.previewPaste(x: 8, y: 16);
      h.maps.editHistory.undo();
      expect(() => c.mixedClipboard.applyPreview(repeat), throwsStateError);
      expect(bytes, isNotEmpty);
    },
  );
  test(
    'cut preview and locks/visibility/fog transaction never partially apply',
    () {
      c.apply(
        c.source.rawDocument,
        mixedPut(c.source.rawDocument, 'THG2', [
          130,
          0,
          32,
          0,
          32,
          0,
          0,
          0,
          0,
          16,
        ]),
        'Sprite',
      );
      capture();
      final p = c.mixedClipboard.previewCut(rawReplacement: 1),
          before = c.source;
      layers.setLocked(MapLayerType.sprites, true);
      expect(() => c.mixedClipboard.applyPreview(p), throwsStateError);
      expect(c.source, same(before));
      layers.setLocked(MapLayerType.sprites, false);
      c.beginFogStroke();
      expect(() => c.mixedClipboard.applyPreview(p), throwsStateError);
      c.cancelFogStroke();
      expect(c.mixedClipboard.applyPreview(p), isTrue);
      expect(c.source.objectViews.spriteSections.single.sprites, isEmpty);
      h.maps.editHistory.undo();
      expect(c.source, same(before));
      layers.setVisible(MapLayerType.terrain, false);
      expect(capture, throwsStateError);
    },
  );
  test(
    'map replacement clears usability and raw copy does not fabricate assets',
    () {
      capture();
      final p = c.mixedClipboard.previewPaste(x: 8, y: 8);
      h.maps.createNew(
        NewMapOptions(width: 32, height: 32, rawTileValue: 1),
        expectedSession: c.source,
      );
      expect(c.mixedClipboard.clipboard, isNull);
      expect(() => c.mixedClipboard.applyPreview(p), throwsStateError);
      expect(c.mixedClipboard.hasData, isFalse);
    },
  );
  test(
    'mixed composite apply is one Undo and late metadata cannot authorize a changed document',
    () async {
      c.apply(c.source.rawDocument, mixedDocument(), 'Fixture');
      final gateway = MixedDoodadGateway();
      final loader = IsomFillController(
        maps: h.maps,
        assets: () => h.assets,
        gateway: SolidSnapshotGateway(),
        placementGateway: gateway,
      );
      await c.mixedClipboard.load(loader);
      c.mixedClipboard.capture(
        region: ClipboardRegion(0, 0, 7, 5),
        profile: MixedClipboardProfile.raw,
        kinds: {'DD2 ', 'UNIT', 'THG2', 'MRGN'},
        overlays: {0: 2, 1: 1},
      );
      final before = c.source,
          bytes = const RawChkEncoder().encode(c.source.rawDocument),
          depth = h.maps.editHistory.undoDepth;
      final p = c.mixedClipboard.previewPaste(x: 16, y: 16);
      expect(c.source, same(before));
      expect(h.maps.editHistory.undoDepth, depth);
      expect(c.mixedClipboard.applyPreview(p), isTrue);
      expect(h.maps.editHistory.undoDepth, depth + 1);
      expect(c.source.objectViews.doodadSections.single.doodads.length, 4);
      h.maps.editHistory.undo();
      expect(const RawChkEncoder().encode(c.source.rawDocument), bytes);
      final cut = c.mixedClipboard.previewCut(rawReplacement: 1);
      expect(c.mixedClipboard.applyPreview(cut), isTrue);
      expect(c.source.objectViews.doodadSections.single.doodads, isEmpty);
      h.maps.editHistory.undo();
      expect(c.source, same(before));
      gateway.beforeReturn = () async {
        c.setStartLocation(player: 0, x: 64, y: 64);
      };
      await expectLater(c.mixedClipboard.load(loader), throwsStateError);
      expect(c.mixedClipboard.clipboard, isNull);
    },
  );
  test(
    'ISOM catalog survives same-document edits; asset change invalidates captured payload',
    () async {
      final loader = IsomFillController(
        maps: h.maps,
        assets: () => h.assets,
        gateway: SolidSnapshotGateway(),
        placementGateway: IsomRampGateway(),
      );
      await loader.load();
      loader.apply(loader.preview(terrainType: 2));
      await c.mixedClipboard.load(loader);
      c.mixedClipboard.capture(
        region: ClipboardRegion(0, 0, 7, 5),
        profile: MixedClipboardProfile.isom,
        kinds: {},
        overlays: {},
      );
      final p = c.mixedClipboard.previewPaste(x: 16, y: 16);
      expect(c.mixedClipboard.applyPreview(p), isFalse);
      c.setStartLocation(player: 0, x: 64, y: 64);
      expect(c.mixedClipboard.hasData, isTrue);
      expect(c.mixedClipboard.previewPaste(x: 16, y: 16).changedSections, 0);
      h.assets = StarCraftDataAssetSettingsState(
        status: StarCraftDataAssetSettingsStatus.ready,
        configuredPath: r'C:\Other',
      );
      expect(c.mixedClipboard.hasData, isFalse);
      expect(c.mixedClipboard.clipboard, isNull);
    },
  );
}
