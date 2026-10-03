import 'dart:io';
import 'dart:typed_data';

import 'package:starcraft_map_editor/domain/chk/raw_chk_encoder.dart';
import 'package:starcraft_map_editor/domain/chk/raw_chk_parser.dart';

// Synthetic unknown-section bytes only; no game assets or third-party maps.
void main() {
  for (final mib in [1, 16, 64]) {
    final payloadLength = mib * 1024 * 1024;
    final input = Uint8List(payloadLength + RawChkParser.headerLength);
    input.setRange(0, 4, 'TEST'.codeUnits);
    ByteData.sublistView(input).setUint32(4, payloadLength, Endian.little);
    input[input.length - 1] = 255;
    final timer = Stopwatch()..start();
    final parsed = const RawChkParser().parse(input);
    timer.stop();
    if (!parsed.isSuccess) throw StateError('Synthetic CHK parse failed.');
    final parseUs = timer.elapsedMicroseconds;
    timer.reset();
    timer.start();
    final encoded = const RawChkEncoder().encode(parsed.document!);
    timer.stop();
    if (encoded.length != input.length || encoded.last != 255) {
      throw StateError('Synthetic round trip failed.');
    }
    for (var i = 0; i < input.length; i++) {
      if (encoded[i] != input[i]) throw StateError('Byte mismatch at $i');
    }
    stdout.writeln(
      'CHK_AUDIT mib=$mib parseUs=$parseUs encodeUs=${timer.elapsedMicroseconds} byteExact=true',
    );
  }
}
