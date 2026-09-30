import 'dart:typed_data';
import '../raw_chk_document.dart';
import '../raw_chk_section.dart';

enum EditorTerrainSectionState {
  validStructure,
  invalidSize,
  unknownDimensions,
  protectionMarker,
}

/// Raw little-endian sides, without clearing flags or guessing terrain types.
final class ChkIsomRectangle {
  const ChkIsomRectangle(this.left, this.top, this.right, this.bottom);
  final int left, top, right, bottom;
}

final class EditorTerrainSection {
  EditorTerrainSection._({
    required this.sectionIndex,
    required this.rawSection,
    required this.state,
    required this.expectedBytes,
    required this.columns,
    required this.rows,
  }) : _bytes = ByteData.sublistView(rawSection.payload);
  final int sectionIndex;
  final RawChkSection rawSection;
  final EditorTerrainSectionState state;
  final int? expectedBytes, columns, rows;
  final ByteData _bytes;
  bool get hasValidStructure =>
      state == EditorTerrainSectionState.validStructure;

  ChkIsomRectangle isomAt(int x, int y) {
    if (!hasValidStructure || rawSection.name != 'ISOM') {
      throw StateError('A structurally valid ISOM grid is required.');
    }
    RangeError.checkValueInInterval(x, 0, columns! - 1, 'x');
    RangeError.checkValueInInterval(y, 0, rows! - 1, 'y');
    final offset = (y * columns! + x) * 8;
    return ChkIsomRectangle(
      _bytes.getUint16(offset, Endian.little),
      _bytes.getUint16(offset + 2, Endian.little),
      _bytes.getUint16(offset + 4, Endian.little),
      _bytes.getUint16(offset + 6, Endian.little),
    );
  }

  int tileAt(int x, int y) {
    if (!hasValidStructure || !['MTXM', 'TILE'].contains(rawSection.name)) {
      throw StateError('A structurally valid tile grid is required.');
    }
    RangeError.checkValueInInterval(x, 0, columns! - 1, 'x');
    RangeError.checkValueInInterval(y, 0, rows! - 1, 'y');
    return _bytes.getUint16((y * columns! + x) * 2, Endian.little);
  }
}

/// Structural inspection only; this does not certify ISOM shape links or ramps.
final class ChkEditorTerrainReport {
  ChkEditorTerrainReport._({
    required this.width,
    required this.height,
    required List<EditorTerrainSection> sections,
    required List<String> duplicateNames,
    required this.differentTileCount,
    required this.hasDoodads,
  }) : sections = List.unmodifiable(sections),
       duplicateNames = List.unmodifiable(duplicateNames);
  final int? width, height;
  final List<EditorTerrainSection> sections;
  final List<String> duplicateNames;
  final int? differentTileCount;
  final bool hasDoodads;
  bool get hasProtectionMarker => sections.any(
    (s) => s.state == EditorTerrainSectionState.protectionMarker,
  );
  bool get hasIsom => sections.any((s) => s.rawSection.name == 'ISOM');
}

class ChkEditorTerrainDecoder {
  const ChkEditorTerrainDecoder();

  ChkEditorTerrainReport decode(RawChkDocument document) {
    final dimensions = document.sections
        .where((s) => s.name == 'DIM ')
        .toList();
    int? width, height;
    if (dimensions.length == 1 && dimensions.single.payload.length == 4) {
      final d = ByteData.sublistView(dimensions.single.payload);
      if (d.getUint16(0, Endian.little) > 0 &&
          d.getUint16(2, Endian.little) > 0) {
        width = d.getUint16(0, Endian.little);
        height = d.getUint16(2, Endian.little);
      }
    }
    final sections = <EditorTerrainSection>[];
    for (var i = 0; i < document.sections.length; i++) {
      final s = document.sections[i];
      if (!['MTXM', 'TILE', 'ISOM'].contains(s.name)) continue;
      final columns = width == null
          ? null
          : s.name == 'ISOM'
          ? width ~/ 2 + 1
          : width;
      final rows = height == null
          ? null
          : s.name == 'ISOM'
          ? height + 1
          : height;
      final expected = columns == null || rows == null
          ? null
          : columns * rows * (s.name == 'ISOM' ? 8 : 2);
      final state = s.isEuddraftProtectionMarker
          ? EditorTerrainSectionState.protectionMarker
          : expected == null
          ? EditorTerrainSectionState.unknownDimensions
          : s.declaredLength != expected
          ? EditorTerrainSectionState.invalidSize
          : EditorTerrainSectionState.validStructure;
      sections.add(
        EditorTerrainSection._(
          sectionIndex: i,
          rawSection: s,
          state: state,
          expectedBytes: expected,
          columns: columns,
          rows: rows,
        ),
      );
    }
    final duplicates = [
      for (final name in ['DIM ', 'MTXM', 'TILE', 'ISOM'])
        if (document.sections.where((s) => s.name == name).length > 1) name,
    ];
    final game = sections.where((s) => s.rawSection.name == 'MTXM').toList();
    final editor = sections.where((s) => s.rawSection.name == 'TILE').toList();
    int? different;
    if (game.length == 1 &&
        editor.length == 1 &&
        game.single.hasValidStructure &&
        editor.single.hasValidStructure) {
      var count = 0;
      final a = game.single._bytes, b = editor.single._bytes;
      for (var i = 0; i < a.lengthInBytes; i += 2) {
        if (a.getUint16(i, Endian.little) != b.getUint16(i, Endian.little)) {
          count++;
        }
      }
      different = count;
    }
    return ChkEditorTerrainReport._(
      width: width,
      height: height,
      sections: sections,
      duplicateNames: duplicates,
      differentTileCount: different,
      hasDoodads: document.sections.any(
        (s) => s.name == 'DD2 ' && s.payload.isNotEmpty,
      ),
    );
  }
}
