import 'dart:async';
import 'dart:io';
import 'package:starcraft_map_editor/domain/triggers/trigger_script_syntax.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/application/documents/recovery_snapshot.dart';
import 'package:starcraft_map_editor/application/eud/eud_source_document.dart';
import 'package:starcraft_map_editor/application/eud/source_workspace_recovery.dart';
import 'package:starcraft_map_editor/application/triggers/trigger_script_drafts.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_recovery_store.dart';
import '../trigger_script_fixture.dart';

Future<void> main(List<String> args) async {
  final document = scriptDocument();
  final snapshot = RecoverySnapshot(
    savedAt: DateTime.utc(2026, 10, 19),
    sourceWorkspace: SourceWorkspaceRecovery(
      root: r'C:\Project\src',
      activeId: 'py',
      documents: [
        EudSourceDocument.opened(
          documentId: 'eps',
          sourcePath: r'C:\Project\src\main.eps',
          text: 'original eps',
        ).withText('unsaved eps 한글'),
        EudSourceDocument.opened(
          documentId: 'py',
          sourcePath: r'C:\Project\src\helper.py',
          text: 'original python',
        ).withText('unsaved python'),
        EudSourceDocument.untitled(
          documentId: 'lua',
          fileName: 'new.lua',
          initialText: 'unsaved lua',
        ),
      ],
    ),
    map: RecoveryMap(
      sourcePath: null,
      fingerprint: null,
      baseline: const RawChkEncoder().encode(document),
      document: document,
      resources: const {},
    ),
    triggerDraft: TriggerScriptRecovery(
      baseline: document,
      current: const TriggerScriptDraft(
        'invalid draft 한글\n',
        TriggerScriptLanguage.python,
      ),
      loadedText: 'initial',
      history: const [
        TriggerScriptDraft('// original', TriggerScriptLanguage.epScript),
      ],
    ),
  );
  await LocalRecoveryStore(
    Directory(args.single),
  ).write('checkpoint-crash-draft', snapshot.encode());
  // Deliberately leave an interrupted next write. The parent kills this process
  // without running any dispose/close/final checkpoint path.
  await File(
    '${args.single}/checkpoint-interrupted.json.partial',
  ).writeAsString('{', flush: true);
  stdout.writeln('CHECKPOINT_FLUSHED');
  await stdout.flush();
  Timer.periodic(const Duration(seconds: 10), (_) {});
  await Completer<void>().future;
}
