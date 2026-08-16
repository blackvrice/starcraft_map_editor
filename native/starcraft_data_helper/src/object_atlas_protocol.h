#pragma once

#include "object_sprite_reference.h"

#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <string>
#include <string_view>
#include <vector>

namespace starcraft_map_editor::starcraft_data {

inline constexpr std::uint16_t kObjectAtlasFormatVersion = 1;
inline constexpr std::uint16_t kObjectAtlasEntryBytes = 32;
inline constexpr std::size_t kMaximumObjectAtlasEntries = 256;
inline constexpr std::uint64_t kMaximumObjectAtlasFileBytes =
    32ULL * 1024ULL * 1024ULL;
inline constexpr std::string_view kObjectAtlasFileName = "object-atlas.rgba";
inline constexpr std::uint8_t kNeutralObjectPlayerColor = 255;

struct ObjectAtlasEntry {
  ObjectGraphicKind kind = ObjectGraphicKind::kUnit;
  std::uint8_t player_color = kNeutralObjectPlayerColor;
  std::uint8_t direction = 0;
  std::uint16_t object_id = 0;
  std::uint16_t sprite_id = 0;
  std::uint16_t image_id = 0;
  std::uint16_t width = 0;
  std::uint16_t height = 0;
  std::int16_t anchor_x = 0;
  std::int16_t anchor_y = 0;
  std::uint16_t frame_index = 0;
  std::vector<std::byte> rgba_bytes;
};

struct ObjectAtlasWriteResult {
  bool success = false;
  std::uint64_t file_bytes = 0;
  std::uint32_t entry_count = 0;
  std::uint32_t pixel_bytes = 0;
  std::string error_code;
  std::string message;
  std::string stage;
  std::uint32_t native_error = 0;
};

bool ValidateObjectAtlasEntries(const std::vector<ObjectAtlasEntry> &entries);

ObjectAtlasWriteResult
WriteObjectAtlas(const std::filesystem::path &working_directory,
                 const std::vector<ObjectAtlasEntry> &entries);

} // namespace starcraft_map_editor::starcraft_data
