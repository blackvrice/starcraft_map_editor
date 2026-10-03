import 'package:flutter/material.dart';
import 'package:re_highlight/re_highlight.dart';

const epScriptKeywords = <String>[
  'function',
  'var',
  'const',
  'if',
  'else',
  'for',
  'foreach',
  'while',
  'return',
  'break',
  'continue',
  'import',
  'as',
  'object',
  'static',
  'once',
  'switch',
  'case',
  'default',
];
const epScriptSymbols = <String>[
  ...epScriptKeywords,
  'onPluginStart',
  'beforeTriggerExec',
  'afterTriggerExec',
  'DisplayText',
  'CreateUnit',
  'SetResources',
  'SetDeaths',
  'SetMemory',
  'SetMemoryX',
  'SetCurrentPlayer',
  'EUDLoopUnit',
  'EUDArray',
  'EPD',
  'dwread_epd',
  'dwwrite_epd',
  'Always',
  'Command',
  'Accumulate',
  'Deaths',
  'Memory',
  'P1',
  'P2',
  'P3',
  'P4',
  'P5',
  'P6',
  'P7',
  'P8',
  'AllPlayers',
  'CurrentPlayer',
  'AtLeast',
  'AtMost',
  'Exactly',
  'SetTo',
  'Add',
  'Subtract',
  'Ore',
  'Gas',
  'All',
  r'$P1',
  r'$P2',
  r'$P3',
  r'$P4',
  r'$P5',
  r'$P6',
  r'$P7',
  r'$P8',
];
const epScriptStarter =
    'function onPluginStart() {\n'
    '    DisplayText("EUD script loaded.");\n}\n\n'
    'function beforeTriggerExec() {\n}\n\n'
    'function afterTriggerExec() {\n}\n';

/// Display grammar only. euddraft remains the authority for compilation.
class EpScriptTextController extends TextEditingController {
  EpScriptTextController({super.text});
  static const keywordColor = Color(0xFFC792EA);
  static const commentColor = Color(0xFF80968A);
  static const stringColor = Color(0xFFC3D98B);
  static final _highlight = Highlight()
    ..registerLanguage(
      'eps',
      Mode(
        keywords: {
          r'$pattern': r'[A-Za-z_$][A-Za-z0-9_$]*',
          'keyword': epScriptKeywords.join(' '),
          'built_in': epScriptSymbols
              .where((s) => !epScriptKeywords.contains(s))
              .join(' '),
          'literal': 'true false null',
        },
        contains: [
          Mode(scope: 'comment', begin: r'//', end: r'$'),
          Mode(scope: 'comment', begin: r'/\*', end: r'\*/'),
          Mode(
            scope: 'string',
            begin: '"',
            end: '"',
            contains: [Mode(begin: r'\\[\s\S]')],
          ),
          Mode(
            scope: 'string',
            begin: "'",
            end: "'",
            contains: [Mode(begin: r'\\[\s\S]')],
          ),
          Mode(scope: 'number', begin: r'\b(0x[0-9a-fA-F]+|\d+(\.\d+)?)\b'),
        ],
      ),
    );
  String? _cachedText;
  TextStyle? _cachedStyle;
  TextSpan? _cachedSpan;

  TextSpan syntaxSpan(TextStyle? style) {
    if (text.length > 200000) return TextSpan(text: text, style: style);
    if (_cachedText != text || _cachedStyle != style) {
      final renderer = TextSpanRenderer(style ?? const TextStyle(), const {
        'keyword': TextStyle(color: keywordColor),
        'comment': TextStyle(color: commentColor),
        'string': TextStyle(color: stringColor),
        'number': TextStyle(color: Color(0xFFFFC67A)),
        'built_in': TextStyle(color: Color(0xFF74CDE8)),
        'literal': TextStyle(color: Color(0xFFFFC67A)),
      });
      _highlight.highlight(code: text, language: 'eps').render(renderer);
      _cachedSpan = renderer.span ?? TextSpan(text: text, style: style);
      _cachedText = text;
      _cachedStyle = style;
    }
    return _cachedSpan!;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // Preserve Flutter's composing underline and IME range exactly.
    if (withComposing &&
        value.composing.isValid &&
        !value.composing.isCollapsed) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    return syntaxSpan(style);
  }

  ({int start, String prefix})? get completionRange {
    if (!selection.isValid ||
        !selection.isCollapsed ||
        !value.composing.isCollapsed) {
      return null;
    }
    final cursor = selection.baseOffset;
    final before = text.substring(0, cursor);
    final match = RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*$').firstMatch(before);
    if (match == null) return null;
    var offset = 0;
    Color? cursorColor;
    void visit(InlineSpan span, Color? inherited) {
      if (span is! TextSpan) return;
      final color = span.style?.color ?? inherited;
      final end = offset + (span.text?.length ?? 0);
      if (offset <= cursor - 1 && cursor - 1 < end) cursorColor = color;
      offset = end;
      for (final child in span.children ?? <InlineSpan>[]) {
        visit(child, color);
      }
    }

    visit(syntaxSpan(null), null);
    if (cursorColor == commentColor || cursorColor == stringColor) return null;
    return (start: match.start, prefix: match.group(0)!);
  }

  List<String> get completions {
    final range = completionRange;
    if (range == null || range.prefix.length < 2) return const [];
    return epScriptSymbols
        .where((s) => s.startsWith(range.prefix) && s != range.prefix)
        .take(8)
        .toList();
  }

  void complete(String symbol) {
    final range = completionRange;
    if (range == null || !epScriptSymbols.contains(symbol)) return;
    final end = selection.baseOffset;
    value = TextEditingValue(
      text: text.replaceRange(range.start, end, symbol),
      selection: TextSelection.collapsed(offset: range.start + symbol.length),
    );
  }
}
