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
}
