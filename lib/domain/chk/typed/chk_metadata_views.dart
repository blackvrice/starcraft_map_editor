import 'dart:typed_data';

import '../../diagnostics/editor_diagnostic.dart';
import '../chk_section_names.dart';
import '../raw_chk_document.dart';
import '../raw_chk_parser.dart';
import '../raw_chk_section.dart';
import 'chk_typed_diagnostic_codes.dart';

enum ChkScenarioType {
  starCraftHybrid(0x53574152, 'RAWS'),
  broodWar(0x42574152, 'RAWB');

  const ChkScenarioType(this.rawValue, this.fourCharacterCode);

  final int rawValue;
  final String fourCharacterCode;

  static ChkScenarioType? fromRawValue(int rawValue) {
    for (final value in values) {
      if (value.rawValue == rawValue) {
        return value;
      }
    }
    return null;
  }
}

enum ChkMapVersion {
  starCraftOriginal(59),
  starCraftHybrid(63),
  broodWar(205),
  remastered(206);

  const ChkMapVersion(this.rawValue);

  final int rawValue;

  static ChkMapVersion? fromRawValue(int rawValue) {
    for (final value in values) {
      if (value.rawValue == rawValue) {
        return value;
      }
    }
    return null;
  }
}

enum ChkInternalVersion {
  beta(9),
  current(10);

  const ChkInternalVersion(this.rawValue);

  final int rawValue;

  static ChkInternalVersion? fromRawValue(int rawValue) {
    for (final value in values) {
      if (value.rawValue == rawValue) {
        return value;
      }
    }
    return null;
  }
}

enum ChkTileset {
  badlands(0),
  spacePlatform(1),
  installation(2),
  ashworld(3),
  jungle(4),
  desert(5),
  arctic(6),
  twilight(7);

  const ChkTileset(this.rawValue);

  final int rawValue;

  static ChkTileset? fromRawValue(int rawValue) {
    for (final value in values) {
      if (value.rawValue == rawValue) {
        return value;
      }
    }
    return null;
  }
}

abstract class ChkTypedSectionView {
  const ChkTypedSectionView({
    required this.sectionIndex,
    required this.rawSection,
  });

  final int sectionIndex;
  final RawChkSection rawSection;
}

final class ChkTypeView extends ChkTypedSectionView {
  ChkTypeView._({required super.sectionIndex, required super.rawSection})
    : rawValue = _readUint32(rawSection.payload);

  static const payloadLength = 4;

  final int rawValue;

  ChkScenarioType? get knownType => ChkScenarioType.fromRawValue(rawValue);

  String get fourCharacterCode => _formatFourCharacterCode(rawSection.payload);

  RawChkSection withRawValue(int updatedValue) {
    return rawSection.withPayload(_writeUint32(updatedValue, 'updatedValue'));
  }
}

final class ChkVersionView extends ChkTypedSectionView {
  ChkVersionView._({required super.sectionIndex, required super.rawSection})
    : rawValue = _readUint16(rawSection.payload);

  static const payloadLength = 2;

  final int rawValue;

  ChkMapVersion? get knownVersion => ChkMapVersion.fromRawValue(rawValue);

  RawChkSection withRawValue(int updatedValue) {
    return rawSection.withPayload(_writeUint16(updatedValue, 'updatedValue'));
  }
}

final class ChkInternalVersionView extends ChkTypedSectionView {
  ChkInternalVersionView._({
    required super.sectionIndex,
    required super.rawSection,
  }) : rawValue = _readUint16(rawSection.payload);

  static const payloadLength = 2;

  final int rawValue;

  ChkInternalVersion? get knownVersion =>
      ChkInternalVersion.fromRawValue(rawValue);

  RawChkSection withRawValue(int updatedValue) {
    return rawSection.withPayload(_writeUint16(updatedValue, 'updatedValue'));
  }
}

final class ChkDimensionsView extends ChkTypedSectionView {
  ChkDimensionsView._({required super.sectionIndex, required super.rawSection})
    : width = _readUint16(rawSection.payload),
      height = _readUint16(rawSection.payload, offset: 2);

  static const payloadLength = 4;

  final int width;
  final int height;

  RawChkSection withDimensions({required int width, required int height}) {
    final payload = Uint8List(payloadLength);
    ByteData.sublistView(payload)
      ..setUint16(0, _checkUint16(width, 'width'), Endian.little)
      ..setUint16(2, _checkUint16(height, 'height'), Endian.little);
    return rawSection.withPayload(payload);
  }
}

final class ChkTilesetView extends ChkTypedSectionView {
  ChkTilesetView._({required super.sectionIndex, required super.rawSection})
    : rawValue = _readUint16(rawSection.payload);

  static const payloadLength = 2;

  final int rawValue;

  ChkTileset? get knownTileset => ChkTileset.fromRawValue(rawValue);

  RawChkSection withRawValue(int updatedValue) {
    return rawSection.withPayload(_writeUint16(updatedValue, 'updatedValue'));
  }
}

final class ChkMetadataViews {
  ChkMetadataViews({
    required List<ChkTypeView> types,
    required List<ChkVersionView> versions,
    required List<ChkInternalVersionView> internalVersions,
    required List<ChkDimensionsView> dimensions,
    required List<ChkTilesetView> tilesets,
    required List<EditorDiagnostic> diagnostics,
  }) : types = List.unmodifiable(types),
       versions = List.unmodifiable(versions),
       internalVersions = List.unmodifiable(internalVersions),
       dimensions = List.unmodifiable(dimensions),
       tilesets = List.unmodifiable(tilesets),
       diagnostics = List.unmodifiable(diagnostics);

  final List<ChkTypeView> types;
  final List<ChkVersionView> versions;
  final List<ChkInternalVersionView> internalVersions;
  final List<ChkDimensionsView> dimensions;
  final List<ChkTilesetView> tilesets;
  final List<EditorDiagnostic> diagnostics;

  bool get hasBlockingDiagnostics =>
      diagnostics.any((diagnostic) => diagnostic.blocksOperation);
}

class ChkMetadataViewDecoder {
  const ChkMetadataViewDecoder();

  ChkMetadataViews decode(RawChkDocument document) {
    final types = <ChkTypeView>[];
    final versions = <ChkVersionView>[];
    final internalVersions = <ChkInternalVersionView>[];
    final dimensions = <ChkDimensionsView>[];
    final tilesets = <ChkTilesetView>[];
    final diagnostics = <EditorDiagnostic>[];

    for (
      var sectionIndex = 0;
      sectionIndex < document.sections.length;
      sectionIndex++
    ) {
      final section = document.sections[sectionIndex];

      if (ChkSectionNames.isType(section)) {
        if (_hasExpectedLength(
          section: section,
          sectionIndex: sectionIndex,
          expectedLength: ChkTypeView.payloadLength,
          diagnostics: diagnostics,
        )) {
          types.add(
            ChkTypeView._(sectionIndex: sectionIndex, rawSection: section),
          );
        }
      } else if (ChkSectionNames.isVersion(section)) {
        if (_hasExpectedLength(
          section: section,
          sectionIndex: sectionIndex,
          expectedLength: ChkVersionView.payloadLength,
          diagnostics: diagnostics,
        )) {
          versions.add(
            ChkVersionView._(sectionIndex: sectionIndex, rawSection: section),
          );
        }
      } else if (ChkSectionNames.isInternalVersion(section)) {
        if (_hasExpectedLength(
          section: section,
          sectionIndex: sectionIndex,
          expectedLength: ChkInternalVersionView.payloadLength,
          diagnostics: diagnostics,
        )) {
          internalVersions.add(
            ChkInternalVersionView._(
              sectionIndex: sectionIndex,
              rawSection: section,
            ),
          );
        }
      } else if (ChkSectionNames.isDimensions(section)) {
        if (_hasExpectedLength(
          section: section,
          sectionIndex: sectionIndex,
          expectedLength: ChkDimensionsView.payloadLength,
          diagnostics: diagnostics,
        )) {
          dimensions.add(
            ChkDimensionsView._(
              sectionIndex: sectionIndex,
              rawSection: section,
            ),
          );
        }
      } else if (ChkSectionNames.isTileset(section)) {
        if (_hasExpectedLength(
          section: section,
          sectionIndex: sectionIndex,
          expectedLength: ChkTilesetView.payloadLength,
          diagnostics: diagnostics,
        )) {
          tilesets.add(
            ChkTilesetView._(sectionIndex: sectionIndex, rawSection: section),
          );
        }
      }
    }

    return ChkMetadataViews(
      types: types,
      versions: versions,
      internalVersions: internalVersions,
      dimensions: dimensions,
      tilesets: tilesets,
      diagnostics: diagnostics,
    );
  }

  bool _hasExpectedLength({
    required RawChkSection section,
    required int sectionIndex,
    required int expectedLength,
    required List<EditorDiagnostic> diagnostics,
  }) {
    if (section.declaredLength == expectedLength) {
      return true;
    }

    diagnostics.add(
      EditorDiagnostic(
        code: ChkTypedDiagnosticCodes.sectionSizeMismatch,
        message:
            'Section "${section.name}" must contain exactly '
            '$expectedLength payload bytes, but contains '
            '${section.declaredLength}.',
        severity: DiagnosticSeverity.error,
        stage: DiagnosticStage.validate,
        sectionName: section.name,
        byteOffset: section.sourceOffset + RawChkParser.headerLength,
        remediation:
            'Keep this section unchanged and treat the map as read-only.',
        rawDetails:
            'sectionIndex=$sectionIndex; '
            'sectionOffset=${section.sourceOffset}; '
            'expectedPayloadBytes=$expectedLength; '
            'actualPayloadBytes=${section.declaredLength}',
      ),
    );
    return false;
  }
}

int _readUint16(Uint8List payload, {int offset = 0}) {
  return ByteData.sublistView(payload).getUint16(offset, Endian.little);
}

int _readUint32(Uint8List payload) {
  return ByteData.sublistView(payload).getUint32(0, Endian.little);
}

int _checkUint16(int value, String argumentName) {
  if (value < 0 || value > 0xffff) {
    throw RangeError.range(value, 0, 0xffff, argumentName);
  }
  return value;
}

int _checkUint32(int value, String argumentName) {
  if (value < 0 || value > 0xffffffff) {
    throw RangeError.range(value, 0, 0xffffffff, argumentName);
  }
  return value;
}

Uint8List _writeUint16(int value, String argumentName) {
  final payload = Uint8List(2);
  ByteData.sublistView(
    payload,
  ).setUint16(0, _checkUint16(value, argumentName), Endian.little);
  return payload;
}

Uint8List _writeUint32(int value, String argumentName) {
  final payload = Uint8List(4);
  ByteData.sublistView(
    payload,
  ).setUint32(0, _checkUint32(value, argumentName), Endian.little);
  return payload;
}

String _formatFourCharacterCode(Uint8List bytes) {
  final result = StringBuffer();

  for (final byte in bytes) {
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
