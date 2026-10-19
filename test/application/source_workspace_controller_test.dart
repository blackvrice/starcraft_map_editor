import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/eud/eud_source_controller.dart';
import 'package:starcraft_map_editor/application/documents/recovery_snapshot.dart';
import 'package:starcraft_map_editor/application/ports/trigger_script_gateway.dart';
import 'package:starcraft_map_editor/domain/triggers/trigger_script_syntax.dart';
import '../fixtures/source_workspace_fixture.dart';

class _NewFiles implements TriggerScriptFiles {
  _NewFiles(this.workspace);
  final MemorySourceWorkspace workspace;
  bool outside = false, changed = false;
  @override
  Future<TriggerScriptFile?> open() async => null;
  @override
  Future<String?> saveNew(String text, TriggerScriptLanguage language) async {
    workspace.text['new.${language.extension}'] = changed
        ? 'external edit'
        : text;
    return outside
        ? r'C:\Outside\new.eps'
        : workspace.file('new.${language.extension}').path;
  }
}

void main() {
  late MemorySourceWorkspace files;
  late EudSourceController controller;
  setUp(() {
    files = MemorySourceWorkspace();
    controller = EudSourceController(workspaceGateway: files);
  });
  tearDown(() => controller.dispose());
  test(
    'workspace Save As verifies bytes before adopting path and preserves outside copies',
    () async {
      final io = _NewFiles(files);
      final source = EudSourceController(workspaceGateway: files, files: io);
      addTearDown(source.dispose);
      await source.chooseWorkspace();
      source.newTab(initialText: 'original draft');
      io.outside = true;
      await expectLater(source.saveNew(), throwsStateError);
      expect(source.state.document!.isUntitled, isTrue);
      expect(source.state.document!.text, 'original draft');
      io.outside = false;
      io.changed = true;
      await expectLater(source.saveNew(), throwsStateError);
      expect(source.state.document!.isUntitled, isTrue);
      io.changed = false;
      await source.saveNew();
      expect(source.state.document!.isUntitled, isFalse);
      expect(source.hasUnsaved, isFalse);
      expect(
        source.workspaceFiles.map((f) => f.relativePath),
        contains('new.eps'),
      );
    },
  );
  test('invalid replacement keeps all old document state intact', () {
    controller.open(sourcePath: r'C:\Project\main.eps', text: 'old');
    final old = controller.state.document;
    expect(
      () => controller.open(sourcePath: 'relative.eps', text: 'bad'),
      throwsArgumentError,
    );
    expect(controller.state.document, same(old));
    expect(controller.documents.single, same(old));
  });
  test(
    'independent tabs preserve dirty text and complete imported symbols',
    () async {
      await controller.chooseWorkspace();
      await controller.openRelative('main.eps');
      final first = controller.state.document!;
      controller.updateText('${first.text}\nconst Draft=1;');
      await controller.openRelative('util.eps');
      expect(controller.documents, hasLength(2));
      expect(controller.hasUnsaved, isTrue);
      expect(controller.state.document!.isDirty, isFalse);
      expect(controller.closeTab(first.documentId), isFalse);
      controller.activate(first.documentId);
      expect(controller.state.document!.text, contains('Draft'));
      await controller.rebuildIndex();
      expect(controller.index!.completions('main.eps'), contains('util.Work'));
      await controller.saveActive();
      expect(controller.hasUnsaved, isFalse);
      expect(files.text['main.eps'], contains('Draft'));
    },
  );
  test(
    'external edits never replace a dirty tab and block overwrite',
    () async {
      await controller.chooseWorkspace();
      await controller.openRelative('main.eps');
      controller.updateText('my draft');
      files.text['main.eps'] = 'external';
      await controller.refreshWorkspace();
      expect(controller.state.document!.text, 'my draft');
      expect(
        controller.conflicts,
        contains(controller.state.document!.documentId),
      );
      await expectLater(controller.saveActive(), throwsStateError);
      await expectLater(controller.reloadActive(), throwsStateError);
      await controller.reloadActive(discardChanges: true);
      expect(controller.state.document!.text, 'external');
      expect(controller.conflicts, isEmpty);
    },
  );
  test('late save preserves edits made while writing', () async {
    await controller.chooseWorkspace();
    await controller.openRelative('main.eps');
    controller.updateText('save me');
    files.pending = Completer();
    final saving = controller.saveActive();
    await Future<void>.delayed(Duration.zero);
    controller.updateText('newer');
    expect(
      controller.closeTab(
        controller.state.document!.documentId,
        discardChanges: true,
      ),
      isFalse,
    );
    files.pending!.complete();
    await saving;
    expect(files.text['main.eps'], 'save me');
    expect(controller.state.document!.text, 'newer');
    expect(controller.hasUnsaved, isTrue);
    expect(controller.conflicts, isEmpty);
  });
  test(
    'all tabs and root roundtrip without filesystem access on restore',
    () async {
      await controller.chooseWorkspace();
      await controller.openRelative('main.eps');
      controller.updateText('unsaved eps');
      await controller.openRelative('data.lua');
      controller.updateText('unsaved lua');
      controller.newTab(fileName: 'new.py', initialText: 'pending python');
      final encoded = RecoverySnapshot(
        savedAt: DateTime.utc(2026),
        sourceWorkspace: controller.recovery,
      ).encode();
      final snapshot = RecoverySnapshot.decode(encoded);
      expect(snapshot.sourceWorkspace!.documents, hasLength(3));
      final restored = EudSourceController(workspaceGateway: files);
      addTearDown(restored.dispose);
      final reads = files.reads, scans = files.scans;
      restored.restoreWorkspace(snapshot.sourceWorkspace!);
      expect(files.reads, reads);
      expect(files.scans, scans);
      expect(restored.workspaceVerified, isFalse);
      expect(restored.hasUnsaved, isTrue);
      expect(restored.documents.map((d) => d.text), [
        'unsaved eps',
        'unsaved lua',
        'pending python',
      ]);
      expect(restored.state.document!.fileName, 'new.py');
      await expectLater(restored.openRelative('main.eps'), throwsStateError);
      await restored.refreshWorkspace();
      expect(restored.workspaceVerified, isTrue);
    },
  );
  test(
    'diagnostic navigation stays in indexed root with exact line/column',
    () async {
      await controller.chooseWorkspace();
      await controller.navigate('pkg/util.py', 2, column: 5);
      expect(controller.state.document!.fileName, 'util.py');
      expect(controller.focusRequest!.offset, 'def Work():\n    '.length);
      await expectLater(
        controller.navigate(r'C:\Outside\util.py', 1),
        throwsStateError,
      );
      await expectLater(controller.navigate('util', 1), throwsStateError);
      await expectLater(
        controller.navigate('pkg/util.py', 99),
        throwsStateError,
      );
    },
  );
  test(
    'build verifies the entire root, dirty inactive tabs and imports',
    () async {
      await controller.chooseWorkspace();
      await controller.openRelative('main.eps');
      await controller.validateForBuild(
        files.chosen,
        files.file('main.eps').path,
      );
      await controller.openRelative('util.eps');
      controller.updateText('dirty');
      await controller.openRelative('main.eps');
      await expectLater(
        controller.validateForBuild(files.chosen, files.file('main.eps').path),
        throwsStateError,
      );
      expect(controller.state.document!.isDirty, isFalse);
      await expectLater(
        controller.openWorkspace(r'C:\Other'),
        throwsStateError,
      );
    },
  );
}
