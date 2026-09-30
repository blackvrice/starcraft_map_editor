import '../../domain/terrain/isom_terrain_conversion.dart';

/// Provider must bind shape/edge and tile-pair projections to one local asset
/// snapshot and converter version. No provider is bundled until validated.
abstract interface class IsomTerrainCatalogGateway {
  Future<IsomTerrainCatalog> load({required int tileset});
}
