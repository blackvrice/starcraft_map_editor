#pragma once

#include "object_grp_decoder.h"

#include <array>
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace starcraft_map_editor::starcraft_data {

inline constexpr std::size_t kObjectPlayerColorCount = 8;

struct ObjectPaletteDecodeResult {
  bool success = false;
  ObjectRgbPalette base_palette{};
  std::array<ObjectPlayerRgbPalette, kObjectPlayerColorCount>
      player_palettes{};
  std::string error_code;
  std::string message;
  std::string stage;
  std::uint32_t native_error = 0;
};

ObjectPaletteDecodeResult DecodeObjectPalettes(
    const std::vector<std::byte>& wpe_bytes,
    const std::vector<std::byte>& tunit_pcx_bytes);

}  // namespace starcraft_map_editor::starcraft_data
