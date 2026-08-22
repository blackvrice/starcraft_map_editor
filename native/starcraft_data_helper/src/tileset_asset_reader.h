#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <string>
#include <string_view>
#include <vector>

namespace starcraft_map_editor::starcraft_data {

inline constexpr std::size_t kTilesetCount = 8;
inline constexpr std::size_t kRenderAssetCount = 4;
inline constexpr std::size_t kDoodadAssetCount = 5;

struct TilesetAssetReadResult {
  bool success = false;
  std::string installation_path;
  std::string storage_product;
  std::uint32_t storage_build_number = 0;
  std::uint64_t total_asset_bytes = 0;
  std::array<std::vector<std::byte>, kRenderAssetCount> assets;
  std::string error_code;
  std::string message;
  std::string stage;
  std::uint32_t native_error = 0;
};

struct DoodadAssetReadResult {
  bool success = false;
  std::string installation_path;
  std::string storage_product;
  std::uint32_t storage_build_number = 0;
  std::uint64_t total_asset_bytes = 0;
  std::array<std::vector<std::byte>, kDoodadAssetCount> assets;
  std::string error_code;
  std::string message;
  std::string stage;
  std::uint32_t native_error = 0;
};

const std::array<
    std::array<std::string_view, kRenderAssetCount>,
    kTilesetCount>&
RenderTilesetAssetPaths();

const std::array<
    std::array<std::string_view, kDoodadAssetCount>,
    kTilesetCount>&
DoodadTilesetAssetPaths();

TilesetAssetReadResult ReadTilesetAssets(
    const std::filesystem::path& installation_path,
    std::uint32_t tileset);

DoodadAssetReadResult ReadDoodadAssets(
    const std::filesystem::path& installation_path,
    std::uint32_t tileset);

}  // namespace starcraft_map_editor::starcraft_data
