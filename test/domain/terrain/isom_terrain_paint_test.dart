import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/terrain/transition_isom_catalog_builder.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_doodad_overlay.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_fill.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_paint.dart';
import '../../fixtures/solid_isom_fixture.dart';

void main() {
  test('tile centers snap to their diamond quadrants', () {
    expect(IsomTerrainPaint.diamondAtTile(0, 0), (0, 0));
    expect(IsomTerrainPaint.diamondAtTile(1, 0), (1, 1));
    expect(IsomTerrainPaint.diamondAtTile(0, 1), (0, 2));
    expect(IsomTerrainPaint.diamondAtTile(1, 1), (1, 1));
    expect(IsomTerrainPaint.diamondAtTile(31, 31), (16, 32));
  });
  final c = const TransitionIsomCatalogBuilder().build(solidSnapshot());
  RawChkDocument base() => const IsomTerrainFill()
      .preview(
        const NewMapFactory().create(
          NewMapOptions(width: 32, height: 32, rawTileValue: 0),
        ),
        c.catalog,
        solidValue: 16,
        seed: 0,
      )
      .result;
  DoodadPlacementRecipe ramp({int group = 2, bool verified = true}) =>
      DoodadPlacementRecipe(
        tileset: StarCraftTilesetAssetSet.badlands,
        startTileGroup: 100,
        doodadType: 3,
        width: 2,
        height: 1,
        centerOffsetX: 32,
        centerOffsetY: 16,
        hasRamp: verified,
        footprint: [
          for (var x = 0; x < 2; x++)
            DoodadFootprintCell(
              x: x,
              y: 0,
              rawTileValue: 1600 + x,
              requiredTileGroup: group + x,
            ),
        ],
        overlay: DoodadOverlayRecipe(
          semantic: DoodadOverlaySemantic.pureSprite,
          id: 130,
        ),
      );

  test(
    'same terrain is byte exact; unavailable boundary cannot partially apply',
    () {
      final source = base(), bytes = const RawChkEncoder().encode(base());
      final p = const IsomTerrainPaint().preview(
        source,
        c.catalog,
        c.brush!,
        solidShape: 1,
        diamonds: {(8, 16)},
      );
      expect(p.hasChanges, isFalse);
      expect(const RawChkEncoder().encode(p.result), bytes);
      expect(
        () => const IsomTerrainPaint().preview(
          source,
          c.catalog,
          c.brush!,
          solidShape: 2,
          diamonds: {(8, 16)},
        ),
        throwsStateError,
      );
      expect(const RawChkEncoder().encode(source), bytes);
      expect(
        () => const IsomTerrainPaint().preview(
          source,
          c.catalog,
          c.brush!,
          solidShape: 1,
          diamonds: {(7, 16)},
        ),
        throwsRangeError,
      );
    },
  );
  test('inconsistent projected diamond is refused before painting', () {
    final source = base(),
        at = base().sections.indexWhere((s) => s.name == 'ISOM');
    final bytes = Uint8List.fromList(source.sections[at].payload);
    ByteData.sublistView(bytes).setUint16((16 * 17 + 8) * 8, 32, Endian.little);
    final invalid = source.replaceSection(
      at,
      source.sections[at].withPayload(bytes),
    );
    expect(
      () => const IsomTerrainPaint().preview(
        invalid,
        c.catalog,
        c.brush!,
        solidShape: 1,
        diamonds: {(8, 16)},
      ),
      throwsStateError,
    );
  });
  test('ramp preview preserves ISOM/TILE and exact unknown bytes', () {
    final source = base().appendSection(
      RawChkSection(
        nameBytes: 'XTRA'.codeUnits,
        declaredLength: 3,
        payload: [255, 0, 128],
        sourceOffset: 0,
      ),
    );
    final r = ramp();
    final result = IsomDoodadOverlay.placeRamp(
      source,
      r,
      x: 4,
      y: 8,
      recipes: [r],
    );
    for (final name in ['ISOM', 'TILE', 'XTRA']) {
      expect(
        result.sections.singleWhere((s) => s.name == name),
        same(source.sections.singleWhere((s) => s.name == name)),
      );
    }
    final objects = const ChkObjectViewDecoder().decode(result);
    expect(objects.doodadSections.single.doodads.single.doodadType, 3);
    expect(objects.spriteSections.single.sprites.single.spriteType, 130);
    final overlay = IsomDoodadOverlay.read(result, [r]);
    expect(
      overlay.base.sections.singleWhere((s) => s.name == 'MTXM').payload,
      source.sections.singleWhere((s) => s.name == 'TILE').payload,
    );
    expect(
      const RawChkEncoder().encode(overlay.restore(overlay.base)),
      const RawChkEncoder().encode(result),
    );
    expect(() => IsomDoodadOverlay.read(result, []), throwsStateError);
    expect(() => IsomDoodadOverlay.read(result, [r, r]), throwsStateError);
    expect(
      () => IsomDoodadOverlay.placeRamp(result, r, x: 4, y: 8, recipes: [r]),
      throwsStateError,
    );
  });
  test('wrong terrain, unknown ramp and outside map preserve the document', () {
    final source = base();
    final before = const RawChkEncoder().encode(source);
    for (final r in [ramp(group: 4), ramp(verified: false)]) {
      expect(
        () => IsomDoodadOverlay.placeRamp(source, r, x: 4, y: 8, recipes: [r]),
        throwsStateError,
      );
    }
    final r = ramp();
    expect(
      () => IsomDoodadOverlay.placeRamp(source, r, x: 31, y: 8, recipes: [r]),
      throwsStateError,
    );
    expect(const RawChkEncoder().encode(source), before);
    final placed = IsomDoodadOverlay.placeRamp(
      source,
      r,
      x: 4,
      y: 8,
      recipes: [r],
    );
    final overlay = IsomDoodadOverlay.read(placed, [r]);
    final at = overlay.base.sections.indexWhere((s) => s.name == 'TILE');
    final bytes = Uint8List.fromList(overlay.base.sections[at].payload);
    bytes[(8 * 32 + 4) * 2] ^= 1;
    expect(
      () => overlay.restore(
        overlay.base.replaceSection(
          at,
          overlay.base.sections[at].withPayload(bytes),
        ),
      ),
      throwsStateError,
    );
  });
}
