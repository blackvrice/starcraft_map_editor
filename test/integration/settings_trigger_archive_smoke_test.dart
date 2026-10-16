import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_player_colors.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_resource_editor.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_search.dart';
import '../fixtures/settings_trigger_editing_fixture.dart';

void main() {
  final helper = Platform.environment['MAP_ARCHIVE_HELPER_PATH'];
  test(
    'settings tokens CRGB trigger replacement survive real MPQ Save As byte-exact',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'editor-settings-triggers-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final gateway = ProcessMapArchiveGateway(helperExecutablePath: helper!);
      var doc = editingDocument().appendSection(
        editingSection('XTRA', [255, 0, 6, 99]),
      );
      doc = withRecords(doc, [triggerAction(doc, 10)]);
      final originalChk = const RawChkEncoder().encode(doc);
      final source = '${directory.path}/original.scx',
          output = '${directory.path}/edited.scx';
      final created = await gateway.writeTemporary(
        MapArchiveWriteRequest(
          operationId: 'settings-create',
          sourcePath: null,
          temporaryOutputPath: source,
          scenarioChkBytes: originalChk,
          timeout: const Duration(seconds: 30),
        ),
      );
      expect(created.isSuccess, isTrue, reason: '${created.diagnostics}');
      final originalArchive = await File(source).readAsBytes();
      doc = ChkPlayerColors.edit(doc, {0: const ChkPlayerColor(2, 12, 34, 56)});
      doc = ChkResourceEditor.editRaw(doc, 1, [6, 65, 255, 10]);
      final search = ChkTriggerSearch(doc);
      final preview = search.replace(
        selected: {0},
        reference: 'location',
        from: 64,
        to: 2,
      );
      doc = withRecords(doc, preview.records);
      final editedChk = const RawChkEncoder().encode(doc);
      final written = await gateway.writeTemporary(
        MapArchiveWriteRequest(
          operationId: 'settings-save-as',
          sourcePath: source,
          temporaryOutputPath: output,
          scenarioChkBytes: editedChk,
          timeout: const Duration(seconds: 30),
        ),
      );
      expect(written.isSuccess, isTrue, reason: '${written.diagnostics}');
      final reopened = await gateway.open(
        MapArchiveOpenRequest(
          operationId: 'settings-reopen',
          sourcePath: output,
          timeout: const Duration(seconds: 30),
        ),
      );
      expect(reopened.isSuccess, isTrue, reason: '${reopened.diagnostics}');
      expect(reopened.extractedMap!.scenarioChkBytes, editedChk);
      expect(await File(source).readAsBytes(), originalArchive);
      expect(doc.sections.firstWhere((s) => s.name == 'XTRA').payload, [
        255,
        0,
        6,
        99,
      ]);
    },
    skip: helper == null
        ? 'Set MAP_ARCHIVE_HELPER_PATH after the Windows build.'
        : false,
  );
}
