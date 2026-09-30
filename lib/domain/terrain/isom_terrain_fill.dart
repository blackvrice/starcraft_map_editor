import 'dart:typed_data';
import '../chk/raw_chk_document.dart';
import '../chk/raw_chk_section.dart';
import '../chk/typed/chk_editor_terrain.dart';
import 'isom_terrain_conversion.dart';

final class IsomFillPreview {
  const IsomFillPreview._(
    this.source,
    this.result,
    this.changedTileCount,
    this.isomChanged,
    this.catalogRevision,
  );
  final RawChkDocument source, result;
  final int changedTileCount;
  final bool isomChanged;
  final String catalogRevision;
  bool get hasChanges => changedTileCount > 0 || isomChanged;
}

/// Explicit whole-map replacement, never automatic ISOM repair.
class IsomTerrainFill {
  const IsomTerrainFill();
  IsomFillPreview preview(
    RawChkDocument source,
    IsomTerrainCatalog catalog, {
    required int solidValue,
    required int seed,
  }) {
    final report = const ChkEditorTerrainDecoder().decode(source);
    final w = report.width, h = report.height;
    if (w == null ||
        h == null ||
        w.isOdd ||
        w > 256 ||
        h > 256 ||
        report.duplicateNames.isNotEmpty ||
        report.hasProtectionMarker ||
        report.hasDoodads ||
        report.differentTileCount != 0 ||
        report.sections.any((s) => !s.hasValidStructure)) {
      throw StateError(
        'ISOM fill requires matching valid TILE/MTXM, even width, no protection or doodads.',
      );
    }
    final known = {for (final e in catalog.edges) e.value: e};
    final edge = known[solidValue];
    if (edge == null ||
        solidValue & 15 != 0 ||
        !catalog.pairs.any(
          (p) =>
              p.terrainType == edge.terrainType &&
              p.isUnstacked &&
              p.links.every((v) => v == edge.link),
        )) {
      throw StateError('A verified solid shape is required.');
    }
    final old = report.sections.where((s) => s.rawSection.name == 'ISOM');
    if (old.isNotEmpty) {
      final d = ByteData.sublistView(old.single.rawSection.payload);
      for (var i = 0; i < d.lengthInBytes; i += 2) {
        if (!known.containsKey(d.getUint16(i, Endian.little) & 0x7ffe)) {
          throw StateError(
            'Existing ISOM includes unsupported shapes; it is preserved.',
          );
        }
      }
    }
    final data = ByteData((w ~/ 2 + 1) * (h + 1) * 8);
    for (var i = 0; i < data.lengthInBytes; i += 2) {
      data.setUint16(i, solidValue, Endian.little);
    }
    final bytes = data.buffer.asUint8List();
    final oldBytes = old.isEmpty ? null : old.single.rawSection.payload;
    var changed = oldBytes == null;
    if (oldBytes != null) {
      for (var i = 0; i < bytes.length; i++) {
        if (bytes[i] != oldBytes[i]) {
          changed = true;
          break;
        }
      }
    }
    var staged = source;
    if (changed) {
      staged = old.isEmpty
          ? source.appendSection(
              RawChkSection(
                nameBytes: 'ISOM'.codeUnits,
                declaredLength: bytes.length,
                payload: bytes,
                sourceOffset: source.sourceLength,
                isDirty: true,
              ),
            )
          : source.replaceSection(
              old.single.sectionIndex,
              old.single.rawSection.withPayload(bytes),
            );
    }
    final converted = const IsomTerrainConverter().preview(
      staged,
      catalog,
      seed: seed,
    );
    return IsomFillPreview._(
      source,
      converted.result,
      converted.changedTileCount,
      changed,
      catalog.revision,
    );
  }
}
