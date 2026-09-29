import 'package:starcraft_map_editor/application/documents/map_resize_controller.dart';
import 'package:starcraft_map_editor/domain/chk/map_resize.dart';
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
    'resize a saved MPQ, undo/redo and Save As without changing source',
    () async {
      final root = await Directory.systemTemp.createTemp('resize_roundtrip_');
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

      maps.createNew(
        NewMapOptions(width: 64, height: 64, rawTileValue: 32),
        expectedSession: null,
      );
      final input = '${root.path}/source.scx';
      expect(
        (await save.saveAs(destinationPath: input)).status,
        SaveMapStatus.saved,
      );
      final original = await fingerprint.fingerprint(input);
      final originalBytes = const RawChkEncoder().encode(
        maps.state.session!.rawDocument,
      );
      final resize = MapResizeController(maps);
      final preview = resize.preview(
        MapResizeOptions(
          width: 128,
          height: 96,
          anchor: MapResizeAnchor.bottomRight,
        ),
      );
      resize.apply(preview, acceptCropping: false);
      final expected = const RawChkEncoder().encode(
        maps.state.session!.rawDocument,
      );
      maps.editHistory.undo();
      expect(
        const RawChkEncoder().encode(maps.state.session!.rawDocument),
        originalBytes,
      );
      expect(maps.state.session!.isDirty, isFalse);
      maps.editHistory.redo();
      final output = '${root.path}/resized.scx';
      expect(
        (await save.saveAs(destinationPath: output)).status,
        SaveMapStatus.saved,
      );
      final reopened = await maps.open(sourcePath: output);
      expect(reopened.status, OpenMapStatus.opened);
      expect(
        const RawChkEncoder().encode(reopened.session!.rawDocument),
        expected,
      );
      expect(reopened.session!.terrainViews.tileMaps.single.width, 128);
      expect(reopened.session!.terrainViews.tileMaps.single.height, 96);
      expect(await fingerprint.fingerprint(input), original);
    },
    skip: !Platform.isWindows || helper == null
        ? 'Requires MAP_ARCHIVE_HELPER_PATH on Windows.'
        : false,
  );
}
