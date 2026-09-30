import 'package:starcraft_map_editor/application/documents/isom_conversion_controller.dart';
import 'package:starcraft_map_editor/application/ports/isom_terrain_catalog_gateway.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_conversion.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import '../fixtures/isom_conversion_fixture.dart';
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
  test(
    'synthetic verified ISOM conversion saves both tile grids and preserves ISOM/source MPQ',
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

      final doc = isomFixture();
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
      final controller = IsomConversionController(
        maps: maps,
        catalogs: _Catalog(),
      );
      final preview = await controller.preview(seed: 0);
      expect(preview.changedTileCount, 1024);
      controller.apply(preview);
      final expected = const RawChkEncoder().encode(
        maps.state.session!.rawDocument,
      );
      maps.editHistory.undo();
      expect(maps.state.session!.isDirty, isFalse);
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
      expect(
        maps.state.session!.rawDocument.sections
            .singleWhere((s) => s.name == 'ISOM')
            .payload,
        doc.sections.singleWhere((s) => s.name == 'ISOM').payload,
      );
      expect(maps.state.session!.editorTerrain.differentTileCount, 0);
      expect(await fingerprint.fingerprint(input), original);
    },
    skip: !Platform.isWindows || helper == null
        ? 'Requires MAP_ARCHIVE_HELPER_PATH on Windows.'
        : false,
  );
}

class _Catalog implements IsomTerrainCatalogGateway {
  @override
  Future<IsomTerrainCatalog> load({required int tileset}) async =>
      isomCatalog();
}
