import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/autosave_controller.dart';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/documents/opened_map_session.dart';
import 'package:starcraft_map_editor/application/documents/save_map_controller.dart';
import 'package:starcraft_map_editor/application/eud/eud_source_controller.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_save_file_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_recovery_store.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';

import '../fixtures/eud_project_workspace_fixture.dart';
import '../fixtures/new_map_harness.dart';
import '../fixtures/pcm_sound_fixture.dart';

void main() {
  final helper = Platform.environment['MAP_ARCHIVE_HELPER_PATH'];
  test(
    'checkpoint restart restores edited MPQ and WAVs, Save As preserves input bytes',
    () async {
      final root = await Directory.systemTemp.createTemp('autosave_roundtrip_');
      addTearDown(() => root.delete(recursive: true));
      final gateway = ProcessMapArchiveGateway(helperExecutablePath: helper!);
      final fingerprint = LocalMapFileFingerprintGateway();
      final picker = NewMapPicker();
      final fixtures = <EudWorkspaceFixture>[];
      final sources = <EudSourceController>[];
      final progressControllers = <OperationProgressController>[];
      OpenMapController maps() {
        final progress = OperationProgressController();
        progressControllers.add(progress);
        return OpenMapController(
          archiveGateway: gateway,
          filePicker: picker,
          fingerprintGateway: fingerprint,
          recentProjectsService: RecentProjectsService(InMemorySettingsStore()),
          operationProgressController: progress,
        );
      }

      AutosaveController autosave(OpenMapController maps, String owner) {
        final f = EudWorkspaceFixture(), s = EudSourceController();
        fixtures.add(f);
        sources.add(s);
        return AutosaveController(
          maps: maps,
          sources: s,
          projects: f.projects,
          store: LocalRecoveryStore(Directory('${root.path}/recovery')),
          settings: InMemorySettingsStore(),
          ownerId: owner,
        );
      }

      SaveMapController save(OpenMapController maps) => SaveMapController(
        archiveGateway: gateway,
        filePicker: picker,
        fingerprintGateway: fingerprint,
        saveFileGateway: LocalMapSaveFileGateway(),
        openMapController: maps,
        operationProgressController: maps.operationProgressController,
      );
      addTearDown(() async {
        for (final f in fixtures) {
          f.dispose();
        }
        for (final s in sources) {
          s.dispose();
        }
        for (final p in progressControllers) {
          await p.dispose();
        }
      });
      final first = maps(), firstSave = save(first);
      addTearDown(first.dispose);
      addTearDown(firstSave.dispose);
      first.createNew(
        NewMapOptions(rawTileValue: 0, width: 32, height: 32),
        expectedSession: null,
      );
      final base = '${root.path}/base.scx';
      expect(
        (await firstSave.saveAs(destinationPath: base)).status,
        SaveMapStatus.saved,
      );
      final originalBytes = await File(base).readAsBytes();
      final session = first.state.session!;
      var doc = session.rawDocument;
      final tileIndex = doc.sections.indexWhere((s) => s.name == 'MTXM');
      final tile = doc.sections[tileIndex].payload..[0] = 1;
      doc = doc.replaceSection(
        tileIndex,
        doc.sections[tileIndex].withPayload(tile),
      );
      for (var i = 0; i < 2; i++) {
        doc = doc.appendSection(
          RawChkSection(
            nameBytes: 'TEST'.codeUnits,
            declaredLength: 2,
            payload: [255, i],
            sourceOffset: 0,
            isDirty: true,
          ),
        );
      }
      first.adoptEditedSession(
        OpenedMapSession(
          extractedMap: session.extractedMap,
          rawDocument: doc,
          metadataViews: session.metadataViews,
          stringViews: session.stringViews,
          terrainViews: session.terrainViews,
          objectViews: session.objectViews,
          sourceFingerprint: session.sourceFingerprint,
          diagnostics: session.diagnostics,
          resourceEdits: {r'staredit\wav\recover.wav': pcmSoundFixture()},
        ),
      );
      final checkpoint = autosave(first, 'first');
      await checkpoint.checkpoint();
      expect(checkpoint.lastError, isNull);
      await checkpoint.dispose();
      final second = maps(),
          secondSave = save(second),
          restarted = autosave(second, 'second');
      addTearDown(second.dispose);
      addTearDown(secondSave.dispose);
      addTearDown(restarted.dispose);
      await restarted.refresh();
      await restarted.restore(restarted.candidates.single.id);
      expect(second.state.session!.isDirty, isTrue);
      expect(
        const RawChkEncoder().encode(second.state.session!.rawDocument),
        const RawChkEncoder().encode(doc),
      );
      final destination = '${root.path}/recovered.scx';
      expect(
        (await secondSave.saveAs(destinationPath: destination)).status,
        SaveMapStatus.saved,
      );
      expect(
        await gateway.readResource(destination, r'staredit\wav\recover.wav'),
        pcmSoundFixture(),
      );
      expect(await File(base).readAsBytes(), originalBytes);
      await second.open(sourcePath: destination);
      expect(
        const RawChkEncoder().encode(second.state.session!.rawDocument),
        const RawChkEncoder().encode(doc),
      );
      await restarted.checkpoint();
      await restarted.refresh();
      expect(restarted.candidates, isEmpty);
    },
    skip: !Platform.isWindows || helper == null
        ? 'Requires MAP_ARCHIVE_HELPER_PATH on Windows.'
        : false,
  );
}
