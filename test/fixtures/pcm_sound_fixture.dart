import 'dart:typed_data';

/// Self-authored 10 ms of 8 kHz, unsigned 8-bit mono silence; no game assets.
Uint8List pcmSoundFixture() {
  final bytes = Uint8List(124);
  final data = ByteData.sublistView(bytes);
  bytes.setAll(0, 'RIFF'.codeUnits);
  data.setUint32(4, bytes.length - 8, Endian.little);
  bytes.setAll(8, 'WAVEfmt '.codeUnits);
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 8000, Endian.little);
  data.setUint32(28, 8000, Endian.little);
  data.setUint16(32, 1, Endian.little);
  data.setUint16(34, 8, Endian.little);
  bytes.setAll(36, 'data'.codeUnits);
  data.setUint32(40, 80, Endian.little);
  bytes.fillRange(44, bytes.length, 128);
  return bytes;
}
