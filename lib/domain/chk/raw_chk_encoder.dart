import 'dart:typed_data';

import 'raw_chk_document.dart';

class RawChkEncoder {
  const RawChkEncoder();

  Uint8List encode(RawChkDocument document) {
    final output = BytesBuilder(copy: false);

    for (final section in document.sections) {
      output.add(section.nameBytes);

      final lengthBytes = ByteData(4)
        ..setUint32(0, section.declaredLength, Endian.little);
      output.add(lengthBytes.buffer.asUint8List());
      output.add(section.payload);
    }

    return output.takeBytes();
  }
}
