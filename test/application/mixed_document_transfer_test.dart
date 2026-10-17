import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/isom_fill_controller.dart';
import 'package:starcraft_map_editor/application/settings/starcraft_data_asset_settings_controller.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/chk_mixed_clipboard.dart';
import '../fixtures/basic_editing_fixture.dart';
import '../fixtures/document_transfer_fixture.dart';
import '../fixtures/mixed_clipboard_fixture.dart';
import '../fixtures/multi_map_fixture.dart';
import '../fixtures/solid_isom_fixture.dart';

void main() {
  late MultiMapFixture f;
  setUp(() => f = MultiMapFixture());
  tearDown(() => f.dispose());
  test(
    'asset revision changes and controller disposal reject captured mixed data',
    () async {
      final a = f.addMap(), b = f.addMap();
      adoptTransferDocument(a.maps, mixedDocument());
      final c = mixedTransferController(f, a, b);
      var settings = StarCraftDataAssetSettingsState(
        status: StarCraftDataAssetSettingsStatus.ready,
        configuredPath: r'C:\Synthetic',
      );
      await c.mixedClipboard.load(
        IsomFillController(
          maps: a.maps,
          assets: () => settings,
          gateway: SolidSnapshotGateway(),
          placementGateway: MixedDoodadGateway(),
        ),
      );
      c.mixedClipboard.capture(
        region: ClipboardRegion(0, 0, 7, 5),
        profile: MixedClipboardProfile.raw,
        kinds: {'UNIT', 'DD2 ', 'THG2', 'MRGN'},
        overlays: {0: 2, 1: 1},
      );
      final preview = c.mixedClipboard.previewPaste(x: 16, y: 16);
      settings = StarCraftDataAssetSettingsState(
        status: StarCraftDataAssetSettingsStatus.ready,
        configuredPath: r'C:\Other',
      );
      expect(c.mixedClipboard.clipboard, isNull);
      expect(() => c.mixedClipboard.applyPreview(preview), throwsStateError);
      await c.dispose();
      expect(
        () => c.mixedClipboard.capture(
          region: ClipboardRegion(0, 0, 1, 1),
          profile: MixedClipboardProfile.raw,
          kinds: {},
          overlays: {},
        ),
        throwsStateError,
      );
    },
  );
  test(
    'cross-map mixed preview and one target Undo leave the source and its history unchanged',
    () async {
      final a = f.addMap(), b = f.addMap();
      adoptTransferDocument(a.maps, mixedDocument());
      final c = mixedTransferController(f, a, b);
      addTearDown(c.dispose);
      final settings = StarCraftDataAssetSettingsState(
        status: StarCraftDataAssetSettingsStatus.ready,
        configuredPath: r'C:\Synthetic',
      );
      await c.mixedClipboard.load(
        IsomFillController(
          maps: a.maps,
          assets: () => settings,
          gateway: SolidSnapshotGateway(),
          placementGateway: MixedDoodadGateway(),
        ),
      );
      final source = a.maps.state.session!, target = b.maps.state.session!;
      c.mixedClipboard.capture(
        region: ClipboardRegion(0, 0, 7, 5),
        profile: MixedClipboardProfile.raw,
        kinds: {'UNIT', 'DD2 ', 'THG2', 'MRGN'},
        overlays: {0: 2, 1: 1},
      );
      final preview = c.mixedClipboard.previewPaste(x: 16, y: 16);
      expect(preview.session.extractedMap, same(target.extractedMap));
      expect(a.maps.state.session, same(source));
      expect(b.maps.state.session, same(target));
      expect(c.mixedClipboard.applyPreview(preview), isTrue);
      final after = const RawChkEncoder().encode(
        b.maps.state.session!.rawDocument,
      );
      expect(a.maps.editHistory.undoDepth, 0);
      expect(b.maps.editHistory.undoDepth, 1);
      expect(a.maps.state.session, same(source));
      b.maps.editHistory.undo();
      expect(
        const RawChkEncoder().encode(b.maps.state.session!.rawDocument),
        const RawChkEncoder().encode(target.rawDocument),
      );
      b.maps.editHistory.redo();
      expect(
        const RawChkEncoder().encode(b.maps.state.session!.rawDocument),
        after,
      );
      expect(
        () => c.mixedClipboard.previewCut(rawReplacement: 1),
        throwsStateError,
      );
    },
  );
  test(
    'source edits, target edits, either layer lock and document close invalidate mixed approval',
    () async {
      final a = f.addMap(), b = f.addMap();
      final tiles = basicData(a.maps.state.session!.rawDocument, 'MTXM')
        ..setUint16(0, 9, Endian.little);
      adoptTransferDocument(
        a.maps,
        mixedPut(
          a.maps.state.session!.rawDocument,
          'MTXM',
          tiles.buffer.asUint8List(),
        ),
      );
      final c = mixedTransferController(f, a, b);
      addTearDown(c.dispose);
      void capture() => c.mixedClipboard.capture(
        region: ClipboardRegion(0, 0, 1, 1),
        profile: MixedClipboardProfile.raw,
        kinds: {},
        overlays: {},
      );
      capture();
      var preview = c.mixedClipboard.previewPaste(x: 16, y: 16);
      b.value.mapLayerController.setLocked(MapLayerType.terrain, true);
      expect(() => c.mixedClipboard.applyPreview(preview), throwsStateError);
      b.value.mapLayerController.setLocked(MapLayerType.terrain, false);
      preview = c.mixedClipboard.previewPaste(x: 16, y: 16);
      adoptTransferDocument(b.maps, b.maps.state.session!.rawDocument);
      expect(() => c.mixedClipboard.applyPreview(preview), throwsStateError);
      preview = c.mixedClipboard.previewPaste(x: 16, y: 16);
      adoptTransferDocument(a.maps, a.maps.state.session!.rawDocument);
      expect(c.mixedClipboard.clipboard, isNull);
      expect(() => c.mixedClipboard.applyPreview(preview), throwsStateError);
      capture();
      preview = c.mixedClipboard.previewPaste(x: 16, y: 16);
      await f.workspace.close(
        a,
        expectedRevision: a.revision,
        discardChanges: true,
      );
      expect(() => c.mixedClipboard.applyPreview(preview), throwsStateError);
      expect(b.maps.editHistory.undoDepth, 0);
    },
  );
}
