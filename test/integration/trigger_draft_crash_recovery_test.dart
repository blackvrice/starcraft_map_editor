import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/recovery_snapshot.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_recovery_store.dart';

void main() {
  final dart = Platform.environment['DART_EXECUTABLE_PATH'];
  test(
    'forced process termination retains verified draft and ignores partial generation',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'trigger_draft_crash_',
      );
      addTearDown(() => root.delete(recursive: true));
      final process = await Process.start(dart!, [
        'run',
        'test/fixtures/helpers/crash_trigger_draft_writer.dart',
        root.path,
      ]);
      addTearDown(() {
        process.kill();
      });
      final errors = process.stderr.transform(utf8.decoder).join();
      final ready = Completer<void>();
      final lines = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (line == 'CHECKPOINT_FLUSHED' && !ready.isCompleted) {
                ready.complete();
              }
            },
            onDone: () {
              if (!ready.isCompleted) {
                ready.completeError(
                  StateError('Writer exited before checkpoint'),
                );
              }
            },
          );
      try {
        await ready.future.timeout(const Duration(seconds: 30));
        expect(process.kill(), isTrue);
        expect(
          await process.exitCode.timeout(const Duration(seconds: 10)),
          isNot(0),
        );
        expect(await errors, isEmpty);
      } finally {
        process.kill();
        await lines.cancel();
      }
      final entries = await LocalRecoveryStore(root).list();
      expect(entries, hasLength(1));
      final recovered = RecoverySnapshot.decode(entries.single.content);
      expect(recovered.triggerDraft!.current.text, 'invalid draft 한글\n');
      expect(recovered.triggerDraft!.history.single.text, '// original');
      expect(recovered.triggerDraft!.current.language.name, 'python');
      expect(recovered.sourceWorkspace!.activeId, 'py');
      expect(recovered.sourceWorkspace!.documents.map((d) => d.text), [
        'unsaved eps 한글',
        'unsaved python',
        'unsaved lua',
      ]);
      expect(
        recovered.sourceWorkspace!.documents.first.savedText,
        'original eps',
      );
    },
    skip: dart == null
        ? 'Set DART_EXECUTABLE_PATH for forced-kill integration.'
        : false,
  );
}
