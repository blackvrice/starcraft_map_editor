#pragma once

#include <cstdint>
#include <filesystem>
#include <string>
#include <string_view>
#include <vector>

namespace starcraft_map_editor::starcraft_data {

inline constexpr std::size_t kMaximumRawValues = 4096;
inline constexpr std::uint16_t kTileAtlasFormatVersion = 1;
inline constexpr std::uint16_t kTileSize = 32;
inline constexpr std::uint64_t kMaximumAtlasFileBytes =
    17ULL * 1024ULL * 1024ULL;
inline constexpr std::string_view kTileAtlasFileName = "tile-atlas.rgba";

struct AtlasWriteResult {
  bool success = false;
  std::uint64_t file_bytes = 0;
  std::string error_code;
  std::string message;
  std::string stage;
  std::uint32_t native_error = 0;
};

bool ValidateRawValues(const std::vector<std::uint32_t>& raw_values);

AtlasWriteResult WriteEmptyTileAtlas(
    const std::filesystem::path& working_directory);

}  // namespace starcraft_map_editor::starcraft_data
