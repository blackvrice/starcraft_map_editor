import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/autosave_controller.dart';
import 'package:starcraft_map_editor/application/documents/opened_map_session.dart';
import 'package:starcraft_map_editor/application/documents/recovery_snapshot.dart';
import 'package:starcraft_map_editor/application/eud/eud_source_controller.dart';
import 'package:starcraft_map_editor/application/ports/recovery_store.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';

import '../fixtures/eud_project_workspace_fixture.dart';
import '../fixtures/pcm_sound_fixture.dart';

class MemoryRecoveryStore implements RecoveryStore {
  final values = <String, String>{};
  bool fail = false;
  Completer<void>? pending;
  @override
  Future<List<RecoveryEntry>> list() async => [
    for (final entry in values.entries)
      RecoveryEntry(id: entry.key, content: entry.value),
  ];
  @override
  Future<void> write(String id, String content) async {
    await pending?.future;
    if (fail) throw StateError('disk full');
    values[id] = content;
  }

  @override
  Future<void> remove(String id) async => values.remove(id);
}

AutosaveController attach(
  EudWorkspaceFixture fixture,
  EudSourceController source,
  MemoryRecoveryStore store, {
  String owner = 'test',
}) => AutosaveController(
  maps: fixture.maps,
  projects: fixture.projects,
  sources: source,
  store: store,
  settings: InMemorySettingsStore(),
  ownerId: owner,
);

void main() {
  test(
    'periodic autosave runs with stored preferences and stops after disposal',
    () async {
      final fixture = EudWorkspaceFixture(),
          source = EudSourceController(),
          store = MemoryRecoveryStore();
      final settings = InMemorySettingsStore();
      await settings.writeString('autosaveIntervalSeconds', '5');
      await settings.writeString('autosaveRetention', '2');
      final controller = AutosaveController(
        maps: fixture.maps,
        sources: source,
        projects: fixture.projects,
        store: store,
        settings: settings,
      );
      addTearDown(fixture.dispose);
      addTearDown(source.dispose);
      source.createUntitled(initialText: 'periodic');
      await controller.initialize();
      expect(controller.interval.inSeconds, 5);
      expect(controller.retention, 2);
      await Future<void>.delayed(const Duration(milliseconds: 5300));
      await controller.checkpoint();
      expect(store.values.length, 1);
      await controller.dispose();
      source.updateText('after disposal');
      await controller.checkpoint();
      expect(store.values.length, 1);
    },
  );

  test(
    'document changes during asynchronous recovery abort all adoption',
    () async {
      final fixture = EudWorkspaceFixture(),
          source = EudSourceController(),
          store = MemoryRecoveryStore();
      final controller = attach(fixture, source, store);
      addTearDown(controller.dispose);
      addTearDown(fixture.dispose);
      addTearDown(source.dispose);
      await fixture.maps.open();
      source.createUntitled(initialText: 'recover me');
      await controller.checkpoint();
      final id = store.values.keys.single;
      source.close(discardChanges: true);
      final oldMap = fixture.maps.state.session;
      fixture.pending = Completer();
      final restoring = controller.restore(id);
      final rejected = expectLater(restoring, throwsStateError);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      source.createUntitled(initialText: 'new work');
      fixture.pending!.complete(fixture.snapshot);
      await rejected;
      expect(fixture.maps.state.session, same(oldMap));
      expect(source.state.document!.text, 'new work');
      expect(store.values.containsKey(id), isTrue);
    },
  );

  test(
    'restart restores new CHK duplicate/unknown bytes, resource edits and EUD drafts without writes',
    () async {
      final first = EudWorkspaceFixture(),
          source = EudSourceController(),
          store = MemoryRecoveryStore();
      final autosave = attach(first, source, store);
      addTearDown(first.dispose);
      addTearDown(source.dispose);
      first.maps.createNew(
        NewMapOptions(rawTileValue: 0),
        expectedSession: null,
      );
      var doc = first.maps.state.session!.rawDocument;
      for (var i = 0; i < 2; i++) {
        doc = doc.appendSection(
          RawChkSection(
            nameBytes: [255, 0, 65, 66],
            declaredLength: 3,
            payload: [255, 128, i],
            sourceOffset: 0,
            isDirty: true,
          ),
        );
      }
      final initial = first.maps.state.session!;
      first.maps.adoptEditedSession(
        OpenedMapSession(
          extractedMap: initial.extractedMap,
          rawDocument: doc,
          metadataViews: initial.metadataViews,
          stringViews: initial.stringViews,
          terrainViews: initial.terrainViews,
          objectViews: initial.objectViews,
          sourceFingerprint: initial.sourceFingerprint,
          diagnostics: initial.diagnostics,
          resourceEdits: {
            r'staredit\wav\test.wav': pcmSoundFixture(),
            r'staredit\wav\removed.wav': null,
          },
        ),
      );
      first.projects.create(
        EudProject(mapPath: r'C:\Maps\base.scx', mapSha256: 'a' * 64),
      );
      source.createUntitled(initialText: 'old');
      source.updateText('unsaved Korean text: 한글');
      await autosave.checkpoint();
      expect(autosave.lastError, isNull);
      expect(first.writes, 0);
      final id = store.values.keys.single;
      await autosave.dispose();

      final second = EudWorkspaceFixture(),
          secondSource = EudSourceController();
      final restarted = attach(second, secondSource, store, owner: 'restart');
      addTearDown(restarted.dispose);
      addTearDown(second.dispose);
      addTearDown(secondSource.dispose);
      await restarted.refresh();
      await restarted.restore(id);
      final restored = second.maps.state.session!;
      expect(restored.isDirty, isTrue);
      expect(restored.isNewMap, isTrue);
      expect(
        const RawChkEncoder().encode(restored.rawDocument),
        const RawChkEncoder().encode(doc),
      );
      expect(
        restored.resourceEdits[r'staredit\wav\test.wav'],
        pcmSoundFixture(),
      );
      expect(
        restored.resourceEdits.containsKey(r'staredit\wav\removed.wav'),
        isTrue,
      );
      expect(secondSource.state.document!.text, 'unsaved Korean text: 한글');
      expect(secondSource.state.document!.isDirty, isTrue);
      expect(second.projects.isDirty, isTrue);
      expect(second.projects.path, isNull);
      expect(second.maps.editHistory.canUndo, isFalse);
      expect(second.reads, isEmpty);
      expect(second.writes, 0);
      expect(store.values.containsKey(id), isTrue);
    },
  );

  test(
    'existing map fingerprint conflict and corrupt checkpoint leave all documents untouched',
    () async {
      final first = EudWorkspaceFixture(),
          source = EudSourceController(),
          store = MemoryRecoveryStore();
      final autosave = attach(first, source, store);
      addTearDown(autosave.dispose);
      addTearDown(first.dispose);
      addTearDown(source.dispose);
      await first.maps.open();
      source.createUntitled(initialText: 'preserve');
      await autosave.checkpoint();
      final id = store.values.keys.single;
      source.close(discardChanges: true);
      first.hash = 'b' * 64;
      final previous = first.maps.state.session;
      await expectLater(autosave.restore(id), throwsStateError);
      expect(autosave.lastError, 'RECOVERY_SOURCE_CHANGED');
      expect(first.maps.state.session, same(previous));
      expect(source.state.document, isNull);
      first.hash = 'a' * 64;
      store.values['checkpoint-damaged'] = '{';
      await autosave.refresh();
      expect(autosave.candidates.where((c) => c.snapshot == null).length, 1);
      await expectLater(
        autosave.restore('checkpoint-damaged'),
        throwsFormatException,
      );
      expect(first.maps.state.session, same(previous));
      await autosave.restore(id);
      expect(source.state.document!.text, 'preserve');
      expect(first.maps.state.session!.sourceFingerprint, first.snapshot);
      expect(first.maps.state.session!.isDirty, isFalse);
      expect(first.writes, 0);
    },
  );

  test(
    'retains last good checkpoint on failure, serializes writes and skips brush transactions',
    () async {
      final first = EudWorkspaceFixture(),
          source = EudSourceController(),
          store = MemoryRecoveryStore();
      final autosave = attach(first, source, store);
      addTearDown(autosave.dispose);
      addTearDown(first.dispose);
      addTearDown(source.dispose);
      source.createUntitled(initialText: 'one');
      await autosave.checkpoint();
      final good = Map.of(store.values);
      source.updateText('two');
      store.fail = true;
      await autosave.checkpoint();
      expect(store.values, good);
      expect(autosave.lastError, 'AUTOSAVE_WRITE_FAILED');
      store.fail = false;
      store.pending = Completer<void>();
      final pending = autosave.checkpoint();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final repeated = autosave.checkpoint();
      source.updateText('three');
      store.pending!.complete();
      await Future.wait([pending, repeated]);
      store.pending = null;
      expect(store.values.length, 2);
      await autosave.checkpoint();
      expect(store.values.length, 3);
      expect(
        RecoverySnapshot.decode(store.values.values.last).source!.text,
        'three',
      );
      first.maps.editHistory.beginTransaction(first);
      source.updateText('four');
      await autosave.checkpoint();
      expect(store.values.length, 3);
      first.maps.editHistory.endTransaction(first);
      await autosave.checkpoint();
      expect(store.values.length, 4);
    },
  );

  test(
    'prunes only owned generations and clean state removes current backups',
    () async {
      final first = EudWorkspaceFixture(),
          source = EudSourceController(),
          store = MemoryRecoveryStore();
      final autosave = attach(first, source, store);
      addTearDown(autosave.dispose);
      addTearDown(first.dispose);
      addTearDown(source.dispose);
      store.values['checkpoint-other-window'] = 'unreadable';
      await autosave.configure(
        enabled: false,
        interval: const Duration(seconds: 5),
        retention: 2,
      );
      source.createUntitled();
      for (var i = 0; i < 4; i++) {
        source.updateText('$i');
        await autosave.checkpoint();
      }
      expect(store.values.length, 3);
      source.close(discardChanges: true);
      await autosave.checkpoint();
      expect(store.values.keys, ['checkpoint-other-window']);
    },
  );

  test(
    'dirty documents reject recovery and malformed settings use bounded defaults',
    () async {
      final first = EudWorkspaceFixture(),
          source = EudSourceController(),
          store = MemoryRecoveryStore();
      final autosave = attach(first, source, store);
      addTearDown(autosave.dispose);
      addTearDown(first.dispose);
      addTearDown(source.dispose);
      source.createUntitled();
      await autosave.checkpoint();
      await expectLater(
        autosave.restore(store.values.keys.single),
        throwsStateError,
      );
      expect(source.state.document!.text, '');
      await expectLater(
        autosave.configure(
          enabled: true,
          interval: Duration.zero,
          retention: 0,
        ),
        throwsArgumentError,
      );
    },
  );
}
