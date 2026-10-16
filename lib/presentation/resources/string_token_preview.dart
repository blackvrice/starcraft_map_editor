import 'dart:convert';
import 'package:flutter/material.dart';
import '../../domain/chk/typed/chk_string_tokens.dart';
import '../localization/l10n.dart';

/// Approximate editor colors, not game font rendering or palette emulation.
class StringTokenPreview extends StatelessWidget {
  const StringTokenPreview({
    required this.text,
    required this.tokens,
    super.key,
  });
  final String text;
  final bool tokens;
  static const colors = <int, Color>{
    1: Color(0xffb8b8e8),
    2: Color(0xffb8b8e8),
    3: Color(0xffdcdc3c),
    4: Color(0xffffffff),
    5: Color(0xff847474),
    6: Color(0xffc81818),
    7: Color(0xff10fc18),
    8: Color(0xfff40404),
    14: Color(0xff0c48cc),
    15: Color(0xff2cb494),
    16: Color(0xff84409c),
    17: Color(0xfff88c14),
    21: Color(0xff703014),
    22: Color(0xffcce0d0),
    23: Color(0xfffcfc38),
    24: Color(0xff088008),
    25: Color(0xfffcfc7c),
    26: Color(0xffb8b8e8),
    27: Color(0xffecc4b0),
    28: Color(0xff4068d4),
    29: Color(0xff74a47c),
    30: Color(0xff9090b8),
    31: Color(0xff00e4fc),
  };
  @override
  Widget build(BuildContext context) {
    List<int> raw;
    try {
      raw = tokens ? ChkStringTokens.decode(text) : utf8.encode(text);
    } catch (_) {
      return Text(context.l10n.settingsValueUnavailable);
    }
    final spans = <TextSpan>[];
    var color = colors[1]!;
    var run = <int>[];
    void flush() {
      if (run.isNotEmpty) {
        spans.add(
          TextSpan(
            text: utf8.decode(run, allowMalformed: true),
            style: TextStyle(color: color),
          ),
        );
      }
      run = [];
    }

    for (final b in raw) {
      if (colors.containsKey(b)) {
        flush();
        color = colors[b]!;
      } else if (b == 10 || b == 9 || b >= 32 && b != 127) {
        run.add(b);
      } else {
        flush();
        spans.add(
          TextSpan(
            text: '<${b.toRadixString(16).padLeft(2, '0').toUpperCase()}>',
            style: const TextStyle(color: Color(0xffaaaaaa)),
          ),
        );
      }
    }
    flush();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.l10n.stringTokenPreview),
        Container(
          key: const Key('string-token-preview'),
          color: const Color(0xff151515),
          padding: const EdgeInsets.all(12),
          child: SelectableText.rich(TextSpan(children: spans)),
        ),
      ],
    );
  }
}
