import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/documents/save_map_controller.dart';
import 'package:starcraft_map_editor/application/documents/isom_fill_controller.dart';
import 'package:starcraft_map_editor/application/editing/basic_editing_controller.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/settings/starcraft_data_asset_settings_controller.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/application/terrain/transition_isom_catalog_builder.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/chk_mixed_clipboard.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_fill.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_save_file_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';
import '../fixtures/basic_editing_fixture.dart';
import '../fixtures/mixed_clipboard_fixture.dart';
import '../fixtures/new_map_harness.dart';
import '../fixtures/solid_isom_fixture.dart';

void main() {
  final helper = Platform.environment['MAP_ARCHIVE_HELPER_PATH'];
  for (final profile in MixedClipboardProfile.values) {
    test(
      'mixed ${profile.name} clipboard cut/paste/Undo SaveAs/reopen preserves original MPQ and exact CHK',
      () async {
        final root = await Directory.systemTemp.createTemp('mixed_clipboard_');
        addTearDown(() => root.delete(recursive: true));
        final gateway = ProcessMapArchiveGateway(helperExecutablePath: helper!);
        final picker = NewMapPicker(),
            fingerprint = LocalMapFileFingerprintGateway(),
            progress = OperationProgressController();
        addTearDown(progress.dispose);
        final maps = OpenMapController(
          archiveGateway: gateway,
          filePicker: picker,
          fingerprintGateway: fingerprint,
          recentProjectsService: RecentProjectsService(InMemorySettingsStore()),
          operationProgressController: progress,
        );
        addTearDown(maps.dispose);
        final save = SaveMapController(
          archiveGateway: gateway,
          filePicker: picker,
          fingerprintGateway: fingerprint,
          saveFileGateway: LocalMapSaveFileGateway(),
          openMapController: maps,
          operationProgressController: progress,
        );
        addTearDown(save.dispose);
        final layers = MapLayerController();
        addTearDown(layers.dispose);
        final editing = BasicEditingController(maps: maps, layers: layers);
        addTearDown(editing.dispose);
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
        final input = '${root.path}/원본.scx', doc = mixedDocument(base: base);
        expect(
          (await gateway.writeTemporary(
            MapArchiveWriteRequest(
              operationId: 'mixed-fixture',
              sourcePath: null,
              temporaryOutputPath: input,
              scenarioChkBytes: const RawChkEncoder().encode(doc),
              timeout: const Duration(seconds: 30),
            ),
          )).isSuccess,
          isTrue,
        );
        final original = await fingerprint.fingerprint(input);
        await maps.open(sourcePath: input);
        layers.synchronizeSession(maps.state.session);
        final before = maps.state.session!,
            bytes = const RawChkEncoder().encode(before.rawDocument);
        // Settings identity must be stable for the full load/preview lifetime.
        final settings = StarCraftDataAssetSettingsState(
          status: StarCraftDataAssetSettingsStatus.ready,
          configuredPath: r'C:\Synthetic',
        );
        final stable = IsomFillController(
          maps: maps,
          assets: () => settings,
          gateway: SolidSnapshotGateway(),
          placementGateway: MixedDoodadGateway(),
        );
        await editing.mixedClipboard.load(stable);
        editing.mixedClipboard.capture(
          region: ClipboardRegion(0, 0, 7, 5),
          profile: profile,
          kinds: {'DD2 ', 'UNIT', 'THG2', 'MRGN'},
          overlays: {0: 2, 1: 1},
        );
        expect(
          editing.mixedClipboard.applyPreview(
            editing.mixedClipboard.previewCut(rawReplacement: 1, fillShape: 1),
          ),
          isTrue,
        );
        expect(
          editing.mixedClipboard.applyPreview(
            editing.mixedClipboard.previewPaste(x: 16, y: 16),
          ),
          isTrue,
        );
        final expected = const RawChkEncoder().encode(
          editing.source.rawDocument,
        );
        expect(maps.editHistory.undoDepth, 2);
        maps.editHistory.undo();
        maps.editHistory.undo();
        expect(const RawChkEncoder().encode(editing.source.rawDocument), bytes);
        maps.editHistory.redo();
        maps.editHistory.redo();
        expect(
          const RawChkEncoder().encode(editing.source.rawDocument),
          expected,
        );
        final output = '${root.path}/복사.scx';
        expect(
          (await save.saveAs(destinationPath: output)).status,
          SaveMapStatus.saved,
        );
        await maps.open(sourcePath: output);
        expect(
          const RawChkEncoder().encode(maps.state.session!.rawDocument),
          expected,
        );
        expect(await fingerprint.fingerprint(input), original);
        expect(editing.mixedClipboard.clipboard, isNull);
      },
      skip: !Platform.isWindows || helper == null
          ? 'Requires MAP_ARCHIVE_HELPER_PATH on Windows.'
          : false,
    );
  }
}
