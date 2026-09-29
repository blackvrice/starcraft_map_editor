import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/documents/opened_map_session.dart';
import 'package:starcraft_map_editor/application/documents/save_map_controller.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_save_file_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';
import '../fixtures/new_map_harness.dart';
import '../fixtures/pcm_sound_fixture.dart';

void main() {
  final helper = Platform.environment['MAP_ARCHIVE_HELPER_PATH'];
  test(
    'new map creates native MPQ, saves sounds, reopens and protects existing output',
    () async {
      final root = await Directory.systemTemp.createTemp('new_map_roundtrip_');
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
      for (final tileset in ChkTileset.values) {
        final initial = maps
            .createNew(
              NewMapOptions(
                rawTileValue: 32,
                width: 32,
                height: 64,
                tileset: tileset,
                humanPlayers: 8,
                title: '새 맵 ${tileset.name}',
              ),
              expectedSession: maps.state.session,
            )
            .session!;
        final bytes = const RawChkEncoder().encode(initial.rawDocument);
        final sound = pcmSoundFixture();
        const path = r'staredit\wav\new.wav';
        maps.adoptEditedSession(
          OpenedMapSession(
            extractedMap: initial.extractedMap,
            rawDocument: initial.rawDocument,
            metadataViews: initial.metadataViews,
            stringViews: initial.stringViews,
            terrainViews: initial.terrainViews,
            objectViews: initial.objectViews,
            sourceFingerprint: null,
            diagnostics: initial.diagnostics,
            resourceEdits: {path: sound},
          ),
        );
        final unsaved = maps.state.session!;
        // Cancelling Save As must not invent a source or remove pending resources.
        await save.saveAs();
        expect(maps.state.session, same(unsaved));
        final destination = '${root.path}/새 맵 ${tileset.name}.scx';
        final result = await save.saveAs(destinationPath: destination);
        expect(
          result.status,
          SaveMapStatus.saved,
          reason:
              '${result.diagnostics.map((d) => '${d.code}: ${d.rawDetails}')}',
        );
        expect(maps.state.session!.isDirty, isFalse);
        expect(maps.state.session!.sourceFingerprint, isNotNull);
        expect(await gateway.readResource(destination, path), sound);
        final opened = await maps.open(sourcePath: destination);
        expect(opened.status, OpenMapStatus.opened);
        expect(
          const RawChkEncoder().encode(opened.session!.rawDocument),
          bytes,
        );
        final before = await File(destination).readAsBytes();
        final refused = await gateway.writeTemporary(
          MapArchiveWriteRequest(
            operationId: 'new-map-collision',
            sourcePath: null,
            temporaryOutputPath: destination,
            scenarioChkBytes: bytes,
            timeout: const Duration(seconds: 30),
          ),
        );
        expect(refused.isSuccess, isFalse);
        expect(await File(destination).readAsBytes(), before);
        final changed = maps
            .createNew(
              NewMapOptions(rawTileValue: 1),
              expectedSession: maps.state.session,
            )
            .session!;
        expect(
          (await save.saveAs(destinationPath: destination)).status,
          SaveMapStatus.failed,
        );
        expect(maps.state.session, same(changed));
        expect(await File(destination).readAsBytes(), before);
      }
    },
    skip: !Platform.isWindows || helper == null
        ? 'Requires MAP_ARCHIVE_HELPER_PATH on Windows.'
        : false,
  );
}
