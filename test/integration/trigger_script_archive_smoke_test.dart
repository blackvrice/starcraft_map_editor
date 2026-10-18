import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_editor.dart';
import 'package:starcraft_map_editor/domain/triggers/trigger_script.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';
import '../fixtures/basic_editing_fixture.dart';
import '../fixtures/trigger_script_fixture.dart';

void main() {
  final helper = Platform.environment['MAP_ARCHIVE_HELPER_PATH'];
  test(
    'three languages produce the same normal MPQ Save As with original archive unchanged',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'trigger-language-mpq-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final gateway = ProcessMapArchiveGateway(helperExecutablePath: helper!);
      final doc = scriptDocument(),
          snapshot = TriggerScriptSnapshot(scriptDocument());
      final source = '${directory.path}/original.scx';
      final created = await gateway.writeTemporary(
        MapArchiveWriteRequest(
          operationId: 'script-create',
          sourcePath: null,
          temporaryOutputPath: source,
          scenarioChkBytes: const RawChkEncoder().encode(doc),
          timeout: const Duration(seconds: 30),
        ),
      );
      expect(created.isSuccess, isTrue);
      final original = await File(source).readAsBytes();
      List<int>? sameOutput;
      for (final language in TriggerScriptLanguage.values) {
        final text = snapshot
            .format(snapshot.initial, language)
            .replaceFirst(', 1000)', ', 3210)');
        final records = snapshot.parse(text, language).triggers;
        final index = ChkTriggers.read(doc).sectionIndex;
        final changed = doc.replaceSection(
          index,
          basicSection('TRIG', ChkTriggers.encode(records)),
        );
        final bytes = const RawChkEncoder().encode(changed);
        sameOutput ??= bytes;
        expect(bytes, sameOutput);
        final output = '${directory.path}/${language.extension}.scx';
        final written = await gateway.writeTemporary(
          MapArchiveWriteRequest(
            operationId: 'script-save-${language.extension}',
            sourcePath: source,
            temporaryOutputPath: output,
            scenarioChkBytes: bytes,
            timeout: const Duration(seconds: 30),
          ),
        );
        expect(written.isSuccess, isTrue);
        final opened = await gateway.open(
          MapArchiveOpenRequest(
            operationId: 'script-open-${language.extension}',
            sourcePath: output,
            timeout: const Duration(seconds: 30),
          ),
        );
        expect(opened.isSuccess, isTrue);
        expect(opened.extractedMap!.scenarioChkBytes, bytes);
        expect(await File(source).readAsBytes(), original);
      }
    },
    skip: helper == null
        ? 'Set MAP_ARCHIVE_HELPER_PATH after the Windows build.'
        : false,
  );
}
