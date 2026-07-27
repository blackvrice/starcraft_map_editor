import 'dart:typed_data';

import '../diagnostics/editor_diagnostic.dart';
import 'raw_chk_document.dart';
import 'raw_chk_parse_result.dart';
import 'raw_chk_section.dart';

abstract final class RawChkDiagnosticCodes {
  static const truncatedHeader = 'CHK_TRUNCATED_HEADER';
  static const sectionOutOfBounds = 'CHK_SECTION_OUT_OF_BOUNDS';
}

class RawChkParser {
  const RawChkParser();

  static const headerLength = 8;
  static const sectionNameLength = 4;

  RawChkParseResult parse(Uint8List source) {
    final sections = <RawChkSection>[];
    final bytes = ByteData.sublistView(source);
    var offset = 0;

    while (offset < source.length) {
      final remainingLength = source.length - offset;
      if (remainingLength < headerLength) {
        return RawChkParseResult.failure(
          EditorDiagnostic(
            code: RawChkDiagnosticCodes.truncatedHeader,
            message:
                'The CHK section header is truncated at byte offset $offset.',
            severity: DiagnosticSeverity.fatal,
            stage: DiagnosticStage.parse,
            byteOffset: offset,
            remediation:
                'Use an intact scenario.chk or open the map as read-only.',
            rawDetails:
                'sectionIndex=${sections.length}; '
                'availableHeaderBytes=$remainingLength; '
                'requiredHeaderBytes=$headerLength',
          ),
        );
      }

      final nameBytes = source.sublist(offset, offset + sectionNameLength);
      final sectionName = RawChkSection(
        nameBytes: nameBytes,
        declaredLength: 0,
        payload: const [],
        sourceOffset: offset,
      ).name;
      final declaredLength = bytes.getUint32(
        offset + sectionNameLength,
        Endian.little,
      );
      final payloadOffset = offset + headerLength;
      final availablePayloadLength = source.length - payloadOffset;

      // eudplib writes an eight-byte ISOM marker whose encoded length has the
      // signed high bit set. It has no physical payload and can precede
      // euddraft-added sections, so preserve the header and continue at the
      // next byte instead of treating the unsigned value as a payload length.
      if (_isEuddraftProtectionMarker(nameBytes, declaredLength)) {
        sections.add(
          RawChkSection.euddraftProtectionMarker(
            declaredLength: declaredLength,
            sourceOffset: offset,
          ),
        );
        offset = payloadOffset;
        continue;
      }

      if (declaredLength > availablePayloadLength) {
        return RawChkParseResult.failure(
          EditorDiagnostic(
            code: RawChkDiagnosticCodes.sectionOutOfBounds,
            message:
                'Section "$sectionName" declares $declaredLength bytes, '
                'but only $availablePayloadLength bytes remain.',
            severity: DiagnosticSeverity.fatal,
            stage: DiagnosticStage.parse,
            sectionName: sectionName,
            byteOffset: offset + sectionNameLength,
            remediation:
                'Use an intact scenario.chk or open the map as read-only.',
            rawDetails:
                'sectionIndex=${sections.length}; '
                'sectionOffset=$offset; '
                'declaredLength=$declaredLength; '
                'availablePayloadBytes=$availablePayloadLength',
          ),
        );
      }

      final nextOffset = payloadOffset + declaredLength;
      sections.add(
        RawChkSection(
          nameBytes: nameBytes,
          declaredLength: declaredLength,
          payload: source.sublist(payloadOffset, nextOffset),
          sourceOffset: offset,
        ),
      );
      offset = nextOffset;
    }

    return RawChkParseResult.success(
      RawChkDocument(sections: sections, sourceLength: source.length),
    );
  }

  bool _isEuddraftProtectionMarker(List<int> nameBytes, int declaredLength) {
    return declaredLength >= 0x80000000 &&
        nameBytes[0] == 0x49 &&
        nameBytes[1] == 0x53 &&
        nameBytes[2] == 0x4f &&
        nameBytes[3] == 0x4d;
  }
}
