import 'package:starcraft_map_editor/application/ports/starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';

class IsomRampGateway implements StarCraftPlacementCatalogGateway {
  Future<void> Function()? beforeReturn;
  final cancelled = <String>[];
  final recipe = DoodadPlacementRecipe(
    tileset: StarCraftTilesetAssetSet.badlands,
    startTileGroup: 100,
    doodadType: 3,
    width: 2,
    height: 1,
    centerOffsetX: 32,
    centerOffsetY: 16,
    hasRamp: true,
    footprint: [
      for (var x = 0; x < 2; x++)
        DoodadFootprintCell(
          x: x,
          y: 0,
          rawTileValue: 1600 + x,
          requiredTileGroup: 0,
        ),
    ],
  );
  @override
  Future<void> cancel(String operationId) async {
    cancelled.add(operationId);
  }

  @override
  Future<StarCraftPlacementCatalogPage> list(
    StarCraftPlacementCatalogRequest request,
  ) async {
    await beforeReturn?.call();
    return StarCraftPlacementCatalogPage(
      request: request,
      totalEntries: 1,
      entries: [
        StarCraftPlacementCatalogEntry(
          key: StarCraftPlacementCatalogKey.doodad(
            tileset: recipe.tileset,
            doodadId: recipe.doodadType,
            startTileGroup: recipe.startTileGroup,
          ),
          source: StarCraftPlacementCatalogSource.localData,
          availability: StarCraftPlacementAvailability.placeable,
          doodadRecipe: recipe,
        ),
      ],
    );
  }
}
