import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';

void main() {
  test('models row-major MTXM, placibility, center and Sprite overlay', () {
    final recipe = DoodadPlacementRecipe(
      tileset: StarCraftTilesetAssetSet.jungle,
      startTileGroup: 200,
      doodadType: 7,
      width: 2,
      height: 2,
      centerOffsetX: 32,
      centerOffsetY: 32,
      footprint: [
        DoodadFootprintCell(
          x: 0,
          y: 0,
          rawTileValue: 3200,
          requiredTileGroup: 4,
        ),
        DoodadFootprintCell(
          x: 1,
          y: 0,
          rawTileValue: 3201,
          requiredTileGroup: 0,
        ),
        DoodadFootprintCell(
          x: 0,
          y: 1,
          rawTileValue: 3216,
          requiredTileGroup: 5,
        ),
        DoodadFootprintCell(
          x: 1,
          y: 1,
          rawTileValue: null,
          requiredTileGroup: 6,
        ),
      ],
      overlay: DoodadOverlayRecipe(
        semantic: DoodadOverlaySemantic.pureSprite,
        id: 130,
      ),
    );

    expect(recipe.enabledValue, DoodadPlacementRecipe.enabled);
    expect(recipe.footprint.where((cell) => cell.writesTerrain), hasLength(3));
    expect(recipe.footprint[1].isPlaceableAnywhere, isTrue);
    expect(recipe.overlay!.thg2Flags, 0x1000);
  });

  test('maps a unit overlay to a THG2 sprite-unit record', () {
    final overlay = DoodadOverlayRecipe(
      semantic: DoodadOverlaySemantic.spriteUnit,
      id: 100,
    );

    expect(overlay.thg2Flags, 0);
  });

  test('rejects mismatched center, raw values and empty terrain', () {
    expect(() => _recipe(centerOffsetX: 16), throwsA(isA<ArgumentError>()));
    expect(() => _recipe(firstRawValue: 3201), throwsA(isA<ArgumentError>()));
    expect(() => _recipe(firstRawValue: null), throwsA(isA<ArgumentError>()));
  });
}

DoodadPlacementRecipe _recipe({
  int centerOffsetX = 32,
  int? firstRawValue = 3200,
}) => DoodadPlacementRecipe(
  tileset: StarCraftTilesetAssetSet.jungle,
  startTileGroup: 200,
  doodadType: 7,
  width: 2,
  height: 1,
  centerOffsetX: centerOffsetX,
  centerOffsetY: 16,
  footprint: [
    DoodadFootprintCell(
      x: 0,
      y: 0,
      rawTileValue: firstRawValue,
      requiredTileGroup: 0,
    ),
    DoodadFootprintCell(x: 1, y: 0, rawTileValue: null, requiredTileGroup: 0),
  ],
);
