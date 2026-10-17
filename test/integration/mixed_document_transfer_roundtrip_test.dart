import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/isom_fill_controller.dart';
import 'package:starcraft_map_editor/application/documents/save_map_controller.dart';
import 'package:starcraft_map_editor/application/settings/starcraft_data_asset_settings_controller.dart';
import 'package:starcraft_map_editor/application/terrain/transition_isom_catalog_builder.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/chk_mixed_clipboard.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_fill.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_save_file_gateway.dart';
import '../fixtures/basic_editing_fixture.dart';
import '../fixtures/document_transfer_fixture.dart';
import '../fixtures/mixed_clipboard_fixture.dart';
import '../fixtures/multi_map_fixture.dart';
import '../fixtures/solid_isom_fixture.dart';

void main() {
  final helper = Platform.environment['MAP_ARCHIVE_HELPER_PATH'];
  for (final profile in MixedClipboardProfile.values) {
    test(
      'cross-map ${profile.name} Doodad/overlay/terrain Undo SaveAs/reopen preserves two source MPQs',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'mixed_document_transfer_',
        );
        addTearDown(() => root.delete(recursive: true));
        final archive = ProcessMapArchiveGateway(helperExecutablePath: helper!),
            hashes = LocalMapFileFingerprintGateway();
        final f = MultiMapFixture(
          archive: archive,
          fingerprints: hashes,
          files: LocalMapSaveFileGateway(),
        );
        addTearDown(f.dispose);
        var base = basicDocument();
        if (profile == MixedClipboardProfile.isom) {
          base = const IsomTerrainFill()
              .preview(
                base,
                const TransitionIsomCatalogBuilder()
                    .build(solidSnapshot())
                    .catalog,
                solidValue: 16,
                seed: 0,
              )
              .result;
        }
        final a = f.addMap(), b = f.addMap();
        adoptTransferDocument(a.maps, mixedDocument(base: base));
        adoptTransferDocument(b.maps, base);
        final pathA = '${root.path}/원본A.scx',
            pathB = '${root.path}/원본B.scx',
            output = '${root.path}/혼합복사.scx';
        expect(
          (await a.saves.saveAs(destinationPath: pathA)).status,
          SaveMapStatus.saved,
        );
        expect(
          (await b.saves.saveAs(destinationPath: pathB)).status,
          SaveMapStatus.saved,
        );
        final hashA = await hashes.fingerprint(pathA),
            hashB = await hashes.fingerprint(pathB);
        final source = a.maps.state.session!,
            beforeB = const RawChkEncoder().encode(
              b.maps.state.session!.rawDocument,
            );
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
        c.mixedClipboard.capture(
          region: ClipboardRegion(0, 0, 7, 5),
          profile: profile,
          kinds: {'UNIT', 'THG2', 'DD2 ', 'MRGN'},
          overlays: {0: 2, 1: 1},
        );
        final preview = c.mixedClipboard.previewPaste(x: 16, y: 16);
        expect(c.mixedClipboard.applyPreview(preview), isTrue);
        final expected = const RawChkEncoder().encode(
          b.maps.state.session!.rawDocument,
        );
        b.maps.editHistory.undo();
        expect(
          const RawChkEncoder().encode(b.maps.state.session!.rawDocument),
          beforeB,
        );
        b.maps.editHistory.redo();
        expect(
          (await b.saves.saveAs(destinationPath: output)).status,
          SaveMapStatus.saved,
        );
        await f.workspace.close(
          b,
          expectedRevision: b.revision,
          discardChanges: true,
        );
        final reopened = (await f.workspace.open(path: output))!;
        expect(
          const RawChkEncoder().encode(
            reopened.maps.state.session!.rawDocument,
          ),
          expected,
        );
        expect(a.maps.state.session, same(source));
        expect(await hashes.fingerprint(pathA), hashA);
        expect(await hashes.fingerprint(pathB), hashB);
      },
      skip: !Platform.isWindows || helper == null
          ? 'Requires MAP_ARCHIVE_HELPER_PATH on Windows.'
          : false,
    );
  }
}
