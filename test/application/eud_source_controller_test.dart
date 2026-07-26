import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/eud/eud_source_controller.dart';

void main() {
  group('EudSourceController', () {
    test('creates one clean untitled epScript document', () {
      final controller = EudSourceController();
      addTearDown(controller.dispose);

      expect(controller.createUntitled(), isTrue);
      expect(controller.createUntitled(), isFalse);

      final document = controller.state.document!;
      expect(document.documentId, 'untitled-1');
      expect(document.fileName, 'main.eps');
      expect(document.sourcePath, isNull);
      expect(document.text, isEmpty);
      expect(document.revision, 0);
      expect(document.isDirty, isFalse);
      expect(document.isUntitled, isTrue);
      expect(document.lineCount, 1);
    });

    test('tracks revisions and dirty state against the saved text', () {
      final controller = EudSourceController();
      addTearDown(controller.dispose);
      controller.open(
        sourcePath: r'C:\Project\src\main.eps',
        text: 'const base = 1;\n',
      );

      controller.updateText('const base = 2;\n');
      expect(controller.state.document!.revision, 1);
      expect(controller.state.document!.isDirty, isTrue);
      expect(controller.state.document!.lineCount, 2);

      controller.updateText('const base = 1;\n');
      expect(controller.state.document!.revision, 2);
      expect(controller.state.document!.isDirty, isFalse);
    });

    test('emits only real text changes', () async {
      final controller = EudSourceController();
      addTearDown(controller.dispose);
      controller.createUntitled();
      final emitted = <EudSourceState>[];
      final subscription = controller.changes.listen(emitted.add);
      addTearDown(subscription.cancel);

      controller.updateText('');
      controller.updateText('function onPluginStart() {}\n');

      expect(emitted, hasLength(1));
      expect(emitted.single.document!.revision, 1);
    });

    test('requires an absolute eps path for opened and saved documents', () {
      final controller = EudSourceController();
      addTearDown(controller.dispose);

      expect(
        () => controller.open(sourcePath: 'src/main.eps', text: ''),
        throwsArgumentError,
      );
      controller.createUntitled();
      expect(controller.markSaved, throwsStateError);
      expect(
        () => controller.markSaved(sourcePath: r'C:\Project\src\main.txt'),
        throwsArgumentError,
      );

      controller.markSaved(sourcePath: r'C:\Project\src\main.eps');
      expect(controller.state.document!.sourcePath, r'C:\Project\src\main.eps');
      expect(controller.state.document!.isDirty, isFalse);
    });

    test('protects dirty text from implicit replacement or close', () {
      final controller = EudSourceController();
      addTearDown(controller.dispose);
      controller.createUntitled();
      controller.updateText('dirty');

      expect(
        controller.open(
          sourcePath: r'C:\Project\src\other.eps',
          text: 'replacement',
        ),
        isFalse,
      );
      expect(controller.close(), isFalse);
      expect(controller.state.document!.text, 'dirty');

      expect(controller.close(discardChanges: true), isTrue);
      expect(controller.state.document, isNull);
    });

    test('validates untitled names and document metadata', () {
      final controller = EudSourceController();
      addTearDown(controller.dispose);

      expect(
        () => controller.createUntitled(fileName: '../main.eps'),
        throwsArgumentError,
      );
      expect(
        () => controller.createUntitled(fileName: 'main.txt'),
        throwsArgumentError,
      );
    });
  });
}
