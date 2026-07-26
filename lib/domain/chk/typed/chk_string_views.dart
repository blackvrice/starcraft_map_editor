import 'dart:typed_data';

import '../../diagnostics/editor_diagnostic.dart';
import '../chk_section_names.dart';
import '../raw_chk_document.dart';
import '../raw_chk_parser.dart';
import '../raw_chk_section.dart';
import 'chk_typed_diagnostic_codes.dart';

typedef ChkStringDisplayDecoder = String Function(Uint8List rawBytes);

enum ChkStringTableKind {
  legacy(countFieldWidth: 2, offsetFieldWidth: 2, maximumOffset: 0xffff),
  extended(countFieldWidth: 4, offsetFieldWidth: 4, maximumOffset: 0xffffffff);

  const ChkStringTableKind({
    required this.countFieldWidth,
    required this.offsetFieldWidth,
    required this.maximumOffset,
  });

  final int countFieldWidth;
  final int offsetFieldWidth;
  final int maximumOffset;
}

final class ChkStringEntryView {
  ChkStringEntryView._({
    required this.stringId,
    required this.rawOffset,
    required this.pointsIntoHeader,
    required this.offsetInBounds,
    required this.isNullTerminated,
    required this._rawBytes,
  });

  final int stringId;
  final int rawOffset;
  final bool pointsIntoHeader;
  final bool offsetInBounds;
  final bool isNullTerminated;
  final Uint8List? _rawBytes;

  bool get isStructurallyValid =>
      offsetInBounds && !pointsIntoHeader && isNullTerminated;

  Uint8List? get rawBytes =>
      _rawBytes == null ? null : Uint8List.fromList(_rawBytes);

  String? decodeForDisplay(ChkStringDisplayDecoder decoder) {
    final bytes = rawBytes;
    return bytes == null ? null : decoder(bytes);
  }
}

final class ChkStringTableView {
  ChkStringTableView._({
    required this.sectionIndex,
    required this.rawSection,
    required this.kind,
    required this.declaredStringCount,
    required this.stringDataOffset,
    required List<ChkStringEntryView> entries,
    required List<EditorDiagnostic> diagnostics,
  }) : entries = List.unmodifiable(entries),
       diagnostics = List.unmodifiable(diagnostics);

  final int sectionIndex;
  final RawChkSection rawSection;
  final ChkStringTableKind kind;
  final int declaredStringCount;
  final int stringDataOffset;
  final List<ChkStringEntryView> entries;
  final List<EditorDiagnostic> diagnostics;

  bool get canAppendSafely =>
      !diagnostics.any((diagnostic) => diagnostic.blocksOperation);

  ChkStringEntryView? entryForId(int stringId) {
    if (stringId <= 0 || stringId > entries.length) {
      return null;
    }
    return entries[stringId - 1];
  }

  RawChkSection withAppendedRawString({
    required int stringId,
    required List<int> rawBytes,
  }) {
    if (!canAppendSafely) {
      throw StateError(
        'Cannot edit a string table that has blocking diagnostics.',
      );
    }
    if (declaredStringCount == 0) {
      throw RangeError.value(
        stringId,
        'stringId',
        'This string table contains no addressable string IDs.',
      );
    }
    if (stringId <= 0 || stringId > declaredStringCount) {
      throw RangeError.range(stringId, 1, declaredStringCount, 'stringId');
    }
    _validateStringBytes(rawBytes);

    final originalPayload = rawSection.payload;
    final appendedOffset = originalPayload.length;
    if (appendedOffset > kind.maximumOffset) {
      throw RangeError.range(
        appendedOffset,
        0,
        kind.maximumOffset,
        'appendedOffset',
      );
    }
    if (originalPayload.length + rawBytes.length + 1 > 0xffffffff) {
      throw RangeError(
        'The updated string table exceeds the CHK section size limit.',
      );
    }

    final updatedPayload = Uint8List(
      originalPayload.length + rawBytes.length + 1,
    )..setAll(0, originalPayload);
    updatedPayload.setAll(originalPayload.length, rawBytes);
    updatedPayload[updatedPayload.length - 1] = 0;

    final offsetFieldPosition =
        kind.countFieldWidth + (stringId - 1) * kind.offsetFieldWidth;
    final data = ByteData.sublistView(updatedPayload);
    if (kind == ChkStringTableKind.legacy) {
      data.setUint16(offsetFieldPosition, appendedOffset, Endian.little);
    } else {
      data.setUint32(offsetFieldPosition, appendedOffset, Endian.little);
    }

    return rawSection.withPayload(updatedPayload);
  }
}

final class ChkStringReference {
  const ChkStringReference(this.stringId);

  final int stringId;

  bool get isNone => stringId == 0;

  ChkStringEntryView? resolve(ChkStringTableView table) {
    return table.entryForId(stringId);
  }
}

final class ChkScenarioPropertiesView {
  ChkScenarioPropertiesView._({
    required this.sectionIndex,
    required this.rawSection,
  }) : scenarioName = ChkStringReference(
         _readUint16(rawSection.payload, offset: 0),
       ),
       scenarioDescription = ChkStringReference(
         _readUint16(rawSection.payload, offset: 2),
       );

  static const payloadLength = 4;

  final int sectionIndex;
  final RawChkSection rawSection;
  final ChkStringReference scenarioName;
  final ChkStringReference scenarioDescription;

  RawChkSection withReferences({
    int? scenarioNameStringId,
    int? scenarioDescriptionStringId,
  }) {
    final payload = Uint8List(payloadLength);
    final data = ByteData.sublistView(payload)
      ..setUint16(
        0,
        _checkUint16(
          scenarioNameStringId ?? scenarioName.stringId,
          'scenarioNameStringId',
        ),
        Endian.little,
      )
      ..setUint16(
        2,
        _checkUint16(
          scenarioDescriptionStringId ?? scenarioDescription.stringId,
          'scenarioDescriptionStringId',
        ),
        Endian.little,
      );
    return rawSection.withPayload(data.buffer.asUint8List());
  }
}

final class ChkStringViews {
  ChkStringViews({
    required List<ChkScenarioPropertiesView> scenarioProperties,
    required List<ChkStringTableView> legacyTables,
    required List<ChkStringTableView> extendedTables,
    required List<EditorDiagnostic> diagnostics,
  }) : scenarioProperties = List.unmodifiable(scenarioProperties),
       legacyTables = List.unmodifiable(legacyTables),
       extendedTables = List.unmodifiable(extendedTables),
       diagnostics = List.unmodifiable(diagnostics);

  final List<ChkScenarioPropertiesView> scenarioProperties;
  final List<ChkStringTableView> legacyTables;
  final List<ChkStringTableView> extendedTables;
  final List<EditorDiagnostic> diagnostics;

  bool get hasBlockingDiagnostics =>
      diagnostics.any((diagnostic) => diagnostic.blocksOperation);
}

class ChkStringViewDecoder {
  const ChkStringViewDecoder();

  ChkStringViews decode(RawChkDocument document) {
    final scenarioProperties = <ChkScenarioPropertiesView>[];
    final legacyTables = <ChkStringTableView>[];
    final extendedTables = <ChkStringTableView>[];
    final diagnostics = <EditorDiagnostic>[];

    for (
      var sectionIndex = 0;
      sectionIndex < document.sections.length;
      sectionIndex++
    ) {
      final section = document.sections[sectionIndex];

      if (ChkSectionNames.isScenarioProperties(section)) {
        if (section.declaredLength == ChkScenarioPropertiesView.payloadLength) {
          scenarioProperties.add(
            ChkScenarioPropertiesView._(
              sectionIndex: sectionIndex,
              rawSection: section,
            ),
          );
        } else {
          diagnostics.add(
            _fixedSizeDiagnostic(
              section: section,
              sectionIndex: sectionIndex,
              expectedLength: ChkScenarioPropertiesView.payloadLength,
            ),
          );
        }
      } else if (ChkSectionNames.isLegacyStrings(section)) {
        final decoded = _decodeTable(
          section: section,
          sectionIndex: sectionIndex,
          kind: ChkStringTableKind.legacy,
        );
        diagnostics.addAll(decoded.diagnostics);
        if (decoded.table != null) {
          legacyTables.add(decoded.table!);
        }
      } else if (ChkSectionNames.isExtendedStrings(section)) {
        final decoded = _decodeTable(
          section: section,
          sectionIndex: sectionIndex,
          kind: ChkStringTableKind.extended,
        );
        diagnostics.addAll(decoded.diagnostics);
        if (decoded.table != null) {
          extendedTables.add(decoded.table!);
        }
      }
    }

    return ChkStringViews(
      scenarioProperties: scenarioProperties,
      legacyTables: legacyTables,
      extendedTables: extendedTables,
      diagnostics: diagnostics,
    );
  }

  _DecodedStringTable _decodeTable({
    required RawChkSection section,
    required int sectionIndex,
    required ChkStringTableKind kind,
  }) {
    final payload = section.payload;
    final diagnostics = <EditorDiagnostic>[];

    if (payload.length < kind.countFieldWidth) {
      diagnostics.add(
        EditorDiagnostic(
          code: ChkTypedDiagnosticCodes.stringTableHeaderTruncated,
          message:
              'Section "${section.name}" does not contain its complete '
              '${kind.countFieldWidth}-byte string count.',
          severity: DiagnosticSeverity.error,
          stage: DiagnosticStage.validate,
          sectionName: section.name,
          byteOffset: section.sourceOffset + RawChkParser.headerLength,
          remediation: 'Keep this string table unchanged and read-only.',
          rawDetails:
              'sectionIndex=$sectionIndex; '
              'requiredCountBytes=${kind.countFieldWidth}; '
              'actualPayloadBytes=${payload.length}',
        ),
      );
      return _DecodedStringTable(table: null, diagnostics: diagnostics);
    }

    final data = ByteData.sublistView(payload);
    final declaredCount = kind == ChkStringTableKind.legacy
        ? data.getUint16(0, Endian.little)
        : data.getUint32(0, Endian.little);
    final stringDataOffset =
        kind.countFieldWidth + declaredCount * kind.offsetFieldWidth;

    if (stringDataOffset > payload.length) {
      diagnostics.add(
        EditorDiagnostic(
          code: ChkTypedDiagnosticCodes.stringTableOffsetsTruncated,
          message:
              'Section "${section.name}" declares $declaredCount strings, '
              'but its offset table exceeds the payload.',
          severity: DiagnosticSeverity.error,
          stage: DiagnosticStage.validate,
          sectionName: section.name,
          byteOffset: section.sourceOffset + RawChkParser.headerLength,
          remediation: 'Keep this string table unchanged and read-only.',
          rawDetails:
              'sectionIndex=$sectionIndex; '
              'declaredStringCount=$declaredCount; '
              'requiredHeaderBytes=$stringDataOffset; '
              'actualPayloadBytes=${payload.length}',
        ),
      );
      return _DecodedStringTable(table: null, diagnostics: diagnostics);
    }

    final entries = <ChkStringEntryView>[];
    for (var stringId = 1; stringId <= declaredCount; stringId++) {
      final offsetFieldPosition =
          kind.countFieldWidth + (stringId - 1) * kind.offsetFieldWidth;
      final rawOffset = kind == ChkStringTableKind.legacy
          ? data.getUint16(offsetFieldPosition, Endian.little)
          : data.getUint32(offsetFieldPosition, Endian.little);
      final offsetInBounds = rawOffset < payload.length;
      final pointsIntoHeader = offsetInBounds && rawOffset < stringDataOffset;
      final terminatorOffset = offsetInBounds
          ? payload.indexOf(0, rawOffset)
          : -1;
      final isNullTerminated = terminatorOffset >= rawOffset;
      final rawBytes = !offsetInBounds
          ? null
          : Uint8List.fromList(
              payload.sublist(
                rawOffset,
                isNullTerminated ? terminatorOffset : payload.length,
              ),
            );

      if (!offsetInBounds) {
        diagnostics.add(
          _stringEntryDiagnostic(
            code: ChkTypedDiagnosticCodes.stringOffsetOutOfBounds,
            message:
                'String $stringId in section "${section.name}" points '
                'outside the payload.',
            section: section,
            sectionIndex: sectionIndex,
            stringId: stringId,
            offsetFieldPosition: offsetFieldPosition,
            rawOffset: rawOffset,
            stringDataOffset: stringDataOffset,
            payloadLength: payload.length,
          ),
        );
      } else {
        if (pointsIntoHeader) {
          diagnostics.add(
            _stringEntryDiagnostic(
              code: ChkTypedDiagnosticCodes.stringOffsetIntoHeader,
              message:
                  'String $stringId in section "${section.name}" points '
                  'into the count or offset table.',
              section: section,
              sectionIndex: sectionIndex,
              stringId: stringId,
              offsetFieldPosition: offsetFieldPosition,
              rawOffset: rawOffset,
              stringDataOffset: stringDataOffset,
              payloadLength: payload.length,
            ),
          );
        }
        if (!isNullTerminated) {
          diagnostics.add(
            EditorDiagnostic(
              code: ChkTypedDiagnosticCodes.stringUnterminated,
              message:
                  'String $stringId in section "${section.name}" has no '
                  'null terminator before the payload ends.',
              severity: DiagnosticSeverity.error,
              stage: DiagnosticStage.validate,
              sectionName: section.name,
              byteOffset:
                  section.sourceOffset + RawChkParser.headerLength + rawOffset,
              remediation: 'Keep this string table unchanged and read-only.',
              rawDetails:
                  'sectionIndex=$sectionIndex; '
                  'stringId=$stringId; '
                  'rawOffset=$rawOffset; '
                  'payloadBytes=${payload.length}',
            ),
          );
        }
      }

      entries.add(
        ChkStringEntryView._(
          stringId: stringId,
          rawOffset: rawOffset,
          pointsIntoHeader: pointsIntoHeader,
          offsetInBounds: offsetInBounds,
          isNullTerminated: isNullTerminated,
          rawBytes: rawBytes,
        ),
      );
    }

    final table = ChkStringTableView._(
      sectionIndex: sectionIndex,
      rawSection: section,
      kind: kind,
      declaredStringCount: declaredCount,
      stringDataOffset: stringDataOffset,
      entries: entries,
      diagnostics: diagnostics,
    );
    return _DecodedStringTable(table: table, diagnostics: diagnostics);
  }
}

final class _DecodedStringTable {
  const _DecodedStringTable({required this.table, required this.diagnostics});

  final ChkStringTableView? table;
  final List<EditorDiagnostic> diagnostics;
}

EditorDiagnostic _fixedSizeDiagnostic({
  required RawChkSection section,
  required int sectionIndex,
  required int expectedLength,
}) {
  return EditorDiagnostic(
    code: ChkTypedDiagnosticCodes.sectionSizeMismatch,
    message:
        'Section "${section.name}" must contain exactly '
        '$expectedLength payload bytes, but contains '
        '${section.declaredLength}.',
    severity: DiagnosticSeverity.error,
    stage: DiagnosticStage.validate,
    sectionName: section.name,
    byteOffset: section.sourceOffset + RawChkParser.headerLength,
    remediation: 'Keep this section unchanged and treat the map as read-only.',
    rawDetails:
        'sectionIndex=$sectionIndex; '
        'sectionOffset=${section.sourceOffset}; '
        'expectedPayloadBytes=$expectedLength; '
        'actualPayloadBytes=${section.declaredLength}',
  );
}

EditorDiagnostic _stringEntryDiagnostic({
  required String code,
  required String message,
  required RawChkSection section,
  required int sectionIndex,
  required int stringId,
  required int offsetFieldPosition,
  required int rawOffset,
  required int stringDataOffset,
  required int payloadLength,
}) {
  return EditorDiagnostic(
    code: code,
    message: message,
    severity: DiagnosticSeverity.error,
    stage: DiagnosticStage.validate,
    sectionName: section.name,
    byteOffset:
        section.sourceOffset + RawChkParser.headerLength + offsetFieldPosition,
    remediation: 'Keep this string table unchanged and read-only.',
    rawDetails:
        'sectionIndex=$sectionIndex; '
        'stringId=$stringId; '
        'rawOffset=$rawOffset; '
        'stringDataOffset=$stringDataOffset; '
        'payloadBytes=$payloadLength',
  );
}

int _readUint16(Uint8List payload, {required int offset}) {
  return ByteData.sublistView(payload).getUint16(offset, Endian.little);
}

int _checkUint16(int value, String argumentName) {
  if (value < 0 || value > 0xffff) {
    throw RangeError.range(value, 0, 0xffff, argumentName);
  }
  return value;
}

void _validateStringBytes(List<int> bytes) {
  for (var index = 0; index < bytes.length; index++) {
    final byte = bytes[index];
    if (byte < 0 || byte > 0xff) {
      throw RangeError.range(byte, 0, 0xff, 'rawBytes[$index]');
    }
    if (byte == 0) {
      throw ArgumentError.value(
        bytes,
        'rawBytes',
        'A string value cannot contain an embedded null terminator.',
      );
    }
  }
}
