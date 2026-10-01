import 'package:starcraft_map_editor/application/documents/isom_fill_controller.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';
import 'package:starcraft_map_editor/application/settings/starcraft_data_asset_settings_controller.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_terrain_connection_snapshot_gateway.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/documents/save_map_controller.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_save_file_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';
import '../fixtures/new_map_harness.dart';

void main() {
  final helper = Platform.environment['MAP_ARCHIVE_HELPER_PATH'];
  final dataHelper = Platform.environment['STARCRAFT_DATA_HELPER_PATH'];
  final install = Platform.environment['STARCRAFT_TEST_INSTALLATION'];
  test(
    'local boundary and ramp edits save/reopen byte-exactly and preserve source MPQ',
    () async {
      final root = await Directory.systemTemp.createTemp('isom_conversion_');
      addTearDown(() => root.delete(recursive: true));
      final gateway = ProcessMapArchiveGateway(helperExecutablePath: helper!);
      final picker = NewMapPicker();
      final fingerprint = LocalMapFileFingerprintGateway();
      final progress = OperationProgressController();
      addTearDown(progress.dispose);
      final recent = RecentProjectsService(InMemorySettingsStore());
      final maps = OpenMapController(
        archiveGateway: gateway,
        filePicker: picker,
        fingerprintGateway: fingerprint,
        recentProjectsService: recent,
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

      final doc = const NewMapFactory().create(
        NewMapOptions(width: 32, height: 32, rawTileValue: 0),
      );
      final input = '${root.path}/source.scx';
      expect(
        (await gateway.writeTemporary(
          MapArchiveWriteRequest(
            operationId: 'isom-fixture',
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
      final settings = StarCraftDataAssetSettingsState(
        status: StarCraftDataAssetSettingsStatus.ready,
        configuredPath: install!,
      );
      final controller = IsomFillController(
        maps: maps,
        assets: () => settings,
        placementGateway: ProcessStarCraftPlacementCatalogGateway(
          helperExecutablePath: dataHelper!,
        ),
        gateway: ProcessTerrainConnectionSnapshotGateway(
          helperExecutablePath: dataHelper,
        ),
      );
      await controller.load();
      final preview = controller.preview(terrainType: 2);
      expect(preview.changedTileCount, 1024);
      controller.apply(preview);
      await controller.load();
      final beforeBrush = maps.state.session!;
      var painted = controller.previewPaint(
        terrainType: 3,
        diamonds: {
          for (var y = 8; y <= 20; y++)
            for (var x = 4 + (y & 1); x <= 12; x += 2) (x, y),
        },
      );
      painted = controller.previewPaint(
        terrainType: 2,
        diamonds: {(8, 14)},
        basePreview: painted,
      );
      expect(maps.state.session, same(beforeBrush));
      controller.apply(painted);
      await controller.load();
      final beforeRamp = maps.state.session!;
      final tiles = controller.previewTerrain(null).rawTileValues;
      (DoodadPlacementRecipe, int, int)? target;
      for (final r in controller.ramps) {
        for (var y = 0; y <= 32 - r.height && target == null; y++) {
          for (var x = 0; x <= 32 - r.width && target == null; x++) {
            if (r.footprint.every(
              (cell) =>
                  cell.requiredTileGroup == 0 ||
                  tiles[(y + cell.y) * 32 + x + cell.x] >> 4 ==
                      cell.requiredTileGroup,
            )) {
              target = (r, x, y);
            }
          }
        }
        if (target != null) break;
      }
      expect(target, isNotNull);
      final ramp = controller.previewRamp(
        recipe: target!.$1,
        x: target.$2,
        y: target.$3,
      );
      controller.apply(ramp);
      final afterRamp = maps.state.session!;
      expect(afterRamp.objectViews.doodadSections.single.doodads.length, 1);
      expect(
        afterRamp.rawDocument.sections.singleWhere((s) => s.name == 'ISOM'),
        same(
          beforeRamp.rawDocument.sections.singleWhere((s) => s.name == 'ISOM'),
        ),
      );
      maps.editHistory.undo();
      expect(maps.state.session, same(beforeRamp));
      maps.editHistory.redo();
      expect(maps.state.session, same(afterRamp));
      final expected = const RawChkEncoder().encode(
        maps.state.session!.rawDocument,
      );
      maps.editHistory.undo();
      expect(maps.state.session, same(beforeRamp));
      maps.editHistory.redo();
      final output = '${root.path}/converted.scx';
      expect(
        (await save.saveAs(destinationPath: output)).status,
        SaveMapStatus.saved,
      );
      await maps.open(sourcePath: output);
      expect(
        const RawChkEncoder().encode(maps.state.session!.rawDocument),
        expected,
      );
      final isom = maps.state.session!.rawDocument.sections.singleWhere(
        (s) => s.name == 'ISOM',
      );
      expect(
        isom.payload,
        afterRamp.rawDocument.sections
            .singleWhere((s) => s.name == 'ISOM')
            .payload,
      );
      expect(
        maps.state.session!.editorTerrain.differentTileCount,
        greaterThan(0),
      );
      expect(await fingerprint.fingerprint(input), original);
    },
    skip:
        !Platform.isWindows ||
            helper == null ||
            dataHelper == null ||
            install == null
        ? 'Requires MAP_ARCHIVE_HELPER_PATH on Windows.'
        : false,
  );
}
