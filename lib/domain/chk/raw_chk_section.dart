import 'dart:typed_data';

class RawChkSection {
  factory RawChkSection({
    required List<int> nameBytes,
    required int declaredLength,
    required List<int> payload,
    required int sourceOffset,
    bool isDirty = false,
  }) {
    if (nameBytes.length != 4) {
      throw ArgumentError.value(
        nameBytes.length,
        'nameBytes',
        'A CHK section name must contain exactly 4 bytes.',
      );
    }
    _validateBytes(nameBytes, 'nameBytes');
    _validateBytes(payload, 'payload');
    if (declaredLength < 0 || declaredLength > 0xffffffff) {
      throw RangeError.range(declaredLength, 0, 0xffffffff, 'declaredLength');
    }
    if (declaredLength != payload.length) {
      throw ArgumentError(
        'The declared section length must match the payload length.',
      );
    }
    if (sourceOffset < 0) {
      throw RangeError.value(
        sourceOffset,
        'sourceOffset',
        'A source offset cannot be negative.',
      );
    }

    return RawChkSection._(
      nameBytes: Uint8List.fromList(nameBytes),
      declaredLength: declaredLength,
      payload: Uint8List.fromList(payload),
      sourceOffset: sourceOffset,
      isDirty: isDirty,
    );
  }

  RawChkSection._({
    required this._nameBytes,
    required this.declaredLength,
    required this._payload,
    required this.sourceOffset,
    required this.isDirty,
  });

  final Uint8List _nameBytes;
  final int declaredLength;
  final Uint8List _payload;
  final int sourceOffset;
  final bool isDirty;

  Uint8List get nameBytes => Uint8List.fromList(_nameBytes);

  Uint8List get payload => Uint8List.fromList(_payload);

  String get name {
    final result = StringBuffer();

    for (final byte in _nameBytes) {
      if (byte >= 0x20 && byte <= 0x7e) {
        result.writeCharCode(byte);
      } else {
        result
          ..write(r'\x')
          ..write(byte.toRadixString(16).padLeft(2, '0').toUpperCase());
      }
    }

    return result.toString();
  }

  RawChkSection withPayload(List<int> updatedPayload) {
    return RawChkSection(
      nameBytes: _nameBytes,
      declaredLength: updatedPayload.length,
      payload: updatedPayload,
      sourceOffset: sourceOffset,
      isDirty: true,
    );
  }
}

void _validateBytes(List<int> bytes, String argumentName) {
  for (var index = 0; index < bytes.length; index++) {
    final byte = bytes[index];
    if (byte < 0 || byte > 0xff) {
      throw RangeError.range(byte, 0, 0xff, '$argumentName[$index]');
    }
  }
}
