import 'dart:convert';

/// Reversible text notation: `<HH>` is one byte; `<<` is a literal '<'.
/// Non-UTF8 runs remain byte tokens instead of replacement characters.
abstract final class ChkStringTokens {
  static String encode(List<int> bytes) {
    final out = StringBuffer();
    var i = 0;
    while (i < bytes.length) {
      final b = bytes[i];
      RangeError.checkValueInInterval(b, 1, 255, 'string byte');
      final width = b < 0x80
          ? 1
          : b >= 0xc2 && b <= 0xdf
          ? 2
          : b >= 0xe0 && b <= 0xef
          ? 3
          : b >= 0xf0 && b <= 0xf4
          ? 4
          : 0;
      String? text;
      if (width > 0 && i + width <= bytes.length && b >= 32 && b != 127) {
        try {
          text = utf8.decode(bytes.sublist(i, i + width));
        } on FormatException {
          // A malformed sequence is represented byte by byte.
        }
      }
      if (text != null) {
        out.write(text.replaceAll('<', '<<'));
        i += width;
      } else {
        out.write('<${b.toRadixString(16).padLeft(2, '0').toUpperCase()}>');
        i++;
      }
    }
    return out.toString();
  }

  static List<int> decode(String text) {
    final result = <int>[];
    var start = 0;
    var i = 0;
    while (i < text.length) {
      if (text[i] != '<') {
        i++;
        continue;
      }
      result.addAll(utf8.encode(text.substring(start, i)));
      if (i + 1 < text.length && text[i + 1] == '<') {
        result.add(60);
        i += 2;
      } else {
        if (i + 3 >= text.length ||
            !RegExp(r'^<[0-9a-fA-F]{2}>$').hasMatch(text.substring(i, i + 4))) {
          throw FormatException('Invalid byte token at $i.');
        }
        result.add(int.parse(text.substring(i + 1, i + 3), radix: 16));
        i += 4;
      }
      start = i;
    }
    result.addAll(utf8.encode(text.substring(start)));
    if (result.contains(0)) throw const FormatException('NUL is not allowed.');
    return List.unmodifiable(result);
  }
}
