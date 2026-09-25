import 'dart:typed_data';

import '../chk/chk.dart';
import 'doodad_placement_recipe.dart';

/// Existing maps carry no overlay ownership ID. The caller must explicitly
/// choose the overlay record; coordinate equality alone never grants ownership.
final class DoodadDeletionPlan {
  DoodadDeletionPlan._(this.document, this.replacements);
  final RawChkDocument document;
  final Map<int, RawChkSection> replacements;

  static DoodadDeletionPlan create({
    required RawChkDocument document,
    required DoodadPlacementRecipe recipe,
    required int recordIndex,
    int? confirmedOverlayRecordIndex,
  }) {
    Never reject(String reason) => throw StateError('DOODAD_DELETE: $reason');
    int unique(String name) {
      final indices = [
        for (var i = 0; i < document.sections.length; i++)
          if (document.sections[i].hasNameBytes(name.codeUnits)) i,
      ];
      if (indices.length != 1) reject('requires one $name section');
      return indices.single;
    }

    unique('DIM ');
    unique('ERA ');
    unique('MTXM');
    unique('DD2 ');
    final underlyingIndex = unique('TILE');
    final metadata = const ChkMetadataViewDecoder().decode(document);
    final terrain = const ChkTerrainViewDecoder()
        .decode(document)
        .tileMaps
        .single;
    final objects = const ChkObjectViewDecoder().decode(document);
    if (metadata.tilesets.length != 1 ||
        metadata.tilesets.single.rawValue != recipe.tileset.rawValue ||
        terrain.width == null ||
        terrain.height == null ||
        objects.doodadSections.length != 1) {
      reject('invalid tileset, dimensions or object sections');
    }
    final section = objects.doodadSections.single;
    if (recordIndex < 0 || recordIndex >= section.doodads.length) {
      reject('invalid record');
    }
    final doodad = section.doodads[recordIndex];
    if (doodad.doodadType != recipe.doodadType ||
        doodad.enabledValue != recipe.enabledValue) {
      reject('recipe does not match enabled doodad');
    }
    final dx = doodad.x - recipe.centerOffsetX;
    final dy = doodad.y - recipe.centerOffsetY;
    if (dx < 0 || dy < 0 || dx % 32 != 0 || dy % 32 != 0) {
      reject('unaligned footprint');
    }
    final x = dx ~/ 32, y = dy ~/ 32;
    if (x + recipe.width > terrain.width! ||
        y + recipe.height > terrain.height!) {
      reject('footprint outside map');
    }
    // With no verified recipe for neighbors, conservatively exclude every
    // possible intersection with their maximum 16x16 footprint.
    for (final other in section.doodads) {
      if (other.recordIndex == recordIndex) continue;
      if (other.x + 256 > dx &&
          other.x - 256 < dx + recipe.width * 32 &&
          other.y + 256 > dy &&
          other.y - 256 < dy + recipe.height * 32) {
        reject('nearby doodad ownership is ambiguous');
      }
    }
    final underlying = document.sections[underlyingIndex].payload;
    if (underlying.length != terrain.width! * terrain.height! * 2) {
      reject('invalid TILE length');
    }
    final data = ByteData.sublistView(underlying);
    final values = terrain.rawTileValues.toList();
    for (final cell in recipe.footprint) {
      if (!cell.writesTerrain) continue;
      final index = (y + cell.y) * terrain.width! + x + cell.x;
      if (values[index] != cell.rawTileValue) {
        reject('terrain no longer matches the recipe');
      }
      final restored = data.getUint16(index * 2, Endian.little);
      if (restored == cell.rawTileValue ||
          (cell.requiredTileGroup != 0 &&
              restored >> 4 != cell.requiredTileGroup)) {
        reject('TILE is not verified underlying terrain');
      }
      values[index] = restored;
    }
    const editor = ChkObjectSectionEditor();
    final replacements = <int, RawChkSection>{
      terrain.sectionIndex: terrain.withRawTileValues(values),
      section.sectionIndex: editor.deleteDoodads(section, {recordIndex}),
    };
    final overlay = recipe.overlay;
    if (overlay != null) {
      unique('THG2');
      if (objects.spriteSections.length != 1 ||
          confirmedOverlayRecordIndex == null) {
        reject('explicit overlay selection required');
      }
      final sprites = objects.spriteSections.single;
      final index = confirmedOverlayRecordIndex;
      if (index < 0 || index >= sprites.sprites.length) {
        reject('invalid overlay record');
      }
      final sprite = sprites.sprites[index];
      if (sprite.spriteType != overlay.id ||
          sprite.x != doodad.x ||
          sprite.y != doodad.y ||
          sprite.owner != doodad.owner ||
          sprite.flags != overlay.thg2Flags ||
          sprite.unused != 0) {
        reject('overlay does not match recipe');
      }
      replacements[sprites.sectionIndex] = editor.deleteSprites(sprites, {
        index,
      });
    } else if (confirmedOverlayRecordIndex != null) {
      reject('recipe has no overlay');
    }
    return DoodadDeletionPlan._(document, Map.unmodifiable(replacements));
  }
}
