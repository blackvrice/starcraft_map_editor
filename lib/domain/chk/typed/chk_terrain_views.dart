import 'dart:typed_data';

import '../../diagnostics/editor_diagnostic.dart';
import '../chk_section_names.dart';
import '../raw_chk_document.dart';
import '../raw_chk_parser.dart';
import '../raw_chk_section.dart';
import 'chk_typed_diagnostic_codes.dart';

final class ChkTerrainTileMapView {
  ChkTerrainTileMapView._({
    required this.sectionIndex,
    required this.rawSection,
    required this.width,
    required this.height,
    required List<int> rawTileValues,
  }) : rawTileValues = List.unmodifiable(rawTileValues);

  static const tileRecordLength = 2;

  final int sectionIndex;
  final RawChkSection rawSection;
  final int? width;
  final int? height;
  final List<int> rawTileValues;

  int get tileCount => rawTileValues.length;

  bool get hasGridDimensions => width != null && height != null;

  int rawTileValueAtIndex(int index) {
    RangeError.checkValidIndex(index, rawTileValues, 'index');
    return rawTileValues[index];
  }

  int rawTileValueAt({required int x, required int y}) {
    return rawTileValues[_gridIndex(x: x, y: y)];
  }

  RawChkSection withRawTileValueAtIndex({
    required int index,
    required int rawValue,
  }) {
    RangeError.checkValidIndex(index, rawTileValues, 'index');
    final updatedValues = rawTileValues.toList();
    updatedValues[index] = _checkUint16(rawValue, 'rawValue');
    return rawSection.withPayload(_encodeTileValues(updatedValues));
  }

  RawChkSection withRawTileValueAt({
    required int x,
    required int y,
    required int rawValue,
  }) {
    return withRawTileValueAtIndex(
      index: _gridIndex(x: x, y: y),
      rawValue: rawValue,
    );
  }

  RawChkSection withRawTileValues(Iterable<int> updatedValues) {
    final values = updatedValues.toList(growable: false);
    if (values.length != tileCount) {
      throw ArgumentError.value(
        values.length,
        'updatedValues',
        'The replacement must contain exactly $tileCount tile values.',
      );
    }

    for (var index = 0; index < values.length; index++) {
      _checkUint16(values[index], 'updatedValues[$index]');
    }
    return rawSection.withPayload(_encodeTileValues(values));
  }

  int _gridIndex({required int x, required int y}) {
    final resolvedWidth = width;
    final resolvedHeight = height;
    if (resolvedWidth == null || resolvedHeight == null) {
      throw StateError(
        'Grid coordinates require exactly one valid DIM section.',
      );
    }
    if (x < 0 || x >= resolvedWidth) {
      throw RangeError.range(x, 0, resolvedWidth - 1, 'x');
    }
    if (y < 0 || y >= resolvedHeight) {
      throw RangeError.range(y, 0, resolvedHeight - 1, 'y');
    }
    return y * resolvedWidth + x;
  }
}

final class ChkTerrainViews {
  ChkTerrainViews({
    required List<ChkTerrainTileMapView> tileMaps,
    required List<EditorDiagnostic> diagnostics,
  }) : tileMaps = List.unmodifiable(tileMaps),
       diagnostics = List.unmodifiable(diagnostics);

  final List<ChkTerrainTileMapView> tileMaps;
  final List<EditorDiagnostic> diagnostics;

  bool get hasBlockingDiagnostics =>
      diagnostics.any((diagnostic) => diagnostic.blocksOperation);
}

class ChkTerrainViewDecoder {
  const ChkTerrainViewDecoder();

  ChkTerrainViews decode(RawChkDocument document) {
    final tileMaps = <ChkTerrainTileMapView>[];
    final diagnostics = <EditorDiagnostic>[];
    final dimensions = _resolveUniqueDimensions(document);

    for (
      var sectionIndex = 0;
      sectionIndex < document.sections.length;
      sectionIndex++
    ) {
      final section = document.sections[sectionIndex];
      if (!ChkSectionNames.isTerrainTiles(section)) {
        continue;
      }

      if (section.declaredLength.isOdd) {
        diagnostics.add(
          _truncatedTileRecordDiagnostic(
            section: section,
            sectionIndex: sectionIndex,
          ),
        );
        continue;
      }

      if (dimensions != null) {
        final expectedTileCount = dimensions.width * dimensions.height;
        final actualTileCount =
            section.declaredLength ~/ ChkTerrainTileMapView.tileRecordLength;
        if (actualTileCount != expectedTileCount) {
          diagnostics.add(
            _tileCountMismatchDiagnostic(
              section: section,
              sectionIndex: sectionIndex,
              dimensions: dimensions,
              actualTileCount: actualTileCount,
            ),
          );
          continue;
        }
      }

      tileMaps.add(
        ChkTerrainTileMapView._(
          sectionIndex: sectionIndex,
          rawSection: section,
          width: dimensions?.width,
          height: dimensions?.height,
          rawTileValues: _decodeTileValues(section.payload),
        ),
      );
    }

    return ChkTerrainViews(tileMaps: tileMaps, diagnostics: diagnostics);
  }
}

final class _ChkTerrainDimensions {
  const _ChkTerrainDimensions({required this.width, required this.height});

  final int width;
  final int height;
}

_ChkTerrainDimensions? _resolveUniqueDimensions(RawChkDocument document) {
  final dimensions = <_ChkTerrainDimensions>[];

  for (final section in document.sections) {
    if (!ChkSectionNames.isDimensions(section) || section.declaredLength != 4) {
      continue;
    }

    final data = ByteData.sublistView(section.payload);
    dimensions.add(
      _ChkTerrainDimensions(
        width: data.getUint16(0, Endian.little),
        height: data.getUint16(2, Endian.little),
      ),
    );
  }

  if (dimensions.length != 1 ||
      dimensions.single.width == 0 ||
      dimensions.single.height == 0) {
    return null;
  }
  return dimensions.single;
}

List<int> _decodeTileValues(Uint8List payload) {
  final data = ByteData.sublistView(payload);
  return List<int>.generate(
    payload.length ~/ ChkTerrainTileMapView.tileRecordLength,
    (index) => data.getUint16(
      index * ChkTerrainTileMapView.tileRecordLength,
      Endian.little,
    ),
    growable: false,
  );
}

Uint8List _encodeTileValues(List<int> values) {
  final payload = Uint8List(
    values.length * ChkTerrainTileMapView.tileRecordLength,
  );
  final data = ByteData.sublistView(payload);

  for (var index = 0; index < values.length; index++) {
    data.setUint16(
      index * ChkTerrainTileMapView.tileRecordLength,
      values[index],
      Endian.little,
    );
  }
  return payload;
}

EditorDiagnostic _truncatedTileRecordDiagnostic({
  required RawChkSection section,
  required int sectionIndex,
}) {
  return EditorDiagnostic(
    code: ChkTypedDiagnosticCodes.terrainTileRecordTruncated,
    message:
        'Section "${section.name}" ends with an incomplete 2-byte tile '
        'record.',
    severity: DiagnosticSeverity.error,
    stage: DiagnosticStage.validate,
    sectionName: section.name,
    byteOffset:
        section.sourceOffset +
        RawChkParser.headerLength +
        section.declaredLength -
        1,
    remediation: 'Keep this terrain section unchanged and read-only.',
    rawDetails:
        'sectionIndex=$sectionIndex; '
        'tileRecordBytes=${ChkTerrainTileMapView.tileRecordLength}; '
        'actualPayloadBytes=${section.declaredLength}',
  );
}

EditorDiagnostic _tileCountMismatchDiagnostic({
  required RawChkSection section,
  required int sectionIndex,
  required _ChkTerrainDimensions dimensions,
  required int actualTileCount,
}) {
  final expectedTileCount = dimensions.width * dimensions.height;
  return EditorDiagnostic(
    code: ChkTypedDiagnosticCodes.terrainTileCountMismatch,
    message:
        'Section "${section.name}" contains $actualTileCount tiles, but '
        '${dimensions.width}x${dimensions.height} map dimensions require '
        '$expectedTileCount.',
    severity: DiagnosticSeverity.error,
    stage: DiagnosticStage.validate,
    sectionName: section.name,
    byteOffset: section.sourceOffset + RawChkParser.headerLength,
    remediation: 'Keep this terrain section unchanged and read-only.',
    rawDetails:
        'sectionIndex=$sectionIndex; '
        'mapWidth=${dimensions.width}; '
        'mapHeight=${dimensions.height}; '
        'expectedTileCount=$expectedTileCount; '
        'actualTileCount=$actualTileCount; '
        'expectedPayloadBytes='
        '${expectedTileCount * ChkTerrainTileMapView.tileRecordLength}; '
        'actualPayloadBytes=${section.declaredLength}',
  );
}

int _checkUint16(int value, String argumentName) {
  if (value < 0 || value > 0xffff) {
    throw RangeError.range(value, 0, 0xffff, argumentName);
  }
  return value;
}
