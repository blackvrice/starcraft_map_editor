import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/recovery_snapshot.dart';
import 'package:starcraft_map_editor/application/eud/eud_source_controller.dart';
import 'package:starcraft_map_editor/application/ports/eud_source_translation_gateway.dart';
import 'package:starcraft_map_editor/application/ports/trigger_script_gateway.dart';
import 'package:starcraft_map_editor/domain/triggers/trigger_script.dart';
import '../domain/eud/portable_eud_script_test.dart' show example;

class _Files implements TriggerScriptFiles {
  TriggerScriptFile? opened;
  Completer<String?>? pending;
  final saved = <(String, TriggerScriptLanguage)>[];
  @override
  Future<TriggerScriptFile?> open() async => opened;
  @override
  Future<String?> saveNew(String text, TriggerScriptLanguage language) async {
    saved.add((text, language));
    return pending == null
        ? 'C:/source/new.${language.extension}'
        : pending!.future;
  }
}

class _Translator implements EudSourceTranslationGateway {
  Completer<EudSourceTranslation>? pending;
  bool cancelled = false;
  @override
  void cancel() {
    cancelled = true;
  }

  @override
  Future<EudSourceTranslation> toPython(String source) async => pending!.future;
}

void main() {
  test(
    'Python draft editing, Save As, reopen and recovery retain language and exact text',
    () async {
      final files = _Files();
      final c = EudSourceController(files: files);
      addTearDown(c.dispose);
      c.createUntitled();
      expect(c.changeEmptyLanguage(TriggerScriptLanguage.python), isTrue);
      expect(c.state.document!.fileName, 'main.py');
      c.updateText(
        'from eudplib import *\n# 한국어\ndef onPluginStart():\n    pass\n',
      );
      expect(c.changeEmptyLanguage(TriggerScriptLanguage.epScript), isFalse);
      final snapshot = RecoverySnapshot.decode(
        RecoverySnapshot(
          savedAt: DateTime.utc(2026),
          source: c.state.document,
        ).encode(),
      );
      expect(snapshot.source!.language, TriggerScriptLanguage.python);
      expect(snapshot.source!.text, c.state.document!.text);
      await c.saveNew();
      expect(c.state.document!.isDirty, isFalse);
      expect(c.state.document!.sourcePath, 'C:/source/new.py');
      files.opened = TriggerScriptFile(
        'C:/source/open.eps',
        example,
        TriggerScriptLanguage.epScript,
      );
      await c.openFile();
      expect(c.state.document!.language, TriggerScriptLanguage.epScript);
    },
  );
  test(
    'late file save cannot mark newer text saved; dirty open and native Lua are rejected',
    () async {
      final files = _Files();
      final c = EudSourceController(files: files);
      addTearDown(c.dispose);
      c.createUntitled(fileName: 'main.py');
      c.updateText('original');
      files.pending = Completer<String?>();
      final pending = c.saveNew();
      c.updateText('newer');
      files.pending!.complete('C:/source/old.py');
      await pending;
      expect(c.state.document!.text, 'newer');
      expect(c.state.document!.isDirty, isTrue);
      await expectLater(c.openFile(), throwsStateError);
      c.close(discardChanges: true);
      files.opened = const TriggerScriptFile(
        'C:/source/a.lua',
        'return 1',
        TriggerScriptLanguage.lua,
      );
      await expectLater(c.openFile(), throwsStateError);
      expect(c.state.document, isNull);
    },
  );
  test(
    'conversion preview and export preserve original draft; unrepresentable code is rejected',
    () async {
      final files = _Files();
      final c = EudSourceController(files: files);
      addTearDown(c.dispose);
      c.createUntitled(initialText: example);
      final original = c.state.document;
      final output = await c.translate(TriggerScriptLanguage.python);
      expect(output, contains('DoActions(SetMemory'));
      expect(c.state.document, same(original));
      await c.exportTranslation(output, TriggerScriptLanguage.python);
      expect(files.saved.single, (output, TriggerScriptLanguage.python));
      expect(c.state.document, same(original));
      c.updateText('import dangerous;');
      await expectLater(
        c.translate(TriggerScriptLanguage.lua),
        throwsA(isA<TriggerScriptDiagnostic>()),
      );
      expect(c.state.document!.text, 'import dangerous;');
    },
  );
  test(
    'compiler response after edits/disposal cannot replace source or publish a stale result',
    () async {
      final translator = _Translator()
        ..pending = Completer<EudSourceTranslation>();
      final c = EudSourceController(translator: translator);
      c.createUntitled(initialText: example);
      final pending = c.translate(TriggerScriptLanguage.python);
      c.updateText('new source');
      c.dispose();
      expect(translator.cancelled, isTrue);
      translator.pending!.complete(
        const EudSourceTranslation(
          source: 'old translation',
          toolVersion: 'fixture',
          rawLog: '',
        ),
      );
      await expectLater(pending, throwsStateError);
      expect(c.latestTranslation, isNull);
      expect(c.state.document!.text, 'new source');
    },
  );
}
