import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/trigger_script_gateway.dart';
import 'package:starcraft_map_editor/application/triggers/trigger_script_controller.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_editor.dart';
import 'package:starcraft_map_editor/domain/triggers/trigger_script.dart';
import '../fixtures/editor_overlay_fixture.dart';
import '../fixtures/trigger_script_fixture.dart';

class ScriptGateway implements TriggerScriptGateway {
  Completer<TriggerScriptAnalysis>? pending;
  int calls = 0;
  final cancelled = <String>[];
  @override
  void cancel(String operationId) => cancelled.add(operationId);
  @override
  Future<TriggerScriptAnalysis> analyze({
    required String operationId,
    required RawChkDocument document,
    required TriggerScriptLanguage language,
    String? source,
    TriggerScriptLanguage? target,
  }) async {
    calls++;
    if (pending != null) return pending!.future;
    final s = TriggerScriptSnapshot(document);
    try {
      final program = source == null ? s.initial : s.parse(source, language);
      return TriggerScriptAnalysis(
        program: program,
        generated: s.format(program, target ?? language),
      );
    } on TriggerScriptDiagnostic catch (e) {
      return TriggerScriptAnalysis(diagnostic: e);
    }
  }
}

class _Files implements TriggerScriptFiles {
  final saved = <TriggerScriptDraft>[];
  bool cancel = false;
  @override
  Future<TriggerScriptFile?> open() async => null;
  @override
  Future<String?> saveNew(String text, TriggerScriptLanguage language) async {
    if (cancel) return null;
    saved.add(TriggerScriptDraft(text, language));
    return 'C:/saved-${saved.length}.${language.extension}';
  }
}

void main() {
  late OverlayHarness h;
  late ScriptGateway gateway;
  late TriggerScriptController c;
  late _Files files;
  setUp(() {
    h = OverlayHarness();
    h.editing.apply(h.editing.source.rawDocument, scriptDocument(), 'Fixture');
    gateway = ScriptGateway();
    files = _Files();
    c = TriggerScriptController(
      editing: h.objects,
      gateway: gateway,
      files: files,
    );
  });
  tearDown(() async {
    await c.dispose();
    await h.dispose();
  });
  test(
    'preview and explicit conversion preserve original comments and never edit map',
    () async {
      await c.reload();
      final before = h.h.maps.state.session,
          depth = h.h.maps.editHistory.undoDepth;
      final original = '${c.text}\n// 한글 원문\n';
      c.updateText(original);
      expect(await c.analyze(convertTo: TriggerScriptLanguage.python), isTrue);
      expect(c.text, original);
      expect(c.language, TriggerScriptLanguage.epScript);
      expect(c.canApply, isFalse);
      expect(c.acceptConversion(), isTrue);
      expect(c.language, TriggerScriptLanguage.python);
      expect(c.history.single.text, original);
      expect(c.dirty, isTrue);
      expect(h.h.maps.state.session, same(before));
      expect(h.h.maps.editHistory.undoDepth, depth);
      expect(await c.analyze(convertTo: TriggerScriptLanguage.lua), isTrue);
      expect(c.acceptConversion(), isTrue);
      expect(c.history.length, 2);
      expect(h.h.maps.state.session, same(before));
    },
  );
  test(
    'apply is one Undo, raw resources survive, reload rebases and Undo makes draft stale',
    () async {
      await c.reload();
      final before = h.h.maps.state.session!,
          depth = h.h.maps.editHistory.undoDepth;
      c.updateText(c.text.replaceFirst(', 1000)', ', 2000)'));
      expect(await c.apply(), isFalse);
      expect(await c.analyze(), isTrue);
      expect(await c.apply(), isTrue);
      expect(c.dirty, isFalse);
      expect(c.stale, isFalse);
      expect(h.h.maps.editHistory.undoDepth, depth + 1);
      final after = h.h.maps.state.session!;
      for (var i = 0; i < after.rawDocument.sections.length; i++) {
        if (after.rawDocument.sections[i].name != 'TRIG') {
          expect(
            after.rawDocument.sections[i].payload,
            before.rawDocument.sections[i].payload,
          );
        }
      }
      expect(after.resourceEdits, before.resourceEdits);
      h.h.maps.editHistory.undo();
      expect(c.stale, isTrue);
      expect(c.canApply, isFalse);
      expect(
        const RawChkEncoder().encode(h.h.maps.state.session!.rawDocument),
        const RawChkEncoder().encode(before.rawDocument),
      );
    },
  );
  test(
    'missing opaque slot and record require separate deletion consent',
    () async {
      final base = scriptRecord(scriptDocument()),
          bytes = [...base.bytes]..[18] = 1;
      h.objects.applyTriggers(
        expectedDocument: h.editing.source.rawDocument,
        records: [ChkTrigger(bytes)],
      );
      await c.reload();
      c.updateText(c.text.replaceFirst('RawCondition(0)', ''));
      await c.analyze();
      expect(c.preview!.program!.opaqueDeletions, 1);
      await expectLater(c.apply(), throwsStateError);
      expect(await c.apply(allowDeletion: true), isTrue);
    },
  );
  test(
    'late reply after text change cannot change text, preview or busy state',
    () async {
      await c.reload();
      final response = c.preview!;
      gateway.pending = Completer<TriggerScriptAnalysis>();
      final old = c.analyze(convertTo: TriggerScriptLanguage.lua);
      c.updateText('${c.text}\n// edited while parsing\n');
      gateway.pending!.complete(response);
      expect(await old, isFalse);
      expect(c.preview, isNull);
      expect(c.text, contains('edited while parsing'));
      expect(c.busy, isFalse);
      expect(gateway.cancelled, isNotEmpty);
    },
  );
  test(
    'map change, disposal and malformed draft cannot apply stale results',
    () async {
      await c.reload();
      final text = c.text, response = c.preview!;
      gateway.pending = Completer<TriggerScriptAnalysis>();
      final old = c.analyze();
      h.objects.applyTriggers(expectedDocument: c.baseline!, records: []);
      gateway.pending!.complete(response);
      expect(await old, isFalse);
      expect(c.stale, isTrue);
      expect(c.text, text);
      expect(await c.apply(), isFalse);
      gateway.pending = null;
      await c.reload();
      c.updateText('${c.text}\nimport os;');
      expect(await c.analyze(), isFalse);
      expect(c.preview!.diagnostic, isNotNull);
      expect(c.canApply, isFalse);
      gateway.pending = Completer<TriggerScriptAnalysis>();
      final disposal = c.analyze();
      await c.dispose();
      gateway.pending!.complete(response);
      expect(await disposal, isFalse);
    },
  );
  test(
    'dirty reload requires preservation and history is never silently evicted',
    () async {
      await c.reload();
      c.updateText('${c.text}\n// a\n');
      await expectLater(c.reload(), throwsStateError);
      expect(await c.reload(keepDraft: true), isTrue);
      expect(c.history.single.text, contains('// a'));
      for (var i = 0; i < 7; i++) {
        c.updateText('${c.text}\n// unique $i\n');
        await c.reload(keepDraft: true);
      }
      final original = c.history.first.text;
      c.updateText('${c.text}\n// ninth\n');
      await expectLater(c.reload(keepDraft: true), throwsStateError);
      expect(c.history.length, 8);
      expect(c.history.first.text, original);
      expect(c.text, contains('ninth'));
    },
  );
  test(
    'applied map does not authorize losing original comments; save all pending originals',
    () async {
      await c.reload();
      final original = '${c.text}\n// original comment\n';
      c.updateText(original.replaceFirst(', 1000)', ', 2345)'));
      await c.analyze();
      await c.apply();
      expect(c.dirty, isFalse);
      expect(c.hasPendingSources, isTrue);
      files.cancel = true;
      expect(await c.exportPending(), isFalse);
      expect(c.hasPendingSources, isTrue);
      files.cancel = false;
      expect(await c.exportPending(), isTrue);
      expect(c.hasPendingSources, isFalse);
      expect(files.saved.single.text, contains('// original comment'));
      expect(files.saved.single.text, contains(', 2345)'));
    },
  );
}
