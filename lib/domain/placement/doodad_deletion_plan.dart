import 'dart:typed_data';

import '../chk/chk.dart';
import 'doodad_placement_recipe.dart';
import 'unit_deletion_plan.dart';

final class DoodadDeletionRequest {
  const DoodadDeletionRequest({
    required this.recipe,
    required this.recordIndex,
    this.confirmedOverlayRecordIndex,
  });
  final DoodadPlacementRecipe recipe;
  final int recordIndex;
  final int? confirmedOverlayRecordIndex;
}

/// Existing maps carry no overlay ownership ID. The caller must explicitly
/// choose the overlay record; coordinate equality alone never grants ownership.
final class DoodadDeletionPlan {
  DoodadDeletionPlan._(
    this.document,
    this.replacements,
    this._restoredTiles,
    this.doodadCount,
    this.overlayCount,
    this.spriteCount, {
    this.unitDeletion,
  });
  final RawChkDocument document;
  final Map<int, RawChkSection> replacements;
  final Map<int, int> _restoredTiles;
  final int doodadCount, overlayCount, spriteCount;
  final UnitDeletionPlan? unitDeletion;
  static const maximumBatchSize = 32;
  static const maximumSelectedSprites = 256;

  static DoodadDeletionPlan create({
    required RawChkDocument document,
    required DoodadPlacementRecipe recipe,
    required int recordIndex,
    int? confirmedOverlayRecordIndex,
  }) => _create(
    document: document,
    recipe: recipe,
    recordIndex: recordIndex,
    confirmedOverlayRecordIndex: confirmedOverlayRecordIndex,
    reviewedNeighbors: const {},
  );

  static DoodadDeletionPlan createBatch({
    required RawChkDocument document,
    required Iterable<DoodadDeletionRequest> requests,
    Iterable<int> selectedSpriteRecordIndices = const [],
    Iterable<int> selectedUnitRecordIndices = const [],
    Iterable<int> confirmedUnitPeerRecordIndices = const [],
  }) {
    final items = requests.take(maximumBatchSize + 1).toList();
    if (items.isEmpty || items.length > maximumBatchSize) {
      throw StateError('DOODAD_DELETE: batch size');
    }
    final selectedSprites = selectedSpriteRecordIndices
        .take(maximumSelectedSprites + 1)
        .toList();
    if (selectedSprites.length > maximumSelectedSprites ||
        selectedSprites.toSet().length != selectedSprites.length) {
      throw StateError('DOODAD_DELETE: selected sprite count or duplicates');
    }
    final unitIndices = selectedUnitRecordIndices
        .take(UnitDeletionPlan.maximumSelectedUnits + 1)
        .toList();
    final unitDeletion = unitIndices.isEmpty
        ? null
        : UnitDeletionPlan.create(
            document: document,
            recordIndices: unitIndices,
          );
    final confirmedPeers = confirmedUnitPeerRecordIndices
        .take(UnitDeletionPlan.maximumSelectedUnits + 1)
        .toList();
    final expectedPeers =
        unitDeletion?.unlinkedPeerRecordIndices ?? const <int>{};
    if (confirmedPeers.length != expectedPeers.length ||
        confirmedPeers.toSet().length != confirmedPeers.length ||
        !expectedPeers.containsAll(confirmedPeers)) {
      throw StateError(
        'UNIT_DELETE: explicit surviving peer confirmation required',
      );
    }
    final records = items.map((r) => r.recordIndex).toSet();
    final overlays = items
        .map((r) => r.confirmedOverlayRecordIndex)
        .whereType<int>()
        .toList();
    if (records.length != items.length ||
        overlays.toSet().length != overlays.length) {
      throw StateError('DOODAD_DELETE: duplicate record ownership');
    }
    final neighbors = {for (final r in items) r.recordIndex: r.recipe};
    final restored = <int, int>{};
    // Validate every request against the same immutable source before merging.
    // Deleting sequentially would shift DD2/THG2 indices and could leave partial edits.
    for (final request in items) {
      final plan = _create(
        document: document,
        recipe: request.recipe,
        recordIndex: request.recordIndex,
        confirmedOverlayRecordIndex: request.confirmedOverlayRecordIndex,
        reviewedNeighbors: neighbors,
        buildReplacements: false,
      );
      for (final tile in plan._restoredTiles.entries) {
        if (restored.containsKey(tile.key)) {
          throw StateError('DOODAD_DELETE: overlapping restore cells');
        }
        restored[tile.key] = tile.value;
      }
    }
    final objects = const ChkObjectViewDecoder().decode(document),
        terrain = const ChkTerrainViewDecoder()
            .decode(document)
            .tileMaps
            .single;
    // Merge original THG2 indices, never indices from an already-deleted view.
    // A separately selected, explicitly confirmed overlay is removed only once.
    final spriteIndices = {...overlays, ...selectedSprites};
    if (spriteIndices.isNotEmpty) {
      final rawSprites = document.sections.where(
        (s) => s.hasNameBytes(ChkSectionNames.spritePlacements),
      );
      if (rawSprites.length != 1 ||
          objects.spriteSections.length != 1 ||
          rawSprites.single.declaredLength !=
              objects.spriteSections.single.sprites.length *
                  ChkSpritePlacement.recordLength) {
        throw StateError('DOODAD_DELETE: requires one complete THG2 section');
      }
      final sprites = objects.spriteSections.single;
      for (final index in spriteIndices) {
        if (index < 0 || index >= sprites.sprites.length) {
          throw StateError('DOODAD_DELETE: invalid selected sprite');
        }
      }
    }
    final values = terrain.rawTileValues.toList();
    for (final tile in restored.entries) {
      values[tile.key] = tile.value;
    }
    const editor = ChkObjectSectionEditor();
    final dd = objects.doodadSections.single;
    final replacements = <int, RawChkSection>{
      terrain.sectionIndex: terrain.withRawTileValues(values),
      dd.sectionIndex: editor.deleteDoodads(dd, records),
      if (unitDeletion != null)
        unitDeletion.sectionIndex: unitDeletion.replacement,
    };
    if (spriteIndices.isNotEmpty) {
      final sprites = objects.spriteSections.single;
      replacements[sprites.sectionIndex] = editor.deleteSprites(
        sprites,
        spriteIndices,
      );
    }
    return DoodadDeletionPlan._(
      document,
      Map.unmodifiable(replacements),
      Map.unmodifiable(restored),
      items.length,
      overlays.length,
      spriteIndices.length,
      unitDeletion: unitDeletion,
    );
  }

  static DoodadDeletionPlan _create({
    required RawChkDocument document,
    required DoodadPlacementRecipe recipe,
    required int recordIndex,
    required int? confirmedOverlayRecordIndex,
    required Map<int, DoodadPlacementRecipe> reviewedNeighbors,
    bool buildReplacements = true,
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
        (doodad.enabledValue != 0 && doodad.enabledValue != 1)) {
      reject(
        'recipe does not match a known doodad state (${doodad.doodadType}/${doodad.enabledValue}, expected type ${recipe.doodadType}, state 0 or 1)',
      );
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
      final reviewed = reviewedNeighbors[other.recordIndex];
      if (reviewed != null) {
        final left = other.x - reviewed.centerOffsetX,
            top = other.y - reviewed.centerOffsetY;
        if (left < dx + recipe.width * 32 &&
            left + reviewed.width * 32 > dx &&
            top < dy + recipe.height * 32 &&
            top + reviewed.height * 32 > dy) {
          reject('reviewed doodad footprints overlap');
        }
        continue;
      }
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
    final values = terrain.rawTileValues;
    final restoredTiles = <int, int>{};
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
      restoredTiles[index] = restored;
    }
    const editor = ChkObjectSectionEditor();
    final replacements = <int, RawChkSection>{};
    if (buildReplacements) {
      final output = values.toList();
      for (final tile in restoredTiles.entries) {
        output[tile.key] = tile.value;
      }
      replacements[terrain.sectionIndex] = terrain.withRawTileValues(output);
      replacements[section.sectionIndex] = editor.deleteDoodads(section, {
        recordIndex,
      });
    }
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
          sprite.flags != overlay.flagsForEnabled(doodad.enabledValue == 0) ||
          sprite.unused != 0) {
        reject('overlay does not match recipe');
      }
      if (buildReplacements) {
        replacements[sprites.sectionIndex] = editor.deleteSprites(sprites, {
          index,
        });
      }
    } else if (confirmedOverlayRecordIndex != null) {
      reject('recipe has no overlay');
    }
    return DoodadDeletionPlan._(
      document,
      Map.unmodifiable(replacements),
      Map.unmodifiable(restoredTiles),
      1,
      overlay == null ? 0 : 1,
      overlay == null ? 0 : 1,
    );
  }
}
