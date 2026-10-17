import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/save_map_controller.dart';
import 'package:starcraft_map_editor/application/editing/basic_editing_controller.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_save_file_gateway.dart';
import '../fixtures/multi_map_fixture.dart';

void main() {
  final helper = Platform.environment['MAP_ARCHIVE_HELPER_PATH'];
  test(
    'A/B inactive SaveAs, isolated Undo, reopen and cross-document output conflict preserve source MPQs',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'multi_map_workspace_',
      );
      addTearDown(() => root.delete(recursive: true));
      final fingerprint = LocalMapFileFingerprintGateway();
      final f = MultiMapFixture(
        archive: ProcessMapArchiveGateway(helperExecutablePath: helper!),
        fingerprints: fingerprint,
        files: LocalMapSaveFileGateway(),
      );
      addTearDown(f.dispose);
      final a = f.addMap(), b = f.addMap(tile: 2);
      expect(f.workspace.active, same(b));
      final originalA = '${root.path}/원본A.scx',
          originalB = '${root.path}/원본B.scx';
      expect(
        (await a.saves.saveAs(destinationPath: originalA)).status,
        SaveMapStatus.saved,
      );
      expect(f.workspace.active, same(b));
      expect(
        (await b.saves.saveAs(destinationPath: originalB)).status,
        SaveMapStatus.saved,
      );
      final hashA = await fingerprint.fingerprint(originalA),
          hashB = await fingerprint.fingerprint(originalB);
      final beforeA = a.maps.state.session!, beforeB = b.maps.state.session!;
      final ea = BasicEditingController(
            maps: a.maps,
            layers: a.value.mapLayerController,
          ),
          eb = BasicEditingController(
            maps: b.maps,
            layers: b.value.mapLayerController,
          );
      addTearDown(ea.dispose);
      addTearDown(eb.dispose);
      ea.setStartLocation(player: 0, x: 64, y: 64);
      eb.setStartLocation(player: 0, x: 800, y: 800);
      final bytesA = const RawChkEncoder().encode(
            a.maps.state.session!.rawDocument,
          ),
          bytesB = const RawChkEncoder().encode(
            b.maps.state.session!.rawDocument,
          );
      expect(a.maps.editHistory.undo(), isTrue);
      expect(a.maps.state.session, same(beforeA));
      expect(b.maps.state.session, isNot(same(beforeB)));
      expect(a.maps.editHistory.redo(), isTrue);
      final bad = await b.saves.saveAs(
        destinationPath: originalA,
        replaceExisting: true,
      );
      expect(bad.status, SaveMapStatus.failed);
      expect(await fingerprint.fingerprint(originalA), hashA);
      final outputA = '${root.path}/편집A.scx', outputB = '${root.path}/편집B.scx';
      expect(
        (await a.saves.saveAs(destinationPath: outputA)).status,
        SaveMapStatus.saved,
      );
      expect(f.workspace.active, same(b));
      expect(
        (await b.saves.saveAs(destinationPath: outputB)).status,
        SaveMapStatus.saved,
      );
      expect(await f.workspace.open(path: outputA), same(a));
      expect(f.workspace.documents.length, 2);
      expect(
        await f.workspace.close(
          a,
          expectedRevision: a.revision,
          discardChanges: true,
        ),
        isTrue,
      );
      expect(
        await f.workspace.close(
          b,
          expectedRevision: b.revision,
          discardChanges: true,
        ),
        isTrue,
      );
      final reopenedA = (await f.workspace.open(path: outputA))!,
          reopenedB = (await f.workspace.open(path: outputB))!;
      expect(
        const RawChkEncoder().encode(reopenedA.maps.state.session!.rawDocument),
        bytesA,
      );
      expect(
        const RawChkEncoder().encode(reopenedB.maps.state.session!.rawDocument),
        bytesB,
      );
      expect(await fingerprint.fingerprint(originalA), hashA);
      expect(await fingerprint.fingerprint(originalB), hashB);
    },
    skip: !Platform.isWindows || helper == null
        ? 'Requires MAP_ARCHIVE_HELPER_PATH on Windows.'
        : false,
  );
}
