import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/autosave_controller.dart';
import 'package:starcraft_map_editor/application/documents/recovery_snapshot.dart';
import 'package:starcraft_map_editor/application/editing/object_editing_controller.dart';
import 'package:starcraft_map_editor/application/eud/eud_source_controller.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/triggers/trigger_script_controller.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/triggers/trigger_script.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';
import '../fixtures/editor_overlay_fixture.dart';
import '../fixtures/eud_project_workspace_fixture.dart';
import '../fixtures/trigger_script_fixture.dart';
import 'autosave_controller_test.dart' show MemoryRecoveryStore;
import 'trigger_script_controller_test.dart' show ScriptGateway;

void main() {
  test(
    'unapplied malformed source, language and originals survive a new controller',
    () async {
      final h = OverlayHarness();
      addTearDown(h.dispose);
      h.editing.apply(
        h.editing.source.rawDocument,
        scriptDocument(),
        'Fixture',
      );
      final c = TriggerScriptController(
        editing: h.objects,
        gateway: ScriptGateway(),
      );
      await c.open();
      final before = h.h.maps.state.session;
      final original = '${c.text}\n// 원문';
      c.updateText(original);
      await c.analyze(convertTo: TriggerScriptLanguage.python);
      c.acceptConversion();
      c.updateText('${c.text}\ninvalid python!');
      final text = c.text;
      final checkpoint = RecoverySnapshot(
        savedAt: DateTime.utc(2026),
        map: RecoveryMap.capture(before!),
        triggerDraft: h.objects.triggerDrafts.value,
      );
      final decoded = RecoverySnapshot.decode(checkpoint.encode());
      expect(jsonDecode(checkpoint.encode())['schema'], 2);
      await c
          .dispose(); // Simulate loss of the editor UI without a close/discard.
      h.objects.triggerDrafts.update(decoded.triggerDraft);
      final reopened = TriggerScriptController(
        editing: h.objects,
        gateway: ScriptGateway(),
      );
      addTearDown(reopened.dispose);
      await reopened.open();
      expect(reopened.text, text);
      expect(reopened.stale, isFalse);
      expect(reopened.language, TriggerScriptLanguage.python);
      expect(reopened.history.single.text, original);
      expect(reopened.canApply, isFalse);
      expect(reopened.hasPendingSources, isTrue);
      expect(h.h.maps.state.session, same(before));
      expect(await reopened.analyze(), isFalse);
    },
  );

  test(
    'autosave/restart restores draft with clean saved map without applying TRIG',
    () async {
      final f = EudWorkspaceFixture(),
          sources = EudSourceController(),
          store = MemoryRecoveryStore(),
          layers = MapLayerController();
      await f.maps.open();
      final objects = ObjectEditingController(
        openMapController: f.maps,
        mapLayerController: layers,
      );
      final draft = TriggerScriptRecovery(
        baseline: scriptDocument(),
        current: const TriggerScriptDraft(
          'unapplied 한글',
          TriggerScriptLanguage.lua,
        ),
        loadedText: 'initial',
        history: const [
          TriggerScriptDraft('original', TriggerScriptLanguage.epScript),
        ],
      );
      final autosave = AutosaveController(
        maps: f.maps,
        sources: sources,
        projects: f.projects,
        store: store,
        settings: InMemorySettingsStore(),
        triggerDrafts: objects.triggerDrafts,
      );
      objects.triggerDrafts.update(draft);
      await autosave.checkpoint();
      final id = store.values.keys.single;
      await autosave.dispose();
      await objects.dispose();
      await layers.dispose();
      sources.dispose();
      f.dispose();

      final next = EudWorkspaceFixture(),
          nextSources = EudSourceController(),
          nextLayers = MapLayerController();
      final nextObjects = ObjectEditingController(
        openMapController: next.maps,
        mapLayerController: nextLayers,
      );
      final restarted = AutosaveController(
        maps: next.maps,
        sources: nextSources,
        projects: next.projects,
        store: store,
        settings: InMemorySettingsStore(),
        triggerDrafts: nextObjects.triggerDrafts,
      );
      addTearDown(() async {
        await restarted.dispose();
        await nextObjects.dispose();
        await nextLayers.dispose();
        nextSources.dispose();
        next.dispose();
      });
      await restarted.refresh();
      expect(nextObjects.triggerDrafts.value, isNull);
      expect(next.maps.state.session, isNull);
      await restarted.restore(id);
      expect(nextObjects.triggerDrafts.value!.current.text, 'unapplied 한글');
      expect(next.maps.state.session!.isDirty, isFalse);
      final before = const RawChkEncoder().encode(
        next.maps.state.session!.rawDocument,
      );
      final editor = TriggerScriptController(
        editing: nextObjects,
        gateway: ScriptGateway(),
      );
      addTearDown(editor.dispose);
      await editor.open();
      expect(
        editor.stale,
        isTrue,
      ); // A different baseline must never be rebound.
      expect(editor.canApply, isFalse);
      expect(
        const RawChkEncoder().encode(next.maps.state.session!.rawDocument),
        before,
      );
    },
  );

  test('bad draft schemas, history budgets and raw baseline fail closed', () {
    final snapshot = RecoverySnapshot(
      savedAt: DateTime.utc(2026),
      triggerDraft: TriggerScriptRecovery(
        baseline: scriptDocument(),
        current: const TriggerScriptDraft('x', TriggerScriptLanguage.python),
        loadedText: '',
        history: const [],
      ),
    );
    final json = jsonDecode(snapshot.encode()) as Map<String, dynamic>;
    for (final mutation in <void Function(Map<String, dynamic>)>[
      (j) => j['triggerDraft']['current']['language'] = 'ruby',
      (j) => j['triggerDraft']['history'] = List.filled(9, {
        'text': '',
        'language': 'python',
      }),
      (j) => j['triggerDraft']['baseline'] = 'AAAA',
      (j) => j['schema'] = 999,
    ]) {
      final copy = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
      mutation(copy);
      expect(
        () => RecoverySnapshot.decode(jsonEncode(copy)),
        throwsA(isA<Object>()),
      );
    }
  });

  test(
    'explicit discard clears persisted draft; disposal alone does not',
    () async {
      final h = OverlayHarness();
      addTearDown(h.dispose);
      h.editing.apply(
        h.editing.source.rawDocument,
        scriptDocument(),
        'Fixture',
      );
      final editor = TriggerScriptController(
        editing: h.objects,
        gateway: ScriptGateway(),
      );
      await editor.open();
      editor.updateText('malformed');
      expect(h.objects.triggerDrafts.value, isNotNull);
      await editor.dispose();
      expect(h.objects.triggerDrafts.value, isNotNull);
      final reopened = TriggerScriptController(
        editing: h.objects,
        gateway: ScriptGateway(),
      );
      await reopened.open();
      reopened.discardRecovery();
      await reopened.dispose();
      expect(h.objects.triggerDrafts.value, isNull);
    },
  );
}
