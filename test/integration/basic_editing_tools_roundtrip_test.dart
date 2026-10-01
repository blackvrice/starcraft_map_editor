import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/documents/save_map_controller.dart';
import 'package:starcraft_map_editor/application/editing/basic_editing_controller.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/terrain/terrain_editing_controller.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_save_file_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';
import '../fixtures/basic_editing_fixture.dart';
import '../fixtures/new_map_harness.dart';

void main() {
  final helper = Platform.environment['MAP_ARCHIVE_HELPER_PATH'];
  test(
    'basic edits, linked clipboard and fog save/reopen byte-exactly without changing source MPQ',
    () async {
      final root = await Directory.systemTemp.createTemp('basic_tools_');
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
      final doc = basicDocument(
        units: [
          basicUnit(type: 134, id: 1, x: 128, y: 128),
          basicUnit(type: 134, id: 2, x: 192, y: 128),
        ],
      );
      final input = '${root.path}/원본.scx';
      expect(
        (await gateway.writeTemporary(
          MapArchiveWriteRequest(
            operationId: 'basic-fixture',
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
      final before = maps.state.session!;
      editing.fillFog(
        TerrainTileRegion.fromCorners(
          TerrainTileCoordinate(x: 1, y: 1),
          TerrainTileCoordinate(x: 3, y: 3),
        ),
        player: 4,
        hidden: false,
      );
      layers.setActiveLayer(MapLayerType.units);
      layers.selectAt(session: editing.source, pixelX: 128, pixelY: 128);
      layers.selectAt(
        session: editing.source,
        pixelX: 192,
        pixelY: 128,
        additive: true,
      );
      editing.patchUnits(states: {1: true, 2: null, 16: true}, hitpoints: 50);
      editing.linkUnits(addon: false);
      editing.copyObjects();
      editing.pasteObjects(x: 512, y: 512);
      editing.setStartLocation(player: 0, x: 256, y: 256);
      editing.setLocationElevation(63, 9);
      final expected = const RawChkEncoder().encode(editing.source.rawDocument),
          depth = maps.editHistory.undoDepth;
      for (var i = 0; i < depth; i++) {
        expect(maps.editHistory.undo(), isTrue);
      }
      expect(maps.state.session, same(before));
      for (var i = 0; i < depth; i++) {
        expect(maps.editHistory.redo(), isTrue);
      }
      expect(
        const RawChkEncoder().encode(editing.source.rawDocument),
        expected,
      );
      final output = '${root.path}/편집.scx';
      expect(
        (await save.saveAs(destinationPath: output)).status,
        SaveMapStatus.saved,
      );
      await maps.open(sourcePath: output);
      expect(
        const RawChkEncoder().encode(maps.state.session!.rawDocument),
        expected,
      );
      expect(maps.state.session!.rawDocument.sections.last.payload, [
        255,
        0,
        17,
      ]);
      expect(await fingerprint.fingerprint(input), original);
      expect(editing.hasClipboard, isFalse);
    },
    skip: !Platform.isWindows || helper == null
        ? 'Requires MAP_ARCHIVE_HELPER_PATH on Windows.'
        : false,
  );
}
