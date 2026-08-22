#pragma once

#include "tileset_asset_reader.h"

#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace starcraft_map_editor::starcraft_data {

enum class DoodadOverlayKind { kSprite, kUnit };

struct DoodadFootprintCell {
  std::uint16_t x = 0;
  std::uint16_t y = 0;
  std::optional<std::uint16_t> raw_tile_value;
  std::uint16_t required_tile_group = 0;
};

struct DoodadOverlayRecipe {
  DoodadOverlayKind kind = DoodadOverlayKind::kSprite;
  std::uint16_t id = 0;
};

struct DoodadPlacementRecipe {
  std::uint16_t start_tile_group = 0;
  std::uint16_t doodad_id = 0;
  std::uint16_t width = 0;
  std::uint16_t height = 0;
  std::uint16_t center_offset_x = 0;
  std::uint16_t center_offset_y = 0;
  std::uint8_t enabled_value = 1;
  std::vector<DoodadFootprintCell> footprint;
  std::optional<DoodadOverlayRecipe> overlay;
  std::string issue_code;
};

struct DoodadCatalogResult {
  bool success = false;
  std::size_t total_entries = 0;
  std::vector<DoodadPlacementRecipe> entries;
  std::string error_code;
  std::string message;
  std::string stage;
  std::uint32_t native_error = 0;
};

DoodadCatalogResult ListDoodadRecipes(
    const std::array<std::vector<std::byte>, kDoodadAssetCount>& assets,
    std::uint32_t offset,
    std::uint32_t limit);

}  // namespace starcraft_map_editor::starcraft_data
