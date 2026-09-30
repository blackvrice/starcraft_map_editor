#pragma once

#include "tileset_asset_reader.h"

namespace starcraft_map_editor::starcraft_data {

// Read-only CV5 projection. These are NOT resolved ISOM shapes or tile pairs.
struct TerrainGroupConnection {
  std::uint16_t group = 0;
  std::uint16_t terrain_type = 0;
  std::uint16_t flags = 0;
  std::array<std::uint16_t, 4> links{};
  std::array<std::uint16_t, 4> stack_connections{};
  std::vector<std::uint16_t> renderable_members;
};

struct TerrainConnectionSnapshot {
  bool success = false;
  std::array<std::string, kRenderAssetCount> asset_sha256;
  std::vector<TerrainGroupConnection> groups;
  std::string error_code;
};

std::string TerrainAssetSha256(const std::vector<std::byte>& bytes);

TerrainConnectionSnapshot ReadTerrainConnections(
    const std::array<std::vector<std::byte>, kRenderAssetCount>& assets);

}  // namespace starcraft_map_editor::starcraft_data
