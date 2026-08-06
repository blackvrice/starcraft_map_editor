import 'dart:typed_data';

import '../../diagnostics/editor_diagnostic.dart';
import '../chk_section_names.dart';
import '../raw_chk_document.dart';
import '../raw_chk_parser.dart';
import '../raw_chk_section.dart';
import 'chk_typed_diagnostic_codes.dart';

final class ChkUnitPlacement {
  const ChkUnitPlacement._({
    required this.recordIndex,
    required this.classId,
    required this.x,
    required this.y,
    required this.unitType,
    required this.relationFlags,
    required this.validStateFlags,
    required this.validFieldFlags,
    required this.owner,
    required this.hitpointPercent,
    required this.shieldPercent,
    required this.energyPercent,
    required this.resourceAmount,
    required this.hangarAmount,
    required this.stateFlags,
    required this.unused,
    required this.relationClassId,
  });

  static const recordLength = 36;

  final int recordIndex;
  final int classId;
  final int x;
  final int y;
  final int unitType;
  final int relationFlags;
  final int validStateFlags;
  final int validFieldFlags;
  final int owner;
  final int hitpointPercent;
  final int shieldPercent;
  final int energyPercent;
  final int resourceAmount;
  final int hangarAmount;
  final int stateFlags;
  final int unused;
  final int relationClassId;
}

final class ChkDoodadPlacement {
  const ChkDoodadPlacement._({
    required this.recordIndex,
    required this.doodadType,
    required this.x,
    required this.y,
    required this.owner,
    required this.enabledValue,
  });

  static const recordLength = 8;

  final int recordIndex;
  final int doodadType;
  final int x;
  final int y;
  final int owner;
  final int enabledValue;

  bool get isEnabled => enabledValue == 0;

  bool get hasKnownEnabledValue => enabledValue == 0 || enabledValue == 1;
}

final class ChkSpritePlacement {
  const ChkSpritePlacement._({
    required this.recordIndex,
    required this.spriteType,
    required this.x,
    required this.y,
    required this.owner,
    required this.unused,
    required this.flags,
  });

  static const recordLength = 10;
  static const drawAsSpriteFlag = 1 << 12;
  static const isUnitFlag = 1 << 13;
  static const spriteUnitDisabledFlag = 1 << 15;

  final int recordIndex;
  final int spriteType;
  final int x;
  final int y;
  final int owner;
  final int unused;
  final int flags;

  bool get drawsAsSprite => flags & drawAsSpriteFlag != 0;

  bool get hasUnitFlag => flags & isUnitFlag != 0;

  bool get isSpriteUnitDisabled => flags & spriteUnitDisabledFlag != 0;
}

final class ChkLocation {
  const ChkLocation._({
    required this.recordIndex,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.stringId,
    required this.elevationFlags,
  });

  static const recordLength = 20;

  final int recordIndex;
  final int left;
  final int top;
  final int right;
  final int bottom;
  final int stringId;
  final int elevationFlags;

  int get locationId => recordIndex + 1;

  bool get isBlank =>
      left == 0 &&
      top == 0 &&
      right == 0 &&
      bottom == 0 &&
      stringId == 0 &&
      elevationFlags == 0;
}

final class ChkUnitSectionView {
  ChkUnitSectionView._({
    required this.sectionIndex,
    required this.rawSection,
    required List<ChkUnitPlacement> units,
  }) : units = List.unmodifiable(units);

  final int sectionIndex;
  final RawChkSection rawSection;
  final List<ChkUnitPlacement> units;
}

final class ChkDoodadSectionView {
  ChkDoodadSectionView._({
    required this.sectionIndex,
    required this.rawSection,
    required List<ChkDoodadPlacement> doodads,
  }) : doodads = List.unmodifiable(doodads);

  final int sectionIndex;
  final RawChkSection rawSection;
  final List<ChkDoodadPlacement> doodads;
}

final class ChkSpriteSectionView {
  ChkSpriteSectionView._({
    required this.sectionIndex,
    required this.rawSection,
    required List<ChkSpritePlacement> sprites,
  }) : sprites = List.unmodifiable(sprites);

  final int sectionIndex;
  final RawChkSection rawSection;
  final List<ChkSpritePlacement> sprites;
}

final class ChkLocationSectionView {
  ChkLocationSectionView._({
    required this.sectionIndex,
    required this.rawSection,
    required List<ChkLocation> locations,
  }) : locations = List.unmodifiable(locations);

  static const originalLocationCount = 64;
  static const extendedLocationCount = 255;

  final int sectionIndex;
  final RawChkSection rawSection;
  final List<ChkLocation> locations;

  bool get usesExtendedLocationTable =>
      locations.length == extendedLocationCount;
}

final class ChkObjectViews {
  ChkObjectViews({
    required List<ChkUnitSectionView> unitSections,
    required List<ChkDoodadSectionView> doodadSections,
    required List<ChkSpriteSectionView> spriteSections,
    required List<ChkLocationSectionView> locationSections,
    required List<EditorDiagnostic> diagnostics,
  }) : unitSections = List.unmodifiable(unitSections),
       doodadSections = List.unmodifiable(doodadSections),
       spriteSections = List.unmodifiable(spriteSections),
       locationSections = List.unmodifiable(locationSections),
       diagnostics = List.unmodifiable(diagnostics);

  final List<ChkUnitSectionView> unitSections;
  final List<ChkDoodadSectionView> doodadSections;
  final List<ChkSpriteSectionView> spriteSections;
  final List<ChkLocationSectionView> locationSections;
  final List<EditorDiagnostic> diagnostics;

  bool get hasBlockingDiagnostics =>
      diagnostics.any((diagnostic) => diagnostic.blocksOperation);
}

class ChkObjectViewDecoder {
  const ChkObjectViewDecoder();

  ChkObjectViews decode(RawChkDocument document) {
    final unitSections = <ChkUnitSectionView>[];
    final doodadSections = <ChkDoodadSectionView>[];
    final spriteSections = <ChkSpriteSectionView>[];
    final locationSections = <ChkLocationSectionView>[];
    final diagnostics = <EditorDiagnostic>[];

    for (
      var sectionIndex = 0;
      sectionIndex < document.sections.length;
      sectionIndex++
    ) {
      final section = document.sections[sectionIndex];

      if (ChkSectionNames.isUnitPlacements(section)) {
        if (!_hasCompleteRecords(
          section: section,
          sectionIndex: sectionIndex,
          recordLength: ChkUnitPlacement.recordLength,
          diagnosticCode: ChkTypedDiagnosticCodes.unitRecordTruncated,
          recordLabel: 'unit',
          diagnostics: diagnostics,
        )) {
          continue;
        }
        unitSections.add(
          ChkUnitSectionView._(
            sectionIndex: sectionIndex,
            rawSection: section,
            units: _decodeUnits(section.payload),
          ),
        );
      } else if (ChkSectionNames.isDoodadPlacements(section)) {
        if (!_hasCompleteRecords(
          section: section,
          sectionIndex: sectionIndex,
          recordLength: ChkDoodadPlacement.recordLength,
          diagnosticCode: ChkTypedDiagnosticCodes.doodadRecordTruncated,
          recordLabel: 'doodad',
          diagnostics: diagnostics,
        )) {
          continue;
        }
        doodadSections.add(
          ChkDoodadSectionView._(
            sectionIndex: sectionIndex,
            rawSection: section,
            doodads: _decodeDoodads(section.payload),
          ),
        );
      } else if (ChkSectionNames.isSpritePlacements(section)) {
        if (!_hasCompleteRecords(
          section: section,
          sectionIndex: sectionIndex,
          recordLength: ChkSpritePlacement.recordLength,
          diagnosticCode: ChkTypedDiagnosticCodes.spriteRecordTruncated,
          recordLabel: 'sprite',
          diagnostics: diagnostics,
        )) {
          continue;
        }
        spriteSections.add(
          ChkSpriteSectionView._(
            sectionIndex: sectionIndex,
            rawSection: section,
            sprites: _decodeSprites(section.payload),
          ),
        );
      } else if (ChkSectionNames.isLocations(section)) {
        if (!_hasSupportedLocationSize(
          section: section,
          sectionIndex: sectionIndex,
          diagnostics: diagnostics,
        )) {
          continue;
        }
        locationSections.add(
          ChkLocationSectionView._(
            sectionIndex: sectionIndex,
            rawSection: section,
            locations: _decodeLocations(section.payload),
          ),
        );
      }
    }

    return ChkObjectViews(
      unitSections: unitSections,
      doodadSections: doodadSections,
      spriteSections: spriteSections,
      locationSections: locationSections,
      diagnostics: diagnostics,
    );
  }
}

List<ChkUnitPlacement> _decodeUnits(Uint8List payload) {
  final data = ByteData.sublistView(payload);
  return List.generate(payload.length ~/ ChkUnitPlacement.recordLength, (
    index,
  ) {
    final offset = index * ChkUnitPlacement.recordLength;
    return ChkUnitPlacement._(
      recordIndex: index,
      classId: data.getUint32(offset, Endian.little),
      x: data.getUint16(offset + 4, Endian.little),
      y: data.getUint16(offset + 6, Endian.little),
      unitType: data.getUint16(offset + 8, Endian.little),
      relationFlags: data.getUint16(offset + 10, Endian.little),
      validStateFlags: data.getUint16(offset + 12, Endian.little),
      validFieldFlags: data.getUint16(offset + 14, Endian.little),
      owner: data.getUint8(offset + 16),
      hitpointPercent: data.getUint8(offset + 17),
      shieldPercent: data.getUint8(offset + 18),
      energyPercent: data.getUint8(offset + 19),
      resourceAmount: data.getUint32(offset + 20, Endian.little),
      hangarAmount: data.getUint16(offset + 24, Endian.little),
      stateFlags: data.getUint16(offset + 26, Endian.little),
      unused: data.getUint32(offset + 28, Endian.little),
      relationClassId: data.getUint32(offset + 32, Endian.little),
    );
  }, growable: false);
}

List<ChkDoodadPlacement> _decodeDoodads(Uint8List payload) {
  final data = ByteData.sublistView(payload);
  return List.generate(payload.length ~/ ChkDoodadPlacement.recordLength, (
    index,
  ) {
    final offset = index * ChkDoodadPlacement.recordLength;
    return ChkDoodadPlacement._(
      recordIndex: index,
      doodadType: data.getUint16(offset, Endian.little),
      x: data.getUint16(offset + 2, Endian.little),
      y: data.getUint16(offset + 4, Endian.little),
      owner: data.getUint8(offset + 6),
      enabledValue: data.getUint8(offset + 7),
    );
  }, growable: false);
}

List<ChkSpritePlacement> _decodeSprites(Uint8List payload) {
  final data = ByteData.sublistView(payload);
  return List.generate(payload.length ~/ ChkSpritePlacement.recordLength, (
    index,
  ) {
    final offset = index * ChkSpritePlacement.recordLength;
    return ChkSpritePlacement._(
      recordIndex: index,
      spriteType: data.getUint16(offset, Endian.little),
      x: data.getUint16(offset + 2, Endian.little),
      y: data.getUint16(offset + 4, Endian.little),
      owner: data.getUint8(offset + 6),
      unused: data.getUint8(offset + 7),
      flags: data.getUint16(offset + 8, Endian.little),
    );
  }, growable: false);
}

List<ChkLocation> _decodeLocations(Uint8List payload) {
  final data = ByteData.sublistView(payload);
  return List.generate(payload.length ~/ ChkLocation.recordLength, (index) {
    final offset = index * ChkLocation.recordLength;
    return ChkLocation._(
      recordIndex: index,
      left: data.getUint32(offset, Endian.little),
      top: data.getUint32(offset + 4, Endian.little),
      right: data.getUint32(offset + 8, Endian.little),
      bottom: data.getUint32(offset + 12, Endian.little),
      stringId: data.getUint16(offset + 16, Endian.little),
      elevationFlags: data.getUint16(offset + 18, Endian.little),
    );
  }, growable: false);
}

bool _hasCompleteRecords({
  required RawChkSection section,
  required int sectionIndex,
  required int recordLength,
  required String diagnosticCode,
  required String recordLabel,
  required List<EditorDiagnostic> diagnostics,
}) {
  final trailingBytes = section.declaredLength % recordLength;
  if (trailingBytes == 0) {
    return true;
  }

  final completeRecordBytes = section.declaredLength - trailingBytes;
  diagnostics.add(
    EditorDiagnostic(
      code: diagnosticCode,
      message:
          'Section "${section.name}" ends with an incomplete '
          '$recordLength-byte $recordLabel record.',
      severity: DiagnosticSeverity.error,
      stage: DiagnosticStage.validate,
      sectionName: section.name,
      byteOffset:
          section.sourceOffset +
          RawChkParser.headerLength +
          completeRecordBytes,
      remediation: 'Keep this object section unchanged and read-only.',
      rawDetails:
          'sectionIndex=$sectionIndex; '
          'recordBytes=$recordLength; '
          'completeRecords=${section.declaredLength ~/ recordLength}; '
          'trailingBytes=$trailingBytes; '
          'actualPayloadBytes=${section.declaredLength}',
    ),
  );
  return false;
}

bool _hasSupportedLocationSize({
  required RawChkSection section,
  required int sectionIndex,
  required List<EditorDiagnostic> diagnostics,
}) {
  const originalBytes =
      ChkLocationSectionView.originalLocationCount * ChkLocation.recordLength;
  const extendedBytes =
      ChkLocationSectionView.extendedLocationCount * ChkLocation.recordLength;
  if (section.declaredLength == originalBytes ||
      section.declaredLength == extendedBytes) {
    return true;
  }

  diagnostics.add(
    EditorDiagnostic(
      code: ChkTypedDiagnosticCodes.locationSectionSizeMismatch,
      message:
          'Section "${section.name}" must contain either 64 or 255 complete '
          'location records.',
      severity: DiagnosticSeverity.error,
      stage: DiagnosticStage.validate,
      sectionName: section.name,
      byteOffset: section.sourceOffset + RawChkParser.headerLength,
      remediation: 'Keep this location section unchanged and read-only.',
      rawDetails:
          'sectionIndex=$sectionIndex; '
          'recordBytes=${ChkLocation.recordLength}; '
          'expectedPayloadBytes=$originalBytes or $extendedBytes; '
          'actualPayloadBytes=${section.declaredLength}',
    ),
  );
  return false;
}
