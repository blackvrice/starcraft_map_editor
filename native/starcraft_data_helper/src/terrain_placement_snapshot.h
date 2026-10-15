#pragma once

#include "tileset_asset_reader.h"

namespace starcraft_map_editor::starcraft_data {

// Derived construction/walkability and static CV5 bits, never observed creep.
struct TerrainPlacementSnapshot {
  bool success = false;
  std::array<std::string, 2> asset_sha256;
  std::vector<bool> group_buildable;
  std::vector<std::array<std::uint16_t, 16>> mega_tile_references;
  std::vector<std::uint16_t> walkable_masks;
  std::vector<std::uint16_t> creep_candidate_flags;
  std::string error_code;
};

TerrainPlacementSnapshot ReadTerrainPlacement(
    const std::array<std::vector<std::byte>, 2>& assets);

}  // namespace starcraft_map_editor::starcraft_data
