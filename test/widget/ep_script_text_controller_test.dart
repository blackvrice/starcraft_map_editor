import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/presentation/eud_editor/ep_script_text_controller.dart';

void main() {
  test('highlights keywords, comments and strings without changing source', () {
    const source =
        'function start() { var x = 12; DisplayText("안녕"); }\n// var note\n/* const ignored */';
    final controller = EpScriptTextController(text: source);
    addTearDown(controller.dispose);
    final spans = <TextSpan>[];
    void visit(TextSpan span) {
      spans.add(span);
      for (final child in span.children ?? <InlineSpan>[]) {
        if (child is TextSpan) visit(child);
      }
    }

    visit(controller.syntaxSpan(const TextStyle(fontSize: 14)));
    expect(controller.syntaxSpan(null).toPlainText(), source);
    expect(
      spans.any(
        (s) =>
            s.text == 'function' &&
            s.style?.color == EpScriptTextController.keywordColor,
      ),
      isTrue,
    );
    expect(
      spans.any(
        (s) =>
            s.text?.contains('// var note') == true &&
            s.style?.color == EpScriptTextController.commentColor,
      ),
      isTrue,
    );
    expect(
      spans.any(
        (s) =>
            s.text?.contains('안녕') == true &&
            s.style?.color == EpScriptTextController.stringColor,
      ),
      isTrue,
    );
    expect(controller.text, source);
  });

  test(
    'completion preserves surrounding source and uses cursor prefix only',
    () {
      final controller = EpScriptTextController(text: '한글\nDis(); // keep');
      addTearDown(controller.dispose);
      controller.selection = const TextSelection.collapsed(offset: 6);
      expect(controller.completions, contains('DisplayText'));
      controller.complete('DisplayText');
      expect(controller.text, '한글\nDisplayText(); // keep');
      expect(controller.selection.baseOffset, 14);
      controller.value = const TextEditingValue(
        text: r'$P',
        selection: TextSelection.collapsed(offset: 2),
      );
      expect(controller.completions, contains(r'$P1'));
    },
  );

  for (final text in ['// Dis', '/* Dis */', '"Dis', "'Dis"]) {
    test('does not suggest inside $text', () {
      final controller = EpScriptTextController(text: text);
      addTearDown(controller.dispose);
      final offset = text.indexOf('Dis') + 3;
      controller.selection = TextSelection.collapsed(offset: offset);
      expect(controller.completions, isEmpty);
    });
  }

  testWidgets('IME underline and selected text are preserved', (tester) async {
    final controller = EpScriptTextController(text: 'Dis');
    addTearDown(controller.dispose);
    controller.value = const TextEditingValue(
      text: 'Dis',
      selection: TextSelection.collapsed(offset: 3),
      composing: TextRange(start: 0, end: 3),
    );
    expect(controller.completions, isEmpty);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            final span = controller.buildTextSpan(
              context: context,
              withComposing: true,
            );
            expect(span.toPlainText(), 'Dis');
            expect(
              (span.children![1] as TextSpan).style?.decoration,
              TextDecoration.underline,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    controller.value = const TextEditingValue(
      text: 'Dis',
      selection: TextSelection(baseOffset: 0, extentOffset: 3),
    );
    controller.complete('DisplayText');
    expect(controller.text, 'Dis');
  });

  test('large source falls back to plain text without loss', () {
    final source = List.filled(20001, 'var x = 1;').join();
    final controller = EpScriptTextController(text: source);
    addTearDown(controller.dispose);
    expect(controller.syntaxSpan(null).toPlainText(), source);
    expect(controller.syntaxSpan(null).children, isNull);
  });
}
