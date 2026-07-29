import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';

void main() {
  test('declares every required loose file for all eight tilesets', () {
    final requirements = StarCraftDataAssetManifest.requiredTilesetAssets;

    expect(StarCraftTilesetAssetSet.values, hasLength(8));
    expect(StarCraftTilesetAssetKind.values, hasLength(5));
    expect(requirements, hasLength(40));
    expect(
      requirements.map((requirement) => requirement.relativePath).toSet(),
      hasLength(40),
    );
    expect(
      requirements.map((requirement) => requirement.relativePath),
      containsAll([
        r'tileset\badlands.cv5',
        r'tileset\platform.vf4',
        r'tileset\install.vx4',
        r'tileset\ashworld.vr4',
        r'tileset\jungle.wpe',
        r'tileset\desert.cv5',
        r'tileset\ice.vf4',
        r'tileset\twilight.wpe',
      ]),
    );
  });

  test('keeps tileset raw values aligned with ERA values', () {
    expect(
      StarCraftTilesetAssetSet.values.map((tileset) => tileset.rawValue),
      orderedEquals([0, 1, 2, 3, 4, 5, 6, 7]),
    );
    expect(StarCraftTilesetAssetSet.spacePlatform.fileStem, 'platform');
    expect(StarCraftTilesetAssetSet.installation.fileStem, 'install');
  });
}
