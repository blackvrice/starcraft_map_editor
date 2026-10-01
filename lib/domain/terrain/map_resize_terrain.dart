import 'dart:typed_data';
import '../chk/raw_chk_document.dart';
import '../chk/typed/chk_terrain_views.dart';
import '../placement/doodad_placement_recipe.dart';
import 'isom_doodad_overlay.dart';
import 'isom_terrain_conversion.dart';
import 'isom_terrain_fill.dart';
import 'isom_terrain_paint.dart';

final class MapResizeTerrainData {
  MapResizeTerrainData({
    required this.catalog,
    required this.brush,
    required Map<int, int> solids,
    required List<DoodadPlacementRecipe> recipes,
  }) : solids = Map.unmodifiable(solids),
       recipes = List.unmodifiable(recipes);
  final IsomTerrainCatalog catalog;
  final IsomBrushCatalog brush;
  final Map<int, int> solids;
  final List<DoodadPlacementRecipe> recipes;
}

final class MapResizeTerrainResult {
  const MapResizeTerrainResult({
    this.document,
    this.movedDoodads = 0,
    this.outsideDoodads = 0,
    this.recalculatedTiles = 0,
    this.blockers = const [],
  });
  final RawChkDocument? document;
  final int movedDoodads, outsideDoodads, recalculatedTiles;
  final List<String> blockers;
}

/// Translates known diamonds; only the new area may propagate boundaries.
/// Doodad footprints and every object's record identity are preserved.
class MapResizeTerrainEditor {
  const MapResizeTerrainEditor();
  MapResizeTerrainResult resize(
    RawChkDocument source,
    RawChkDocument resized,
    MapResizeTerrainData data, {
    required int dx,
    required int dy,
    required int fillX,
    required int fillY,
  }) {
    final overlay = IsomDoodadOverlay.read(
      source,
      data.recipes,
      allowDisabled: true,
    );
    final view = const ChkTerrainViewDecoder().decode(resized).tileMaps.single;
    final w = view.width!, h = view.height!;
    final outside = overlay.bounds.where((b) => !b.fits(w, h, dx, dy)).length;
    final moved = dx == 0 && dy == 0 ? 0 : overlay.bounds.length - outside;
    if (outside > 0) {
      return MapResizeTerrainResult(
        movedDoodads: moved,
        outsideDoodads: outside,
        blockers: [
          '$outside doodad footprints would leave the map. Move them or change the anchor/size; no records are deleted.',
        ],
      );
    }
    var result = resized;
    var recalculated = 0;
    if (source.sections.any((s) => s.name == 'ISOM')) {
      if (dx % 4 != 0 || dy % 2 != 0) {
        throw StateError(
          'ISOM translation requires a multiple of 4 tiles horizontally and 2 vertically. Change the anchor/size.',
        );
      }
      const paint = IsomTerrainPaint();
      // No-op assignment validates the complete original adjacency and stack path.
      paint.previewShapes(
        overlay.base,
        data.catalog,
        data.brush,
        assignments: {},
      );
      final old = IsomTerrainPaint.readDiamonds(overlay.base, data.brush);
      final oldView = const ChkTerrainViewDecoder()
          .decode(source)
          .tileMaps
          .single;
      final sample = old[IsomTerrainPaint.diamondAtTile(fillX, fillY)];
      final adding = w > oldView.width! || h > oldView.height!;
      final solid = adding ? sample : data.solids.values.first;
      if (solid == null || !data.solids.values.contains(solid)) {
        throw StateError(
          'Choose a flat ISOM diamond as the fill sample; boundary and doodad tiles are not fill terrain.',
        );
      }
      final baseTile = resized.sections
          .singleWhere((s) => s.name == 'TILE')
          .payload;
      var template = RawChkDocument(
        sections: [
          for (final s in resized.sections)
            if (s.name != 'ISOM')
              s.name == 'DD2 '
                  ? s.withPayload([])
                  : s.name == 'MTXM'
                  ? s.withPayload(baseTile)
                  : s,
        ],
        sourceLength: resized.sourceLength,
      );
      template = const IsomTerrainFill()
          .preview(template, data.catalog, solidValue: solid << 4, seed: 0)
          .result;
      final assignments = <IsomDiamond, int>{};
      final preferred = <IsomDiamond, int>{};
      for (final e in old.entries) {
        final d = (e.key.$1 + dx ~/ 2, e.key.$2 + dy);
        if (d.$1 >= 0 && d.$1 <= w ~/ 2 && d.$2 >= 0 && d.$2 <= h) {
          preferred[d] = e.value;
          // A formerly clipped diamond needs its newly exposed sides resolved.
          final exposed =
              (e.key.$1 == 0 && d.$1 > 0) ||
              (e.key.$1 == oldView.width! ~/ 2 && d.$1 < w ~/ 2) ||
              (e.key.$2 == 0 && d.$2 > 0) ||
              (e.key.$2 == oldView.height! && d.$2 < h);
          if (!exposed) assignments[d] = e.value;
        }
      }
      result = paint
          .previewShapes(
            template,
            data.catalog,
            data.brush,
            assignments: assignments,
            solveRegion: true,
            preferredShapes: preferred,
          )
          .result;
      final isom = result.sections.singleWhere((s) => s.name == 'ISOM');
      final newBytes = isom.payload;
      final newData = ByteData.sublistView(newBytes);
      final original = ByteData.sublistView(
        source.sections.singleWhere((s) => s.name == 'ISOM').payload,
      );
      final ow = oldView.width! ~/ 2 + 1;
      // Preserve old flags and raw values wherever the translated shape survives.
      for (var y = 0; y <= oldView.height!; y++) {
        for (var x = 0; x < ow; x++) {
          final nx = x + dx ~/ 2, ny = y + dy;
          if (nx < 0 || nx > w ~/ 2 || ny < 0 || ny > h) continue;
          for (var side = 0; side < 4; side++) {
            final from = (y * ow + x) * 8 + side * 2,
                to = (ny * (w ~/ 2 + 1) + nx) * 8 + side * 2;
            final before = original.getUint16(from, Endian.little),
                after = newData.getUint16(to, Endian.little);
            newData.setUint16(
              to,
              (before & 0x7ff0) == (after & 0x7ff0)
                  ? before
                  : (after & 0x7ffe) | (before & 0x8001),
              Endian.little,
            );
          }
        }
      }
      result = _put(result, 'ISOM', newBytes);
      // Prefer exact overlap tile members while solving complete resized columns.
      result = _put(_put(result, 'TILE', baseTile), 'MTXM', baseTile);
      final converted = const IsomTerrainConverter().preview(
        result,
        data.catalog,
        seed: 0,
      );
      result = converted.result;
      recalculated = converted.changedTileCount;
      // Restore source section order, translated objects and original unknown bytes.
      result = RawChkDocument(
        sections: [
          for (final s in resized.sections)
            ['ISOM', 'TILE', 'MTXM'].contains(s.name)
                ? result.sections.singleWhere((r) => r.name == s.name)
                : s,
        ],
        sourceLength: resized.sourceLength,
      );
      result = overlay.restoreResized(result, dx, dy);
    }
    IsomDoodadOverlay.read(result, data.recipes, allowDisabled: true);
    return MapResizeTerrainResult(
      document: result,
      movedDoodads: moved,
      outsideDoodads: outside,
      recalculatedTiles: recalculated,
    );
  }

  RawChkDocument _put(RawChkDocument doc, String name, List<int> bytes) {
    final i = doc.sections.indexWhere((s) => s.name == name);
    return doc.replaceSection(i, doc.sections[i].withPayload(bytes));
  }
}
