import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/save_map_controller.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_resource_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_save_file_gateway.dart';
import '../fixtures/document_transfer_fixture.dart';
import '../fixtures/multi_map_fixture.dart';
import '../fixtures/pcm_sound_fixture.dart';

void main() {
  final helper = Platform.environment['MAP_ARCHIVE_HELPER_PATH'];
  test(
    'cross-map ordinary trigger closure and PCM sound survive native SaveAs/reopen while original MPQ hashes stay unchanged',
    () async {
      final root = await Directory.systemTemp.createTemp('document_transfer_');
      addTearDown(() => root.delete(recursive: true));
      final archive = ProcessMapArchiveGateway(helperExecutablePath: helper!),
          hashes = LocalMapFileFingerprintGateway();
      final f = MultiMapFixture(
        archive: archive,
        fingerprints: hashes,
        files: LocalMapSaveFileGateway(),
        resourceGateway: LocalMapResourceGateway(archive),
      );
      addTearDown(f.dispose);
      final a = f.addMap(), b = f.addMap();
      adoptTransferDocument(
        a.maps,
        transferSource(),
        resources: {transferSoundPath: pcmSoundFixture()},
      );
      final originalA = '${root.path}/원본A.scx',
          originalB = '${root.path}/원본B.scx',
          output = '${root.path}/복사결과.scx';
      expect(
        (await a.saves.saveAs(destinationPath: originalA)).status,
        SaveMapStatus.saved,
      );
      expect(
        (await b.saves.saveAs(destinationPath: originalB)).status,
        SaveMapStatus.saved,
      );
      final hashA = await hashes.fingerprint(originalA),
          hashB = await hashes.fingerprint(originalB);
      final before = const RawChkEncoder().encode(
        b.maps.state.session!.rawDocument,
      );
      final controller = transferController(f);
      addTearDown(controller.dispose);
      final preview = await controller.prepare(
        source: a,
        target: b,
        selected: {
          'UNIT': {0, 1},
        },
        triggers: {0},
        briefings: {0},
        offsetX: 32,
      );
      controller.apply(preview);
      final expected = const RawChkEncoder().encode(
        b.maps.state.session!.rawDocument,
      );
      expect(b.maps.editHistory.undo(), isTrue);
      expect(
        const RawChkEncoder().encode(b.maps.state.session!.rawDocument),
        before,
      );
      expect(b.maps.state.session!.resourceEdits, isEmpty);
      expect(b.maps.editHistory.redo(), isTrue);
      expect(
        (await b.saves.saveAs(destinationPath: output)).status,
        SaveMapStatus.saved,
      );
      expect(
        await archive.readResource(output, transferSoundPath),
        pcmSoundFixture(),
      );
      expect(
        await f.workspace.close(
          b,
          expectedRevision: b.revision,
          discardChanges: true,
        ),
        isTrue,
      );
      final reopened = (await f.workspace.open(path: output))!;
      expect(
        const RawChkEncoder().encode(reopened.maps.state.session!.rawDocument),
        expected,
      );
      expect(await hashes.fingerprint(originalA), hashA);
      expect(await hashes.fingerprint(originalB), hashB);
    },
    skip: !Platform.isWindows || helper == null
        ? 'Requires MAP_ARCHIVE_HELPER_PATH on Windows.'
        : false,
  );
}
