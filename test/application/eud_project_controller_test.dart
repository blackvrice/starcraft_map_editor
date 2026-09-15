import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/eud/eud_project_controller.dart';
import 'package:starcraft_map_editor/application/ports/eud_project_store.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';

class MemoryStore implements EudProjectStore {
  final files = <String, EudProject>{};
  bool fail = false;
  Completer<void>? pending;
  @override
  Future<EudProjectFile> read(String path) async {
    if (fail) throw const FormatException('bad file');
    return EudProjectFile(
      project: files[path]!,
      revision: files[path]!.encode(),
    );
  }

  @override
  Future<EudProjectFile> saveAs(String path, EudProject project) async {
    if (pending != null) await pending!.future;
    if (fail) throw StateError('disk failure');
    if (files.containsKey(path)) throw StateError('exists');
    files[path] = project;
    return EudProjectFile(project: project, revision: project.encode());
  }

  @override
  Future<EudProjectFile> save(
    String path,
    EudProject project, {
    required String expectedRevision,
  }) async {
    if (pending != null) await pending!.future;
    if (fail) throw StateError('disk failure');
    if (files[path]?.encode() != expectedRevision) {
      throw EudProjectConflict(path);
    }
    files[path] = project;
    return EudProjectFile(
      project: project,
      revision: project.encode(),
      backupPath: '$path.backup.bak',
    );
  }
}

void main() {
  late MemoryStore store;
  late EudProjectController controller;
  EudProject empty() =>
      EudProject(mapPath: r'C:\maps\base.scx', mapSha256: 'a' * 64);
  List<EudOverride> edits(int n) => [
    EudOverride(field: 'weapon.maxRange', targetId: 0, value: n),
  ];
  setUp(() {
    store = MemoryStore();
    controller = EudProjectController(store);
  });
  tearDown(() => controller.dispose());

  test(
    'Save uses the session revision, retains undo and refuses external changes',
    () async {
      controller.create(empty());
      await expectLater(controller.save(), throwsStateError);
      await controller.saveAs('project.eud.json');
      controller.replaceOverrides(edits(100));
      expect(controller.canSave, isTrue);
      await controller.save();
      expect(controller.isDirty, isFalse);
      expect(controller.backupPath, 'project.eud.json.backup.bak');
      controller.undo();
      expect(controller.isDirty, isTrue);
      controller.redo();
      expect(controller.isDirty, isFalse);
      store.files['project.eud.json'] = empty();
      controller.replaceOverrides(edits(200));
      await expectLater(controller.save(), throwsA(isA<EudProjectConflict>()));
      expect(controller.isDirty, isTrue);
      expect(controller.project!.overrides.single.value, 200);
      expect(store.files['project.eud.json']!.overrides, isEmpty);
      await controller.saveAs('copy.eud.json');
      expect(controller.isDirty, isFalse);
      expect(controller.backupPath, isNull);
    },
  );

  test('savepoint follows content across undo redo and reopening', () async {
    controller.create(empty());
    expect(controller.isDirty, isTrue);
    controller.replaceOverrides(edits(100));
    await controller.saveAs('first.eud.json');
    expect(controller.isDirty, isFalse);
    controller.replaceOverrides(edits(200));
    expect(controller.isDirty, isTrue);
    expect(controller.undo(), isTrue);
    expect(controller.isDirty, isFalse);
    expect(controller.redo(), isTrue);
    expect(controller.isDirty, isTrue);
    expect(controller.close(), isFalse);
    expect(await controller.open('first.eud.json'), isFalse);
    expect(
      await controller.open('first.eud.json', discardChanges: true),
      isTrue,
    );
    expect(controller.isDirty, isFalse);
    expect(controller.canUndo, isFalse);
    expect(controller.project!.overrides.single.value, 100);
  });

  test(
    'invalid batches and failed I/O preserve the document and dirty state',
    () async {
      controller.create(empty());
      controller.replaceOverrides(edits(100));
      final before = controller.project;
      expect(
        () => controller.replaceOverrides(edits(-1)),
        throwsFormatException,
      );
      expect(controller.project, same(before));
      store.fail = true;
      await expectLater(controller.saveAs('fail.eud.json'), throwsStateError);
      expect(controller.isDirty, isTrue);
      expect(controller.path, isNull);
      await expectLater(
        controller.open('bad.eud.json', discardChanges: true),
        throwsFormatException,
      );
      expect(controller.project, same(before));
      expect(controller.isBusy, isFalse);
    },
  );

  test(
    'pending save blocks edits close and replacement until completion',
    () async {
      controller.create(empty());
      store.pending = Completer<void>();
      final save = controller.saveAs('saved.eud.json');
      expect(controller.isBusy, isTrue);
      expect(controller.close(discardChanges: true), isFalse);
      expect(controller.create(empty(), discardChanges: true), isFalse);
      expect(() => controller.replaceOverrides(edits(1)), throwsStateError);
      expect(controller.undo(), isFalse);
      store.pending!.complete();
      await save;
      expect(controller.isDirty, isFalse);
    },
  );

  test('explicit map rebinding is undoable and new edits clear redo', () async {
    controller.create(empty());
    await controller.saveAs('first.eud.json');
    controller.rebindMap(mapPath: r'D:\moved.scx', mapSha256: 'b' * 64);
    expect(controller.isDirty, isTrue);
    controller.undo();
    expect(controller.isDirty, isFalse);
    expect(controller.project!.mapPath, r'C:\maps\base.scx');
    controller.replaceOverrides(edits(32));
    expect(controller.canRedo, isFalse);
    controller.replaceOverrides(edits(32));
    controller.undo();
    expect(controller.isDirty, isFalse);
  });
}
