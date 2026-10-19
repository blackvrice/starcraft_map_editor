import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/documents/opened_map_session.dart';
import 'package:starcraft_map_editor/application/documents/save_map_controller.dart';
import 'package:starcraft_map_editor/application/editing/object_editing_controller.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_save_file_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';
import '../fixtures/doodad_deletion_fixture.dart';
import '../fixtures/new_map_harness.dart';

void main() {
  final helper = Platform.environment['MAP_ARCHIVE_HELPER_PATH'];
  for (final mode in ['single', 'batch', 'mixed']) {
    final batch = mode != 'single', mixed = mode == 'mixed';
    for (final overlay in [null, ...DoodadOverlaySemantic.values]) {
      test(
        'Doodad $overlay mode=$mode delete survives real MPQ Save As/reopen and preserves original',
        () async {
          final root = await Directory.systemTemp.createTemp(
            'doodad_delete_roundtrip_',
          );
          addTearDown(() => root.delete(recursive: true));
          final archive = ProcessMapArchiveGateway(
            helperExecutablePath: helper!,
          );
          final fingerprint = LocalMapFileFingerprintGateway(),
              picker = NewMapPicker(),
              progress = OperationProgressController();
          final maps = OpenMapController(
            archiveGateway: archive,
            filePicker: picker,
            fingerprintGateway: fingerprint,
            recentProjectsService: RecentProjectsService(
              InMemorySettingsStore(),
            ),
            operationProgressController: progress,
          );
          addTearDown(maps.dispose);
          addTearDown(progress.dispose);
          final save = SaveMapController(
            archiveGateway: archive,
            filePicker: picker,
            fingerprintGateway: fingerprint,
            saveFileGateway: LocalMapSaveFileGateway(),
            openMapController: maps,
            operationProgressController: progress,
          );
          addTearDown(save.dispose);
          final doc = batch
                  ? batchDeletionDocument(overlay: overlay)
                  : deletionDocument(overlay: overlay),
              before = const RawChkEncoder().encode(doc);
          maps.adoptRecoverySession(
            OpenedMapSession(
              extractedMap: ExtractedMap.inMemory(scenarioChkBytes: before),
              rawDocument: doc,
              metadataViews: const ChkMetadataViewDecoder().decode(doc),
              stringViews: const ChkStringViewDecoder().decode(doc),
              terrainViews: const ChkTerrainViewDecoder().decode(doc),
              objectViews: const ChkObjectViewDecoder().decode(doc),
              sourceFingerprint: null,
              diagnostics: const [],
            ),
          );
          final input = '${root.path}/original.scx',
              output = '${root.path}/deleted.scx';
          expect(
            (await save.saveAs(destinationPath: input)).status,
            SaveMapStatus.saved,
          );
          final original = await File(input).readAsBytes();
          await maps.open(sourcePath: input);
          final layers = MapLayerController()
            ..synchronizeSession(maps.state.session);
          final editing = ObjectEditingController(
            openMapController: maps,
            mapLayerController: layers,
          );
          addTearDown(layers.dispose);
          addTearDown(editing.dispose);
          final plan = batch
              ? editing.prepareDoodadDeletions(
                  batchDeletionRequests(overlay: overlay),
                  selectedSpriteRecordIndices: mixed ? [0, 1] : const [],
                )
              : editing.prepareDoodadDeletion(
                  recipe: deletionRecipe(overlay: overlay),
                  recordIndex: 0,
                  overlayRecordIndex: overlay == null ? null : 1,
                );
          editing.deleteDoodad(plan);
          expect(maps.editHistory.undoDepth, 1);
          final after = const RawChkEncoder().encode(
            maps.state.session!.rawDocument,
          );
          expect(editing.undo(), isTrue);
          expect(
            const RawChkEncoder().encode(maps.state.session!.rawDocument),
            before,
          );
          expect(editing.redo(), isTrue);
          expect(
            const RawChkEncoder().encode(maps.state.session!.rawDocument),
            after,
          );
          expect(
            (await save.saveAs(destinationPath: output)).status,
            SaveMapStatus.saved,
          );
          expect(await File(input).readAsBytes(), original);
          expect(
            (await maps.open(sourcePath: output)).status,
            OpenMapStatus.opened,
          );
          expect(
            const RawChkEncoder().encode(maps.state.session!.rawDocument),
            after,
          );
          expect(
            maps.state.session!.objectViews.doodadSections.single.doodads,
            hasLength(1),
          );
          expect(
            maps.state.session!.objectViews.spriteSections.single.sprites,
            hasLength(
              mixed
                  ? 1
                  : overlay == null
                  ? 3
                  : 2,
            ),
          );
        },
        skip: !Platform.isWindows || helper == null
            ? 'Requires MAP_ARCHIVE_HELPER_PATH on Windows.'
            : false,
      );
    }
  }
}
