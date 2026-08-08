import '../../diagnostics/editor_diagnostic.dart';
import '../raw_chk_parser.dart';
import 'chk_metadata_views.dart';
import 'chk_object_views.dart';
import 'chk_string_views.dart';

abstract final class ChkObjectReferenceDiagnosticCodes {
  static const coordinateOutOfBounds = 'CHK_OBJECT_COORDINATE_OUT_OF_BOUNDS';
  static const playerOutOfRange = 'CHK_OBJECT_PLAYER_OUT_OF_RANGE';
  static const locationBoundsInvalid = 'CHK_LOCATION_BOUNDS_INVALID';
  static const stringReferenceOutOfRange = 'CHK_STRING_REFERENCE_OUT_OF_RANGE';
  static const stringReferenceUnresolved = 'CHK_STRING_REFERENCE_UNRESOLVED';
  static const stringTableAmbiguous = 'CHK_STRING_REFERENCE_TABLE_AMBIGUOUS';

  static const values = {
    coordinateOutOfBounds,
    playerOutOfRange,
    locationBoundsInvalid,
    stringReferenceOutOfRange,
    stringReferenceUnresolved,
    stringTableAmbiguous,
  };

  static bool contains(String code) => values.contains(code);
}

class ChkObjectReferenceValidator {
  const ChkObjectReferenceValidator();

  static const minimumPlayer = 0;
  static const maximumPlayer = 11;

  List<EditorDiagnostic> validate({
    required ChkMetadataViews metadataViews,
    required ChkStringViews stringViews,
    required ChkObjectViews objectViews,
  }) {
    final diagnostics = <EditorDiagnostic>[];
    final dimensions = metadataViews.dimensions.length == 1
        ? metadataViews.dimensions.single
        : null;
    final maximumX = dimensions == null ? null : dimensions.width * 32;
    final maximumY = dimensions == null ? null : dimensions.height * 32;

    for (final section in objectViews.unitSections) {
      for (final unit in section.units) {
        _validatePoint(
          diagnostics,
          sectionName: section.rawSection.name,
          sectionIndex: section.sectionIndex,
          sectionSourceOffset: section.rawSection.sourceOffset,
          recordIndex: unit.recordIndex,
          recordLength: ChkUnitPlacement.recordLength,
          coordinateFieldOffset: 4,
          x: unit.x,
          y: unit.y,
          maximumX: maximumX,
          maximumY: maximumY,
          objectLabel: 'Unit',
        );
        _validatePlayer(
          diagnostics,
          sectionName: section.rawSection.name,
          sectionIndex: section.sectionIndex,
          sectionSourceOffset: section.rawSection.sourceOffset,
          recordIndex: unit.recordIndex,
          recordLength: ChkUnitPlacement.recordLength,
          playerFieldOffset: 16,
          player: unit.owner,
          objectLabel: 'Unit',
        );
      }
    }
    for (final section in objectViews.doodadSections) {
      for (final doodad in section.doodads) {
        _validatePoint(
          diagnostics,
          sectionName: section.rawSection.name,
          sectionIndex: section.sectionIndex,
          sectionSourceOffset: section.rawSection.sourceOffset,
          recordIndex: doodad.recordIndex,
          recordLength: ChkDoodadPlacement.recordLength,
          coordinateFieldOffset: 2,
          x: doodad.x,
          y: doodad.y,
          maximumX: maximumX,
          maximumY: maximumY,
          objectLabel: 'Doodad',
        );
        _validatePlayer(
          diagnostics,
          sectionName: section.rawSection.name,
          sectionIndex: section.sectionIndex,
          sectionSourceOffset: section.rawSection.sourceOffset,
          recordIndex: doodad.recordIndex,
          recordLength: ChkDoodadPlacement.recordLength,
          playerFieldOffset: 6,
          player: doodad.owner,
          objectLabel: 'Doodad',
        );
      }
    }
    for (final section in objectViews.spriteSections) {
      for (final sprite in section.sprites) {
        _validatePoint(
          diagnostics,
          sectionName: section.rawSection.name,
          sectionIndex: section.sectionIndex,
          sectionSourceOffset: section.rawSection.sourceOffset,
          recordIndex: sprite.recordIndex,
          recordLength: ChkSpritePlacement.recordLength,
          coordinateFieldOffset: 2,
          x: sprite.x,
          y: sprite.y,
          maximumX: maximumX,
          maximumY: maximumY,
          objectLabel: 'Sprite',
        );
        _validatePlayer(
          diagnostics,
          sectionName: section.rawSection.name,
          sectionIndex: section.sectionIndex,
          sectionSourceOffset: section.rawSection.sourceOffset,
          recordIndex: sprite.recordIndex,
          recordLength: ChkSpritePlacement.recordLength,
          playerFieldOffset: 6,
          player: sprite.owner,
          objectLabel: 'Sprite',
        );
      }
    }
    for (final section in objectViews.locationSections) {
      for (final location in section.locations) {
        if (location.isBlank) {
          continue;
        }
        _validateLocationBounds(
          diagnostics,
          section: section,
          location: location,
          maximumX: maximumX,
          maximumY: maximumY,
        );
        _validateStringReference(
          diagnostics,
          stringViews: stringViews,
          sectionName: section.rawSection.name,
          sectionIndex: section.sectionIndex,
          sectionSourceOffset: section.rawSection.sourceOffset,
          fieldOffset: location.recordIndex * ChkLocation.recordLength + 16,
          stringId: location.stringId,
          referenceLabel: 'Location ${location.locationId} name',
          rawDetails:
              'sectionIndex=${section.sectionIndex}; '
              'recordIndex=${location.recordIndex}; '
              'locationId=${location.locationId}',
        );
      }
    }

    for (final properties in stringViews.scenarioProperties) {
      _validateStringReference(
        diagnostics,
        stringViews: stringViews,
        sectionName: properties.rawSection.name,
        sectionIndex: properties.sectionIndex,
        sectionSourceOffset: properties.rawSection.sourceOffset,
        fieldOffset: 0,
        stringId: properties.scenarioName.stringId,
        referenceLabel: 'Scenario name',
        rawDetails: 'sectionIndex=${properties.sectionIndex}; field=name',
      );
      _validateStringReference(
        diagnostics,
        stringViews: stringViews,
        sectionName: properties.rawSection.name,
        sectionIndex: properties.sectionIndex,
        sectionSourceOffset: properties.rawSection.sourceOffset,
        fieldOffset: 2,
        stringId: properties.scenarioDescription.stringId,
        referenceLabel: 'Scenario description',
        rawDetails:
            'sectionIndex=${properties.sectionIndex}; field=description',
      );
    }

    return List.unmodifiable(diagnostics);
  }
}

void _validatePoint(
  List<EditorDiagnostic> diagnostics, {
  required String sectionName,
  required int sectionIndex,
  required int sectionSourceOffset,
  required int recordIndex,
  required int recordLength,
  required int coordinateFieldOffset,
  required int x,
  required int y,
  required int? maximumX,
  required int? maximumY,
  required String objectLabel,
}) {
  if (maximumX == null || maximumY == null) {
    return;
  }
  if (x >= 0 && x <= maximumX && y >= 0 && y <= maximumY) {
    return;
  }
  diagnostics.add(
    _warning(
      code: ChkObjectReferenceDiagnosticCodes.coordinateOutOfBounds,
      message:
          '$objectLabel ${recordIndex + 1} is outside the map pixel bounds.',
      sectionName: sectionName,
      byteOffset:
          sectionSourceOffset +
          RawChkParser.headerLength +
          recordIndex * recordLength +
          coordinateFieldOffset,
      remediation:
          'Move the object inside 0..$maximumX by 0..$maximumY, or keep the '
          'raw record unchanged if the value is intentional EUD data.',
      rawDetails:
          'sectionIndex=$sectionIndex; recordIndex=$recordIndex; '
          'x=$x; y=$y; maximumX=$maximumX; maximumY=$maximumY',
    ),
  );
}

void _validatePlayer(
  List<EditorDiagnostic> diagnostics, {
  required String sectionName,
  required int sectionIndex,
  required int sectionSourceOffset,
  required int recordIndex,
  required int recordLength,
  required int playerFieldOffset,
  required int player,
  required String objectLabel,
}) {
  if (player >= ChkObjectReferenceValidator.minimumPlayer &&
      player <= ChkObjectReferenceValidator.maximumPlayer) {
    return;
  }
  diagnostics.add(
    _warning(
      code: ChkObjectReferenceDiagnosticCodes.playerOutOfRange,
      message:
          '$objectLabel ${recordIndex + 1} refers to player value $player, '
          'outside the supported 0..11 range.',
      sectionName: sectionName,
      byteOffset:
          sectionSourceOffset +
          RawChkParser.headerLength +
          recordIndex * recordLength +
          playerFieldOffset,
      remediation:
          'Choose Player 1 through Player 12, or keep the raw value unchanged '
          'if it is intentional EUD data.',
      rawDetails:
          'sectionIndex=$sectionIndex; recordIndex=$recordIndex; owner=$player',
    ),
  );
}

void _validateLocationBounds(
  List<EditorDiagnostic> diagnostics, {
  required ChkLocationSectionView section,
  required ChkLocation location,
  required int? maximumX,
  required int? maximumY,
}) {
  if (maximumX == null || maximumY == null) {
    return;
  }
  final inMap =
      location.left >= 0 &&
      location.left <= maximumX &&
      location.right >= 0 &&
      location.right <= maximumX &&
      location.top >= 0 &&
      location.top <= maximumY &&
      location.bottom >= 0 &&
      location.bottom <= maximumY;
  if (inMap &&
      location.left < location.right &&
      location.top < location.bottom) {
    return;
  }
  diagnostics.add(
    _warning(
      code: ChkObjectReferenceDiagnosticCodes.locationBoundsInvalid,
      message:
          'Location ${location.locationId} does not form a valid rectangle '
          'inside the map.',
      sectionName: section.rawSection.name,
      byteOffset:
          section.rawSection.sourceOffset +
          RawChkParser.headerLength +
          location.recordIndex * ChkLocation.recordLength,
      remediation:
          'Use left < right and top < bottom inside 0..$maximumX by '
          '0..$maximumY, or preserve the raw value if intentional.',
      rawDetails:
          'sectionIndex=${section.sectionIndex}; '
          'recordIndex=${location.recordIndex}; '
          'left=${location.left}; top=${location.top}; '
          'right=${location.right}; bottom=${location.bottom}; '
          'maximumX=$maximumX; maximumY=$maximumY',
    ),
  );
}

void _validateStringReference(
  List<EditorDiagnostic> diagnostics, {
  required ChkStringViews stringViews,
  required String sectionName,
  required int sectionIndex,
  required int sectionSourceOffset,
  required int fieldOffset,
  required int stringId,
  required String referenceLabel,
  required String rawDetails,
}) {
  if (stringId == 0) {
    return;
  }
  final tables = [...stringViews.legacyTables, ...stringViews.extendedTables];
  final byteOffset =
      sectionSourceOffset + RawChkParser.headerLength + fieldOffset;
  if (tables.length > 1) {
    diagnostics.add(
      _warning(
        code: ChkObjectReferenceDiagnosticCodes.stringTableAmbiguous,
        message:
            '$referenceLabel uses string ID $stringId, but multiple STR/STRx '
            'tables make the reference ambiguous.',
        sectionName: sectionName,
        byteOffset: byteOffset,
        remediation:
            'Inspect the raw string sections; the editor will not guess an '
            'active table.',
        rawDetails:
            '$rawDetails; stringId=$stringId; tableCount=${tables.length}; '
            'tableSectionIndexes=${tables.map((table) => table.sectionIndex).join(',')}',
      ),
    );
    return;
  }
  if (tables.isEmpty) {
    diagnostics.add(
      _warning(
        code: ChkObjectReferenceDiagnosticCodes.stringReferenceUnresolved,
        message:
            '$referenceLabel uses string ID $stringId, but no readable '
            'STR/STRx table is available.',
        sectionName: sectionName,
        byteOffset: byteOffset,
        remediation:
            'Inspect the raw string table before changing this reference.',
        rawDetails: '$rawDetails; stringId=$stringId; tableCount=0',
      ),
    );
    return;
  }
  final table = tables.single;
  final entry = table.entryForId(stringId);
  if (entry == null) {
    diagnostics.add(
      _warning(
        code: ChkObjectReferenceDiagnosticCodes.stringReferenceOutOfRange,
        message:
            '$referenceLabel uses string ID $stringId, but the table contains '
            'only ${table.declaredStringCount} entries.',
        sectionName: sectionName,
        byteOffset: byteOffset,
        remediation:
            'Choose an existing string ID or clear the reference to ID 0.',
        rawDetails:
            '$rawDetails; stringId=$stringId; '
            'tableSectionIndex=${table.sectionIndex}; '
            'declaredStringCount=${table.declaredStringCount}',
      ),
    );
  } else if (!entry.isStructurallyValid) {
    diagnostics.add(
      _warning(
        code: ChkObjectReferenceDiagnosticCodes.stringReferenceUnresolved,
        message:
            '$referenceLabel uses string ID $stringId, whose raw entry cannot '
            'be resolved safely.',
        sectionName: sectionName,
        byteOffset: byteOffset,
        remediation:
            'Inspect the string table structural diagnostics and preserve the '
            'raw reference until the source is understood.',
        rawDetails:
            '$rawDetails; stringId=$stringId; '
            'tableSectionIndex=${table.sectionIndex}; '
            'rawOffset=${entry.rawOffset}',
      ),
    );
  }
}

EditorDiagnostic _warning({
  required String code,
  required String message,
  required String sectionName,
  required int byteOffset,
  required String remediation,
  required String rawDetails,
}) => EditorDiagnostic(
  code: code,
  message: message,
  severity: DiagnosticSeverity.warning,
  stage: DiagnosticStage.validate,
  sectionName: sectionName,
  byteOffset: byteOffset,
  remediation: remediation,
  rawDetails: rawDetails,
);
