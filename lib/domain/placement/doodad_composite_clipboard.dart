import 'dart:typed_data';
import '../chk/chk.dart';
import '../chk/chk_basic_editing.dart';
import 'doodad_deletion_plan.dart';
import 'doodad_placement_recipe.dart';

/// One explicitly verified composite, including its source editor state.
class DoodadCompositeClipboard {
  DoodadCompositeClipboard._(this.recipe, this.record, this.overlay);
  final DoodadPlacementRecipe recipe;
  final List<int> record;
  final List<int>? overlay;

  static DoodadCompositeClipboard capture(
    RawChkDocument doc, {
    required DoodadPlacementRecipe recipe,
    required int recordIndex,
    int? overlayRecordIndex,
  }) {
    const e = ChkBasicEditing();
    // Enabled-state validation also verifies disabled sprite-unit overlays.
    e.setDoodadEnabled(
      doc,
      recipe: recipe,
      recordIndex: recordIndex,
      enabled: true,
      overlayRecordIndex: overlayRecordIndex,
    );
    final dd = e.section(doc, 'DD2 ', stride: 8)!.payload;
    final thg = overlayRecordIndex == null
        ? null
        : e.section(doc, 'THG2', stride: 10)!.payload;
    if (thg != null && recipe.overlay!.thg2Flags & 0x1000 == 0) {
      final flags = ByteData.sublistView(
        thg,
      ).getUint16(overlayRecordIndex! * 10 + 8, Endian.little);
      if (flags !=
          (recipe.overlay!.thg2Flags |
              (dd[recordIndex * 8 + 7] == 1 ? 0x8000 : 0))) {
        throw StateError(
          'Apply an explicit Doodad enabled state before copying inconsistent editor/overlay states.',
        );
      }
    }
    return DoodadCompositeClipboard._(
      recipe,
      List.unmodifiable(dd.sublist(recordIndex * 8, recordIndex * 8 + 8)),
      thg == null
          ? null
          : List.unmodifiable(
              thg.sublist(
                overlayRecordIndex! * 10,
                overlayRecordIndex * 10 + 10,
              ),
            ),
    );
  }

  static RawChkDocument cut(
    RawChkDocument doc, {
    required DoodadPlacementRecipe recipe,
    required int recordIndex,
    int? overlayRecordIndex,
  }) {
    const e = ChkBasicEditing();
    final normalized = e.setDoodadEnabled(
      doc,
      recipe: recipe,
      recordIndex: recordIndex,
      enabled: true,
      overlayRecordIndex: overlayRecordIndex,
    );
    final plan = DoodadDeletionPlan.create(
      document: normalized,
      recipe: recipe,
      recordIndex: recordIndex,
      confirmedOverlayRecordIndex: overlayRecordIndex,
    );
    var result = doc;
    for (final entry in plan.replacements.entries) {
      result = result.replaceSection(entry.key, entry.value);
    }
    return result;
  }

  RawChkDocument paste(
    RawChkDocument doc, {
    required int tileX,
    required int tileY,
  }) {
    const e = ChkBasicEditing();
    final (w, h) = e.dimensions(doc);
    RangeError.checkValueInInterval(tileX, 0, w - recipe.width, 'tileX');
    RangeError.checkValueInInterval(tileY, 0, h - recipe.height, 'tileY');
    final era = e.section(doc, 'ERA ');
    if (era == null ||
        era.payload.length != 2 ||
        ByteData.sublistView(era.payload).getUint16(0, Endian.little) !=
            recipe.tileset.rawValue) {
      throw StateError('Doodad clipboard tileset mismatch.');
    }
    final m = e.section(doc, 'MTXM'),
        t = e.section(doc, 'TILE'),
        dd = e.section(doc, 'DD2 ', stride: 8),
        s = e.section(doc, 'THG2', stride: 10);
    if (m == null ||
        t == null ||
        dd == null ||
        m.payload.length != w * h * 2 ||
        t.payload.length != w * h * 2 ||
        (overlay != null && s == null)) {
      throw StateError('Complete unique composite sections are required.');
    }
    final x = tileX * 32 + recipe.centerOffsetX,
        y = tileY * 32 + recipe.centerOffsetY;
    if (x >= w * 32 || y >= h * 32) {
      throw StateError('Doodad center outside map.');
    }
    final existing = ByteData.sublistView(dd.payload);
    for (var at = 0; at < existing.lengthInBytes; at += 8) {
      final ox = existing.getUint16(at + 2, Endian.little),
          oy = existing.getUint16(at + 4, Endian.little);
      if (ox + 256 > tileX * 32 &&
          ox - 256 < (tileX + recipe.width) * 32 &&
          oy + 256 > tileY * 32 &&
          oy - 256 < (tileY + recipe.height) * 32) {
        throw StateError('Nearby Doodad footprint ownership is ambiguous.');
      }
    }
    if (s != null) {
      final sprites = ByteData.sublistView(s.payload);
      for (var at = 0; at < sprites.lengthInBytes; at += 10) {
        if (sprites.getUint16(at + 2, Endian.little) == x &&
            sprites.getUint16(at + 4, Endian.little) == y) {
          throw StateError('Destination overlay ownership would be ambiguous.');
        }
      }
    }
    final terrain = ByteData.sublistView(m.payload),
        underlying = ByteData.sublistView(t.payload);
    for (final cell in recipe.footprint) {
      final at = ((tileY + cell.y) * w + tileX + cell.x) * 2,
          v = terrain.getUint16(at, Endian.little);
      if (underlying.getUint16(at, Endian.little) != v ||
          (cell.requiredTileGroup != 0 && v >> 4 != cell.requiredTileGroup) ||
          (cell.writesTerrain && v == cell.rawTileValue)) {
        throw StateError(
          'Destination underlying terrain does not match the verified recipe.',
        );
      }
      if (cell.writesTerrain) {
        terrain.setUint16(at, cell.rawTileValue!, Endian.little);
      }
    }
    final newDd = Uint8List.fromList(record);
    ByteData.sublistView(newDd)
      ..setUint16(2, x, Endian.little)
      ..setUint16(4, y, Endian.little);
    var result = doc.replaceSection(
      doc.sections.indexOf(m),
      m.withPayload(terrain.buffer.asUint8List()),
    );
    result = result.replaceSection(
      doc.sections.indexOf(dd),
      dd.withPayload([...dd.payload, ...newDd]),
    );
    if (overlay != null) {
      final bytes = Uint8List.fromList(overlay!);
      ByteData.sublistView(bytes)
        ..setUint16(2, x, Endian.little)
        ..setUint16(4, y, Endian.little);
      result = result.replaceSection(
        doc.sections.indexOf(s!),
        s.withPayload([...s.payload, ...bytes]),
      );
    }
    return result;
  }
}
