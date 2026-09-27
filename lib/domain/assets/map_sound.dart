import 'dart:typed_data';

abstract final class MapSound {
  static const maximumBytes = 16 * 1024 * 1024;
  static String path(String value) {
    final p = value.replaceAll('/', '\\');
    if (p.length > 240 ||
        !RegExp(
          r'^[A-Za-z0-9_ .\-\\]+\.wav$',
          caseSensitive: false,
        ).hasMatch(p) ||
        p
            .split('\\')
            .any(
              (s) =>
                  s.isEmpty ||
                  s == '.' ||
                  s == '..' ||
                  s.endsWith(' ') ||
                  s.endsWith('.'),
            )) {
      throw const FormatException(
        'Use a relative ASCII .wav archive path without empty or parent segments.',
      );
    }
    return p;
  }

  static void validate(List<int> raw) {
    if (raw.length < 44 || raw.length > maximumBytes) {
      throw const FormatException('WAV must be 44 bytes to 16 MiB.');
    }
    final bytes = Uint8List.fromList(raw),
        data = ByteData.sublistView(Uint8List.fromList(raw));
    String tag(int i) => String.fromCharCodes(bytes.sublist(i, i + 4));
    if (tag(0) != 'RIFF' ||
        tag(8) != 'WAVE' ||
        data.getUint32(4, Endian.little) + 8 != bytes.length) {
      throw const FormatException('Invalid RIFF/WAVE envelope.');
    }
    bool format = false, audio = false;
    var alignment = 0;
    var p = 12;
    for (; p + 8 <= bytes.length;) {
      final n = data.getUint32(p + 4, Endian.little);
      if (p + 8 + n > bytes.length) {
        throw const FormatException('Truncated WAV chunk.');
      }
      if (tag(p) == 'fmt ') {
        if (n < 16 || format) {
          throw const FormatException('Invalid WAV format chunk.');
        }
        final channels = data.getUint16(p + 10, Endian.little),
            rate = data.getUint32(p + 12, Endian.little),
            bits = data.getUint16(p + 22, Endian.little);
        alignment = channels * bits ~/ 8;
        if (data.getUint16(p + 8, Endian.little) != 1 ||
            !{1, 2}.contains(channels) ||
            !{8, 16}.contains(bits) ||
            rate < 8000 ||
            rate > 48000 ||
            data.getUint16(p + 20, Endian.little) != alignment ||
            data.getUint32(p + 16, Endian.little) != rate * alignment) {
          throw const FormatException(
            'Import supports PCM WAV, mono/stereo, 8/16-bit, 8–48 kHz.',
          );
        }
        format = true;
      }
      if (tag(p) == 'data') {
        if (!format || audio || n == 0 || n % alignment != 0) {
          throw const FormatException('Invalid WAV data chunk.');
        }
        audio = true;
      }
      p += 8 + n + (n & 1);
      if (p > bytes.length) {
        throw const FormatException('Missing chunk padding.');
      }
    }
    if (p != bytes.length) {
      throw const FormatException('Trailing partial WAV chunk.');
    }
    if (!format || !audio) {
      throw const FormatException('WAV format/data is missing.');
    }
  }
}
