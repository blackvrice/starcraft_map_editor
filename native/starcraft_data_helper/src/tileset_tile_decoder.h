#pragma once

#include "tileset_asset_reader.h"

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace starcraft_map_editor::starcraft_data {

inline constexpr std::size_t kRgbaBytesPerTile = 32 * 32 * 4;
inline constexpr std::size_t kCv5GroupBytes = 52;
inline constexpr std::size_t kMaximumCv5Groups = 4096;
inline constexpr std::size_t kMaximumCatalogPageSize = 256;

struct TilesetTileDecodeResult {
  bool success = false;
  std::vector<std::uint16_t> rendered_raw_values;
  std::vector<std::uint32_t> unsupported_raw_values;
  std::vector<std::byte> rgba_bytes;
  std::string error_code;
  std::string message;
  std::string stage;
  std::uint32_t native_error = 0;
};

TilesetTileDecodeResult DecodeTilesetTiles(
    const std::array<std::vector<std::byte>, kRenderAssetCount>& assets,
    const std::vector<std::uint32_t>& raw_values);

struct TilesetTileCatalogResult {
  bool success = false;
  std::size_t total_entries = 0;
  std::vector<std::uint16_t> raw_values;
  std::string error_code;
  std::string message;
  std::string stage;
  std::uint32_t native_error = 0;
};

TilesetTileCatalogResult ListTilesetTiles(
    const std::array<std::vector<std::byte>, kRenderAssetCount>& assets,
    std::uint32_t offset,
    std::uint32_t limit);

}  // namespace starcraft_map_editor::starcraft_data
