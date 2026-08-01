import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_tile_atlas_gateway.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';

void main() {
  test('request requires a sorted unique bounded raw-value batch', () {
    expect(
      () => StarCraftTileAtlasRequest(
        installationPath: r'C:\Games\StarCraft',
        tileset: StarCraftTilesetAssetSet.badlands,
        rawValues: const [],
      ),
      throwsRangeError,
    );
    expect(
      () => StarCraftTileAtlasRequest(
        installationPath: r'C:\Games\StarCraft',
        tileset: StarCraftTilesetAssetSet.badlands,
        rawValues: const [1, 1],
      ),
      throwsArgumentError,
    );
    expect(
      () => StarCraftTileAtlasRequest(
        installationPath: r'C:\Games\StarCraft',
        tileset: StarCraftTilesetAssetSet.badlands,
        rawValues: const [2, 1],
      ),
      throwsArgumentError,
    );
    expect(
      () => StarCraftTileAtlasRequest(
        installationPath: r'C:\Games\StarCraft',
        tileset: StarCraftTilesetAssetSet.badlands,
        rawValues: const [0x10000],
      ),
      throwsRangeError,
    );
  });

  test('request and result copy mutable binary inputs', () {
    final sourceRawValues = [0, 0x4000];
    final request = StarCraftTileAtlasRequest(
      installationPath: r'C:\Games\StarCraft',
      tileset: StarCraftTilesetAssetSet.jungle,
      rawValues: sourceRawValues,
    );
    sourceRawValues[0] = 7;

    final sourcePixels = Uint8List(2 * 32 * 32 * 4);
    final result = StarCraftTileAtlasResult(
      request: request,
      tileSize: 32,
      columns: 2,
      rows: 1,
      rawValues: const [0, 0x4000],
      rgbaBytes: sourcePixels,
      unsupportedRawValues: const [],
    );
    sourcePixels[0] = 255;

    expect(request.rawValues, [0, 0x4000]);
    expect(result.rgbaBytes[0], 0);
    expect(result.rawValues, [0, 0x4000]);
    expect(() => result.rgbaBytes[0] = 1, throwsUnsupportedError);
    expect(result.isSuccess, isTrue);
  });

  test('result requires exact rendered and unsupported coverage', () {
    final request = StarCraftTileAtlasRequest(
      installationPath: r'C:\Games\StarCraft',
      tileset: StarCraftTilesetAssetSet.ice,
      rawValues: const [1, 2],
    );

    expect(
      () => StarCraftTileAtlasResult(
        request: request,
        tileSize: 32,
        columns: 1,
        rows: 1,
        rawValues: const [1],
        rgbaBytes: Uint8List(32 * 32 * 4),
        unsupportedRawValues: const [],
      ),
      throwsArgumentError,
    );
    final extendedRequest = StarCraftTileAtlasRequest(
      installationPath: r'C:\Games\StarCraft',
      tileset: StarCraftTilesetAssetSet.ice,
      rawValues: const [1, 0x4000],
    );
    final extended = StarCraftTileAtlasResult(
      request: extendedRequest,
      tileSize: 32,
      columns: 2,
      rows: 1,
      rawValues: const [1, 0x4000],
      rgbaBytes: Uint8List(2 * 32 * 32 * 4),
      unsupportedRawValues: const [],
    );
    expect(extended.rawValues, [1, 0x4000]);
  });
}
