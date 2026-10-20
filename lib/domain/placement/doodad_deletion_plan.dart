import 'dart:typed_data';

import '../chk/chk.dart';
import 'doodad_placement_recipe.dart';
import 'unit_deletion_plan.dart';
import 'location_deletion_plan.dart';

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
    this.locationDeletion,
    this.preservedNeighborRecordIndices = const {},
  });
  final RawChkDocument document;
  final Map<int, RawChkSection> replacements;
  final Map<int, int> _restoredTiles;
  final int doodadCount, overlayCount, spriteCount;
  final UnitDeletionPlan? unitDeletion;
  final LocationDeletionPlan? locationDeletion;
  final Set<int> preservedNeighborRecordIndices;
  static const maximumBatchSize = 32;
  static const maximumRecipeTypes = 32;
  static const maximumSelectedSprites = 256;
  static const maximumPreservedNeighbors = 256;
  static const maximumNeighborRecipeCandidates = 256;
  static const maximumNeighborCandidateCells = 262144;
  static const _maximumHalfExtent =
      DoodadPlacementRecipe.maximumFootprintAxis *
      DoodadPlacementRecipe.halfTilePixels;

  /// Chooses metadata types, not deletion targets. Before recipes are loaded,
  /// both centers need their maximum possible half-extent. Exceeding the lookup
  /// budget falls back to selected types; Apply still performs the exact checks.
  static Set<int> recipeLookupTypes({
    required ChkDoodadSectionView section,
    required Iterable<int> recordIndices,
  }) {
    final indices = recordIndices.take(maximumBatchSize + 1).toList();
    final selectedIndices = indices.toSet();
    if (indices.isEmpty ||
        indices.length > maximumBatchSize ||
        selectedIndices.length != indices.length ||
        indices.any((i) => i < 0 || i >= section.doodads.length)) {
      throw StateError('DOODAD_DELETE: invalid recipe lookup selection');
    }
    final selected = [for (final i in indices) section.doodads[i]];
    final selectedTypes = selected.map((d) => d.doodadType).toSet();
    final types = {...selectedTypes};
    var neighborCount = 0;
    for (final other in section.doodads) {
      if (selectedIndices.contains(other.recordIndex) ||
          !selected.any(
            (d) =>
                (d.x - other.x).abs() < _maximumHalfExtent * 2 &&
                (d.y - other.y).abs() < _maximumHalfExtent * 2,
          )) {
        continue;
      }
      neighborCount++;
      types.add(other.doodadType);
      if (neighborCount > maximumPreservedNeighbors ||
          types.length > maximumRecipeTypes) {
        return Set.unmodifiable(selectedTypes);
      }
    }
    return Set.unmodifiable(types);
  }

  static DoodadDeletionPlan create({
    required RawChkDocument document,
    required DoodadPlacementRecipe recipe,
    required int recordIndex,
    int? confirmedOverlayRecordIndex,
    Map<int, DoodadPlacementRecipe> retainedNeighborRecipes = const {},
    Map<int, Iterable<DoodadPlacementRecipe>> retainedNeighborCandidates =
        const {},
  }) => _create(
    document: document,
    recipe: recipe,
    recordIndex: recordIndex,
    confirmedOverlayRecordIndex: confirmedOverlayRecordIndex,
    reviewedNeighbors: const {},
    retainedNeighbors: _RetainedNeighborReview(
      retainedNeighborRecipes,
      retainedNeighborCandidates,
    ),
  );

  static DoodadDeletionPlan createBatch({
    required RawChkDocument document,
    required Iterable<DoodadDeletionRequest> requests,
    Iterable<int> selectedSpriteRecordIndices = const [],
    Iterable<int> selectedUnitRecordIndices = const [],
    Iterable<int> confirmedUnitPeerRecordIndices = const [],
    Iterable<int> selectedLocationRecordIndices = const [],
    Iterable<int> confirmedLocationRecordIndices = const [],
    Map<int, DoodadPlacementRecipe> retainedNeighborRecipes = const {},
    Map<int, Iterable<DoodadPlacementRecipe>> retainedNeighborCandidates =
        const {},
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
    final locationIndices = selectedLocationRecordIndices
        .take(LocationDeletionPlan.maximumSelectedLocations + 1)
        .toList();
    final locationDeletion = locationIndices.isEmpty
        ? null
        : LocationDeletionPlan.create(
            document: document,
            recordIndices: locationIndices,
          );
    final confirmedLocations = confirmedLocationRecordIndices
        .take(LocationDeletionPlan.maximumSelectedLocations + 1)
        .toList();
    final expectedLocations = locationDeletion?.recordIndices ?? const <int>{};
    if (confirmedLocations.length != expectedLocations.length ||
        confirmedLocations.toSet().length != confirmedLocations.length ||
        !expectedLocations.containsAll(confirmedLocations)) {
      throw StateError(
        'LOCATION_DELETE: explicit slot clearing confirmation required',
      );
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
    final retained = _RetainedNeighborReview(
      retainedNeighborRecipes,
      retainedNeighborCandidates,
    );
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
        retainedNeighbors: retained,
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
      if (locationDeletion != null)
        locationDeletion.sectionIndex: locationDeletion.replacement,
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
      locationDeletion: locationDeletion,
      preservedNeighborRecordIndices: Set.unmodifiable(retained.verified.keys),
    );
  }

  static DoodadDeletionPlan _create({
    required RawChkDocument document,
    required DoodadPlacementRecipe recipe,
    required int recordIndex,
    required int? confirmedOverlayRecordIndex,
    required Map<int, DoodadPlacementRecipe> reviewedNeighbors,
    required _RetainedNeighborReview retainedNeighbors,
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
        terrain.tileCount != terrain.width! * terrain.height! ||
        terrain.rawSection.declaredLength != terrain.tileCount * 2 ||
        objects.doodadSections.length != 1) {
      reject('invalid tileset, dimensions or object sections');
    }
    final section = objects.doodadSections.single;
    if (document.sections[section.sectionIndex].declaredLength !=
        section.doodads.length * ChkDoodadPlacement.recordLength) {
      reject('requires one complete DD2 section');
    }
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
    // Check every catalog footprint, even if its terrain differs. A mismatch
    // cannot disprove that it represents a retained object with altered tiles.
    for (final other in section.doodads) {
      if (other.recordIndex == recordIndex) continue;
      final selectedRecipe = reviewedNeighbors[other.recordIndex];
      List<DoodadPlacementRecipe>? reviewed = selectedRecipe == null
          ? null
          : [selectedRecipe];
      if (reviewed == null) {
        if (!(other.x + _maximumHalfExtent > dx &&
            other.x - _maximumHalfExtent < dx + recipe.width * 32 &&
            other.y + _maximumHalfExtent > dy &&
            other.y - _maximumHalfExtent < dy + recipe.height * 32)) {
          continue;
        }
        reviewed = retainedNeighbors.verify(
          other,
          recipe.tileset.rawValue,
          terrain,
        );
      }
      if (reviewed != null) {
        for (final candidate in reviewed) {
          final left = other.x - candidate.centerOffsetX,
              top = other.y - candidate.centerOffsetY;
          if (left < dx + recipe.width * 32 &&
              left + candidate.width * 32 > dx &&
              top < dy + recipe.height * 32 &&
              top + candidate.height * 32 > dy) {
            reject('reviewed doodad footprints overlap');
          }
        }
        continue;
      }
      reject('nearby doodad ownership is ambiguous');
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
      preservedNeighborRecordIndices: Set.unmodifiable(
        retainedNeighbors.verified.keys,
      ),
    );
  }
}

/// Complete catalog candidates describe retained objects, not extra deletions.
/// A caller must not remove an unknown/broken variant to manufacture certainty.
final class _RetainedNeighborReview {
  _RetainedNeighborReview(
    Map<int, DoodadPlacementRecipe> recipes,
    Map<int, Iterable<DoodadPlacementRecipe>> candidates,
  ) {
    if (recipes.length + candidates.length >
            DoodadDeletionPlan.maximumRecipeTypes ||
        recipes.keys.any(candidates.containsKey)) {
      throw StateError('DOODAD_DELETE: invalid retained neighbor recipes');
    }
    final result = <int, List<DoodadPlacementRecipe>>{};
    var count = 0;
    void add(int type, Iterable<DoodadPlacementRecipe> values) {
      final list = values
          .take(DoodadDeletionPlan.maximumNeighborRecipeCandidates - count + 1)
          .toList();
      count += list.length;
      if (type < 0 ||
          type > 0xffff ||
          count > DoodadDeletionPlan.maximumNeighborRecipeCandidates ||
          list.any((r) => r.doodadType != type)) {
        throw StateError('DOODAD_DELETE: invalid retained neighbor candidates');
      }
      result[type] = List.unmodifiable(list);
    }

    for (final entry in recipes.entries) {
      add(entry.key, [entry.value]);
    }
    for (final entry in candidates.entries) {
      add(entry.key, entry.value);
    }
    this.candidates = Map.unmodifiable(result);
  }

  late final Map<int, List<DoodadPlacementRecipe>> candidates;
  final verified = <int, List<DoodadPlacementRecipe>>{};
  var _remainingCells = DoodadDeletionPlan.maximumNeighborCandidateCells;

  List<DoodadPlacementRecipe>? verify(
    ChkDoodadPlacement doodad,
    int tileset,
    ChkTerrainTileMapView terrain,
  ) {
    if (verified.containsKey(doodad.recordIndex)) {
      return verified[doodad.recordIndex];
    }
    final recipes = candidates[doodad.doodadType];
    if (recipes == null || recipes.isEmpty) return null;
    Never reject() =>
        throw StateError('DOODAD_DELETE: retained neighbor is not verified');
    if (verified.length >= DoodadDeletionPlan.maximumPreservedNeighbors ||
        (doodad.enabledValue != 0 && doodad.enabledValue != 1)) {
      reject();
    }
    var hasTerrainMatch = false;
    for (final recipe in recipes) {
      if (recipe.tileset.rawValue != tileset) reject();
      final dx = doodad.x - recipe.centerOffsetX,
          dy = doodad.y - recipe.centerOffsetY;
      if (dx < 0 || dy < 0 || dx % 32 != 0 || dy % 32 != 0) reject();
      final x = dx ~/ 32, y = dy ~/ 32;
      if (x + recipe.width > terrain.width! ||
          y + recipe.height > terrain.height!) {
        reject();
      }
      var matchesTerrain = true;
      for (final cell in recipe.footprint) {
        if (_remainingCells-- <= 0) {
          throw StateError('DOODAD_DELETE: neighbor candidate cell budget');
        }
        if (cell.writesTerrain &&
            terrain.rawTileValues[(y + cell.y) * terrain.width! + x + cell.x] !=
                cell.rawTileValue) {
          matchesTerrain = false;
          break;
        }
      }
      hasTerrainMatch = hasTerrainMatch || matchesTerrain;
    }
    if (!hasTerrainMatch) reject();
    verified[doodad.recordIndex] = recipes;
    return recipes;
  }
}
