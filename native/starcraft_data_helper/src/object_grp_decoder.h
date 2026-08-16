#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace starcraft_map_editor::starcraft_data {

inline constexpr std::size_t kMaximumObjectGrpBytes = 64ULL * 1024ULL * 1024ULL;
inline constexpr std::uint16_t kMaximumObjectGrpDimension = 1024;
inline constexpr std::size_t kMaximumObjectFrameBytes =
    4ULL * 1024ULL * 1024ULL;

struct ObjectRgbColor {
  std::uint8_t red = 0;
  std::uint8_t green = 0;
  std::uint8_t blue = 0;
};

using ObjectRgbPalette = std::array<ObjectRgbColor, 256>;
using ObjectPlayerRgbPalette = std::array<ObjectRgbColor, 8>;

struct ObjectGrpDecodeResult {
  bool success = false;
  std::uint16_t width = 0;
  std::uint16_t height = 0;
  std::int16_t anchor_x = 0;
  std::int16_t anchor_y = 0;
  std::uint16_t frame_index = 0;
  std::vector<std::byte> rgba_bytes;
  std::string error_code;
  std::string message;
  std::string stage;
};

ObjectGrpDecodeResult DecodeObjectGrpFirstFrame(
    const std::vector<std::byte> &grp_bytes,
    const ObjectRgbPalette &base_palette,
    const ObjectPlayerRgbPalette *player_palette = nullptr);

} // namespace starcraft_map_editor::starcraft_data
