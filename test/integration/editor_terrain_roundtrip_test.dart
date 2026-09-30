import 'package:starcraft_map_editor/application/terrain/terrain_editing_controller.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import '../fixtures/editor_terrain_fixture.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/documents/save_map_controller.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_save_file_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';
import '../fixtures/new_map_harness.dart';

void main() {
  final helper = Platform.environment['MAP_ARCHIVE_HELPER_PATH'];
  test(
    'inspect and raw edit preserve TILE/ISOM and original MPQ through Save As',
    () async {
      final root = await Directory.systemTemp.createTemp('editor_terrain_');
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

      final doc = const NewMapFactory()
          .create(NewMapOptions(width: 32, height: 32, rawTileValue: 32))
          .appendSection(
            part('ISOM', List.generate(17 * 33 * 8, (i) => i % 256)),
          );
      final input = '${root.path}/source.scx';
      final created = await gateway.writeTemporary(
        MapArchiveWriteRequest(
          operationId: 'terrain-inspection-fixture',
          sourcePath: null,
          temporaryOutputPath: input,
          scenarioChkBytes: const RawChkEncoder().encode(doc),
          timeout: const Duration(seconds: 30),
        ),
      );
      expect(created.isSuccess, isTrue);
      final original = await fingerprint.fingerprint(input);
      expect((await maps.open(sourcePath: input)).status, OpenMapStatus.opened);
      final before = maps.state.session!;
      expect(before.editorTerrain.differentTileCount, 0);
      expect(before.isDirty, isFalse);
      final terrain = TerrainEditingController(openMapController: maps);
      addTearDown(terrain.dispose);
      terrain.selectCatalogTile(33);
      terrain.paintTiles([const TerrainTileCoordinate(x: 0, y: 0)]);
      expect(maps.state.session!.editorTerrain.differentTileCount, 1);
      final output = '${root.path}/edited.scx';
      expect(
        (await save.saveAs(destinationPath: output)).status,
        SaveMapStatus.saved,
      );
      await maps.open(sourcePath: output);
      for (final name in ['TILE', 'ISOM']) {
        expect(
          maps.state.session!.rawDocument.sections
              .singleWhere((s) => s.name == name)
              .payload,
          doc.sections.singleWhere((s) => s.name == name).payload,
        );
      }
      expect(maps.state.session!.editorTerrain.differentTileCount, 1);
      expect(await fingerprint.fingerprint(input), original);
    },
    skip: !Platform.isWindows || helper == null
        ? 'Requires MAP_ARCHIVE_HELPER_PATH on Windows.'
        : false,
  );
}
