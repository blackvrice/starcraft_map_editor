import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/autosave_controller.dart';
import 'package:starcraft_map_editor/application/documents/recovery_snapshot.dart';
import 'package:starcraft_map_editor/application/eud/eud_source_controller.dart';
import 'package:starcraft_map_editor/application/triggers/trigger_script_drafts.dart';
import 'package:starcraft_map_editor/domain/triggers/trigger_script.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';
import '../fixtures/eud_project_workspace_fixture.dart';
import '../fixtures/trigger_script_fixture.dart';
import 'autosave_controller_test.dart' show MemoryRecoveryStore;

void main() {
  test(
    'draft debounce writes a clean map, disabled autosave does not, failure retains a generation',
    () async {
      final f = EudWorkspaceFixture(),
          source = EudSourceController(),
          drafts = TriggerScriptDraftWorkspace(),
          store = MemoryRecoveryStore();
      await f.maps.open();
      final autosave = AutosaveController(
        maps: f.maps,
        sources: source,
        projects: f.projects,
        store: store,
        settings: InMemorySettingsStore(),
        triggerDrafts: drafts,
      );
      addTearDown(() async {
        await autosave.dispose();
        await drafts.dispose();
        source.dispose();
        f.dispose();
      });
      await autosave.initialize();
      TriggerScriptRecovery draft(String text) => TriggerScriptRecovery(
        baseline: scriptDocument(),
        current: TriggerScriptDraft(text, TriggerScriptLanguage.python),
        loadedText: '',
        history: const [],
      );
      drafts.update(draft('not applied'));
      await Future<void>.delayed(const Duration(milliseconds: 800));
      expect(store.values, hasLength(1));
      expect(
        RecoverySnapshot.decode(
          store.values.values.single,
        ).triggerDraft!.current.text,
        'not applied',
      );
      final saved = Map.of(store.values);
      await autosave.configure(
        enabled: false,
        interval: const Duration(seconds: 30),
        retention: 5,
      );
      drafts.update(draft('disabled text'));
      await Future<void>.delayed(const Duration(milliseconds: 800));
      expect(store.values, saved);
      store.fail = true;
      await autosave.checkpoint();
      expect(autosave.lastError, 'AUTOSAVE_WRITE_FAILED');
      expect(store.values, saved);
    },
  );
}
