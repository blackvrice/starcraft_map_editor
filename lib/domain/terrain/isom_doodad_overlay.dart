import 'dart:typed_data';
import '../chk/chk.dart';
import '../chk/typed/chk_editor_terrain.dart';
import '../placement/doodad_placement_recipe.dart';
import '../placement/object_placement_factory.dart';

/// Resolves existing footprints by exact local recipe and MTXM bytes.
/// Ambiguous ownership, disabled records and raw overrides are never repaired.
final class IsomDoodadOverlay {
  IsomDoodadOverlay._(this.source, this.base, this._cells, this._protected);
  final RawChkDocument source, base;
  final Map<int, (int, int)> _cells; // index -> (raw overlay, required group)
  final Map<int, int> _protected;

  static IsomDoodadOverlay read(
    RawChkDocument source,
    List<DoodadPlacementRecipe> recipes,
  ) {
    final report = const ChkEditorTerrainDecoder().decode(source);
    if (report.width == null ||
        report.height == null ||
        report.duplicateNames.isNotEmpty ||
        report.hasProtectionMarker ||
        report.sections.any((s) => !s.hasValidStructure)) {
      throw StateError('Invalid editor terrain.');
    }
    final terrain = const ChkTerrainViewDecoder()
        .decode(source)
        .tileMaps
        .single;
    final metadata = const ChkMetadataViewDecoder().decode(source);
    if (metadata.tilesets.length != 1 ||
        metadata.tilesets.single.knownTileset == null ||
        source.sections.where((s) => s.name == 'DD2 ').length > 1 ||
        source.sections
            .where((s) => s.name == 'DD2 ')
            .any((s) => s.payload.length % 8 != 0)) {
      throw StateError('Invalid tileset or doodad records.');
    }
    final underlying = source.sections.singleWhere((s) => s.name == 'TILE');
    if (underlying.payload.length != terrain.tileCount * 2) {
      throw StateError('Invalid TILE.');
    }
    final tile = ByteData.sublistView(underlying.payload);
    final objects = const ChkObjectViewDecoder().decode(source);
    final cells = <int, (int, int)>{};
    final protected = <int, int>{};
    for (final section in objects.doodadSections) {
      for (final d in section.doodads) {
        final candidates = <(Map<int, (int, int)>, Map<int, int>)>[];
        for (final r in recipes.where(
          (r) =>
              r.doodadType == d.doodadType &&
              r.tileset.rawValue == metadata.tilesets.single.rawValue &&
              r.enabledValue == d.enabledValue,
        )) {
          final dx = d.x - r.centerOffsetX, dy = d.y - r.centerOffsetY;
          if (dx < 0 || dy < 0 || dx % 32 != 0 || dy % 32 != 0) continue;
          final x = dx ~/ 32, y = dy ~/ 32;
          if (x + r.width > report.width! || y + r.height > report.height!) {
            continue;
          }
          final footprint = <int, (int, int)>{};
          final required = <int, int>{};
          var valid = true;
          for (final c in r.footprint) {
            final i = (y + c.y) * report.width! + x + c.x;
            final group = tile.getUint16(i * 2, Endian.little) >> 4;
            if ((c.writesTerrain &&
                    terrain.rawTileValues[i] != c.rawTileValue) ||
                (c.requiredTileGroup != 0 && group != c.requiredTileGroup)) {
              valid = false;
              break;
            }
            required[i] = tile.getUint16(i * 2, Endian.little);
            if (c.writesTerrain) {
              footprint[i] = (c.rawTileValue!, c.requiredTileGroup);
            }
          }
          if (valid) candidates.add((footprint, required));
        }
        if (candidates.length != 1) {
          throw StateError('Unknown or ambiguous doodad footprint.');
        }
        for (final e in candidates.single.$2.entries) {
          if (protected.containsKey(e.key)) {
            throw StateError('Overlapping doodad footprints.');
          }
          protected[e.key] = e.value;
        }
        for (final e in candidates.single.$1.entries) {
          cells[e.key] = e.value;
        }
      }
    }
    for (var i = 0; i < terrain.tileCount; i++) {
      if (!cells.containsKey(i) &&
          terrain.rawTileValues[i] != tile.getUint16(i * 2, Endian.little)) {
        throw StateError('Raw MTXM override outside verified doodads.');
      }
    }
    var base = source.replaceSection(
      terrain.sectionIndex,
      terrain.rawSection.withPayload(underlying.payload),
    );
    for (final section in objects.doodadSections) {
      base = base.replaceSection(
        section.sectionIndex,
        source.sections[section.sectionIndex].withPayload([]),
      );
    }
    return IsomDoodadOverlay._(source, base, cells, protected);
  }

  RawChkDocument restore(RawChkDocument converted) {
    final tile = converted.sections.singleWhere((s) => s.name == 'TILE');
    final data = ByteData.sublistView(Uint8List.fromList(tile.payload));
    for (final e in _protected.entries) {
      // Preserve the complete underlying footprint, including member choice.
      if (data.getUint16(e.key * 2, Endian.little) != e.value) {
        throw StateError(
          'Terrain brush intersects a doodad; move or delete it first.',
        );
      }
    }
    for (final e in _cells.entries) {
      data.setUint16(e.key * 2, e.value.$1, Endian.little);
    }
    var result = converted;
    for (var i = 0; i < source.sections.length; i++) {
      if (source.sections[i].name == 'DD2 ') {
        result = result.replaceSection(i, source.sections[i]);
      }
      if (source.sections[i].name == 'MTXM') {
        result = result.replaceSection(
          i,
          source.sections[i].withPayload(data.buffer.asUint8List()),
        );
      }
    }
    return result;
  }

  static RawChkDocument placeRamp(
    RawChkDocument source,
    DoodadPlacementRecipe recipe, {
    required int x,
    required int y,
    required List<DoodadPlacementRecipe> recipes,
  }) {
    if (!recipe.hasRamp) {
      throw StateError('A verified VF4 ramp is required.');
    }
    read(source, recipes);
    final report = const ChkEditorTerrainDecoder().decode(source);
    if (const ChkMetadataViewDecoder()
                .decode(source)
                .tilesets
                .single
                .rawValue !=
            recipe.tileset.rawValue ||
        x < 0 ||
        y < 0 ||
        x + recipe.width > report.width! ||
        y + recipe.height > report.height!) {
      throw StateError('Ramp outside map or wrong tileset.');
    }
    final plan = const DoodadPlacementFactory()
        .create(recipe: recipe, owner: 11, originTileX: x, originTileY: y)
        .plan;
    final view = const ChkTerrainViewDecoder().decode(source).tileMaps.single;
    final values = view.rawTileValues.toList();
    for (final c in recipe.footprint) {
      final i = (y + c.y) * report.width! + x + c.x;
      if (!c.isPlaceableAnywhere && values[i] >> 4 != c.requiredTileGroup) {
        throw StateError(
          'Ramp requires its matching cliff orientation and terrain.',
        );
      }
      if (c.writesTerrain) values[i] = c.rawTileValue!;
    }
    var result = source.replaceSection(
      view.sectionIndex,
      view.withRawTileValues(values),
    );
    void append(String name, Uint8List record, int recordLength) {
      final indices = [
        for (var i = 0; i < result.sections.length; i++)
          if (result.sections[i].name == name) i,
      ];
      if (indices.length > 1) throw StateError('Duplicate $name.');
      if (indices.isEmpty) {
        result = result.appendSection(
          RawChkSection(
            nameBytes: name.codeUnits,
            declaredLength: record.length,
            payload: record,
            sourceOffset: source.sourceLength,
            isDirty: true,
          ),
        );
      } else {
        final at = indices.single, old = result.sections[at];
        if (old.payload.length % recordLength != 0) {
          throw StateError('Invalid $name.');
        }
        result = result.replaceSection(
          at,
          old.withPayload([...old.payload, ...record]),
        );
      }
    }

    append('DD2 ', plan.doodadRecord, 8);
    if (plan.overlayRecord case final Uint8List bytes) {
      append('THG2', bytes, 10);
    }
    // Detect overlaps and ensure the resulting recipe can be resolved exactly.
    read(result, recipes);
    return result;
  }
}
