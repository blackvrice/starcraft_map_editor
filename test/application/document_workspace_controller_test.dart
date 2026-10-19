import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/document_workspace_controller.dart';
import 'package:starcraft_map_editor/application/documents/recovery_snapshot.dart';
import 'package:starcraft_map_editor/application/documents/save_map_controller.dart';
import 'package:starcraft_map_editor/application/editing/basic_editing_controller.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_controller.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/chk_mixed_clipboard.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';
import '../fixtures/multi_map_fixture.dart';

void main() {
  late MultiMapFixture f;
  setUp(() => f = MultiMapFixture());
  tearDown(() => f.dispose());
  test(
    'inactive source tab prevents map workspace from closing without consent',
    () async {
      final map = f.addMap();
      map.sources.newTab(fileName: 'draft.eps', initialText: 'unsaved');
      map.sources.newTab(fileName: 'clean.py');
      map.sources.markSaved(sourcePath: r'C:\Project\clean.py');
      expect(map.sources.state.document!.isDirty, isFalse);
      expect(map.dirty, isTrue);
      expect(
        await f.workspace.close(map, expectedRevision: map.revision),
        isFalse,
      );
      expect(f.workspace.documents, contains(map));
    },
  );
  test(
    'resource import belongs to A and prevents closing A while B stays editable',
    () async {
      final a = f.addMap(), b = f.addMap();
      final beforeB = b.maps.state.session;
      final pending = Completer<({String name, List<int> bytes})?>();
      f.resources.pending = pending;
      final read = a.value.objectEditingController.importSound();
      expect(a.busy, isTrue);
      expect(b.busy, isFalse);
      expect(
        await f.workspace.close(
          a,
          expectedRevision: a.revision,
          discardChanges: true,
        ),
        isFalse,
      );
      f.workspace.activate(b.id);
      pending.complete(null);
      await read;
      expect(a.busy, isFalse);
      expect(b.maps.state.session, same(beforeB));
    },
  );
  test(
    'dirty maps retain independent Undo, selections, layer policy, source/project and clipboard',
    () async {
      final a = f.addMap(), b = f.addMap(tile: 2);
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
      final beforeB = b.maps.state.session;
      ea.setStartLocation(player: 0, x: 96, y: 96);
      a.value.mapLayerController.setLocked(MapLayerType.locations, true);
      a.sources.createUntitled(initialText: 'A source');
      b.sources.createUntitled(initialText: 'B source');
      a.projects!.projects.create(
        EudProject(mapPath: r'C:\Maps\a.scx', mapSha256: 'a' * 64),
      );
      ea.mixedClipboard.capture(
        region: ClipboardRegion(0, 0, 3, 1),
        profile: MixedClipboardProfile.raw,
        kinds: {},
        overlays: {},
      );
      expect(eb.mixedClipboard.clipboard, isNull);
      final snapshot = const RawChkEncoder().encode(ea.source.rawDocument);
      for (var i = 0; i < 4; i++) {
        f.workspace.activate(a.id);
        f.workspace.activate(b.id);
      }
      expect(b.maps.state.session, same(beforeB));
      expect(a.maps.editHistory.undoDepth, 1);
      expect(b.maps.editHistory.undoDepth, 0);
      expect(const RawChkEncoder().encode(ea.source.rawDocument), snapshot);
      expect(
        a.value.mapLayerController.state
            .statusOf(MapLayerType.locations)
            .isLocked,
        isTrue,
      );
      expect(a.sources.state.document!.text, 'A source');
      expect(b.sources.state.document!.text, 'B source');
      expect(a.maps.editHistory.undo(), isTrue);
      expect(b.maps.state.session, same(beforeB));
    },
  );
  test(
    'duplicate Windows paths select existing document; failed open preserves all existing maps',
    () async {
      final a = await f.workspace.open(path: r'C:\Maps\A.scx');
      expect(await f.workspace.open(path: r'c:\maps\folder\..\a.scx'), same(a));
      f.paths.aliases[r'c:\maps\hardlink.scx'] = r'c:\maps\a.scx';
      expect(await f.workspace.open(path: r'C:\Maps\hardlink.scx'), same(a));
      expect(f.fakeArchive.opened.length, 1);
      expect(f.workspace.documents.length, 1);
      f.fakeArchive.fail = true;
      await expectLater(
        f.workspace.open(path: r'C:\Maps\broken.scx'),
        throwsStateError,
      );
      expect(f.workspace.active, same(a));
      expect(f.workspace.documents, [a]);
      expect(f.disposed.length, 1);
    },
  );
  test('a late open cannot steal focus after the user switches maps', () async {
    final a = f.addMap(), b = f.addMap(tile: 2);
    final pending = Completer<void>();
    f.fakeArchive.pending = pending;
    final open = f.workspace.open(path: r'C:\Maps\late.scx');
    while (f.fakeArchive.opened.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    f.workspace.activate(a.id);
    pending.complete();
    final lateMap = await open;
    expect(f.workspace.active, same(a));
    expect(f.workspace.documents, [a, b, lateMap]);
  });
  test(
    'output reservations are serialized across aliases and block close until released',
    () async {
      final a = f.addMap(), b = f.addMap();
      final lease = await f.workspace.reserve(
        a.id,
        r'C:\Maps\out.scx',
        purpose: WorkspacePathPurpose.mapOutput,
      );
      await expectLater(
        f.workspace.reserve(
          b.id,
          r'c:\maps\out.scx',
          purpose: WorkspacePathPurpose.buildOutput,
        ),
        throwsStateError,
      );
      await expectLater(
        f.workspace.reserve(
          a.id,
          r'C:\Maps\out.scx',
          purpose: WorkspacePathPurpose.mapOutput,
        ),
        throwsStateError,
      );
      expect(
        await f.workspace.close(
          a,
          expectedRevision: a.revision,
          discardChanges: true,
        ),
        isFalse,
      );
      lease.release();
      lease.release();
      final next = await f.workspace.reserve(
        b.id,
        r'C:\Maps\out.scx',
        purpose: WorkspacePathPurpose.mapOutput,
      );
      next.release();
      expect(
        await f.workspace.close(
          a,
          expectedRevision: a.revision,
          discardChanges: true,
        ),
        isTrue,
      );
      expect(f.workspace.active, same(b));
      expect(() => lease.validate(), throwsStateError);
    },
  );
  test(
    'Save As cannot touch another opened source or its hard-link alias',
    () async {
      final a = (await f.workspace.open(path: r'C:\Maps\A.scx'))!,
          b = f.addMap();
      f.paths.aliases[r'c:\maps\alias.scx'] = r'c:\maps\a.scx';
      final before = a.maps.state.session;
      final result = await b.saves.saveAs(
        destinationPath: r'C:\Maps\alias.scx',
        replaceExisting: true,
      );
      expect(result.status, SaveMapStatus.failed);
      expect(f.paths.writes, 0);
      expect(a.maps.state.session, same(before));
    },
  );
  test(
    'context changes during asynchronous path comparison reject rather than admit a stale reservation',
    () async {
      final a = (await f.workspace.open(path: r'C:\Maps\A.scx'))!,
          b = f.addMap();
      var once = true;
      f.paths.beforeCompare = () async {
        if (once) {
          once = false;
          a.sources.createUntitled(initialText: 'new input');
        }
      };
      await expectLater(
        f.workspace.reserve(
          b.id,
          r'C:\Maps\output.scx',
          purpose: WorkspacePathPurpose.mapOutput,
        ),
        throwsStateError,
      );
    },
  );
  test(
    'confirmation revision, transactions and capacity are enforced without discarding documents',
    () async {
      final a = f.addMap(), b = f.addMap();
      final revision = a.revision;
      a.sources.createUntitled(initialText: 'changed');
      expect(
        await f.workspace.close(
          a,
          expectedRevision: revision,
          discardChanges: true,
        ),
        isFalse,
      );
      expect(await f.workspace.close(a, expectedRevision: a.revision), isFalse);
      f.workspace.activate(a.id);
      final owner = Object();
      a.maps.editHistory.beginTransaction(owner);
      expect(() => f.workspace.activate(b.id), throwsStateError);
      a.maps.editHistory.endTransaction(owner);
      for (var i = 0; i < 6; i++) {
        f.addMap();
      }
      expect(() => f.addMap(), throwsStateError);
      expect(f.workspace.documents.length, 8);
    },
  );
  test(
    'independent recovery owners, active checkpoint protection and background restore preserve B',
    () async {
      final a = f.addMap(), b = f.addMap(tile: 2);
      final beforeB = b.maps.state.session;
      await a.autosave!.checkpoint();
      await b.autosave!.checkpoint();
      expect(f.memoryRecovery.values.length, 2);
      final checkpoint = f.memoryRecovery.values.keys.firstWhere(
        (id) => a.autosave!.ownsCheckpoint(id),
      );
      expect(
        RecoverySnapshot.decode(f.memoryRecovery.values[checkpoint]!).map,
        isNotNull,
      );
      final recovery = f.workspace.prepareDocument();
      await expectLater(
        recovery.autosave!.restore(checkpoint),
        throwsStateError,
      );
      await expectLater(
        recovery.autosave!.remove(checkpoint),
        throwsStateError,
      );
      expect(
        await f.workspace.close(
          a,
          expectedRevision: a.revision,
          discardChanges: true,
        ),
        isTrue,
      );
      await recovery.autosave!.restore(checkpoint);
      f.workspace.publish(recovery, activate: false);
      expect(f.workspace.active, same(b));
      expect(b.maps.state.session, same(beforeB));
      expect(
        recovery.maps.state.session!.rawDocument.sections.first.name,
        a.maps.state.session!.rawDocument.sections.first.name,
      );
    },
  );
  test(
    'background build result and output leases belong only to the originating document',
    () async {
      final a = f.addMap(), b = f.addMap(tile: 2);
      a.builds.prepare(workspacePlan('A'));
      final running = a.builds.start();
      while (f.builds[a.id]!.started == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      f.workspace.activate(b.id);
      b.builds.prepare(workspacePlan('B'));
      expect(await b.builds.start(), isFalse);
      expect(f.builds[b.id]!.started, 0);
      expect(
        await f.workspace.close(
          a,
          expectedRevision: a.revision,
          discardChanges: true,
        ),
        isFalse,
      );
      f.builds[a.id]!.completion.complete(true);
      expect(await running, isTrue);
      expect(a.builds.state.status, EudBuildStatus.succeeded);
      expect(b.builds.state.status, EudBuildStatus.failed);
      expect(f.workspace.active, same(b));
      expect(a.builds.state.records.length, 1);
      expect(
        (await f.workspace.reserve(
          b.id,
          r'C:\Maps\output.scx',
          purpose: WorkspacePathPurpose.mapOutput,
        ))..release(),
        isNotNull,
      );
    },
  );
  test('immediate build cancellation never starts a queued compiler', () async {
    final a = f.addMap();
    a.builds.prepare(workspacePlan('cancel-queued'));
    final running = a.builds.start();
    expect(await a.builds.cancel(), isTrue);
    expect(await running, isFalse);
    expect(a.builds.state.status, EudBuildStatus.cancelled);
    expect(f.builds[a.id]!.started, 0);
  });
  test(
    'running build cancellation releases its output only after stream completion',
    () async {
      final a = f.addMap(), b = f.addMap();
      a.builds.prepare(workspacePlan('cancel-running'));
      final running = a.builds.start();
      while (f.builds[a.id]!.started == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(await a.builds.cancel(), isTrue);
      expect(await running, isFalse);
      expect(a.builds.state.status, EudBuildStatus.cancelled);
      final lease = await f.workspace.reserve(
        b.id,
        r'C:\Maps\output.scx',
        purpose: WorkspacePathPurpose.mapOutput,
      );
      lease.release();
    },
  );
}
