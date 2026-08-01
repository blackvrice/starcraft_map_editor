#include "tileset_tile_decoder.h"

#include <Windows.h>

#include <array>
#include <stdexcept>
#include <utility>

namespace starcraft_map_editor::starcraft_data {
namespace {

constexpr std::size_t kCv5GroupBytes = 52;
constexpr std::size_t kCv5MegaTileReferencesOffset = 20;
constexpr std::size_t kMaximumCv5Groups = 4096;
constexpr std::size_t kVx4ExMegaTileBytes = 64;
constexpr std::size_t kVr4MiniTileBytes = 64;
constexpr std::size_t kWpeColorBytes = 4;
constexpr std::size_t kWpeColorCount = 256;
constexpr std::size_t kWpeBytes = kWpeColorBytes * kWpeColorCount;
constexpr std::size_t kMiniTilesPerAxis = 4;
constexpr std::size_t kMiniTilePixelsPerAxis = 8;

TilesetTileDecodeResult Failure(std::string message) {
  TilesetTileDecodeResult result;
  result.error_code = "SC_CASC_TILE_ASSET_INVALID";
  result.message = std::move(message);
  result.stage = "decode-assets";
  result.native_error = ERROR_INVALID_DATA;
  return result;
}

std::uint8_t ReadUint8(
    const std::vector<std::byte>& bytes,
    const std::size_t offset) {
  return std::to_integer<std::uint8_t>(bytes[offset]);
}

std::uint16_t ReadUint16(
    const std::vector<std::byte>& bytes,
    const std::size_t offset) {
  return static_cast<std::uint16_t>(
      ReadUint8(bytes, offset) |
      (static_cast<std::uint16_t>(ReadUint8(bytes, offset + 1)) << 8U));
}

std::uint32_t ReadUint32(
    const std::vector<std::byte>& bytes,
    const std::size_t offset) {
  std::uint32_t value = 0;
  for (std::size_t index = 0; index < 4; ++index) {
    value |= static_cast<std::uint32_t>(ReadUint8(bytes, offset + index))
             << (index * 8U);
  }
  return value;
}

bool AppendTile(
    const std::array<std::vector<std::byte>, kRenderAssetCount>& assets,
    const std::uint32_t raw_value,
    std::vector<std::byte>* const rgba_bytes) {
  const auto& cv5 = assets[0];
  const auto& vx4ex = assets[1];
  const auto& vr4 = assets[2];
  const auto& wpe = assets[3];
  const auto group = static_cast<std::size_t>(raw_value / 16U);
  const auto member = static_cast<std::size_t>(raw_value % 16U);
  const auto group_count = cv5.size() / kCv5GroupBytes;
  if (group >= group_count) {
    return false;
  }

  const auto cv5_offset = group * kCv5GroupBytes +
                          kCv5MegaTileReferencesOffset + member * 2;
  const auto mega_tile_index =
      static_cast<std::size_t>(ReadUint16(cv5, cv5_offset));
  const auto mega_tile_count = vx4ex.size() / kVx4ExMegaTileBytes;
  if (mega_tile_index >= mega_tile_count) {
    throw std::out_of_range("CV5 references a missing VX4EX mega-tile.");
  }

  const auto tile_start = rgba_bytes->size();
  rgba_bytes->resize(tile_start + kRgbaBytesPerTile);
  const auto mini_tile_count = vr4.size() / kVr4MiniTileBytes;
  for (std::size_t mini_y = 0; mini_y < kMiniTilesPerAxis; ++mini_y) {
    for (std::size_t mini_x = 0; mini_x < kMiniTilesPerAxis; ++mini_x) {
      const auto mini_index = mini_y * kMiniTilesPerAxis + mini_x;
      const auto graphics = ReadUint32(
          vx4ex,
          mega_tile_index * kVx4ExMegaTileBytes + mini_index * 4);
      const auto flipped = (graphics & 1U) != 0;
      const auto vr4_index = static_cast<std::size_t>(graphics >> 1U);
      if (vr4_index >= mini_tile_count) {
        throw std::out_of_range("VX4EX references a missing VR4 mini-tile.");
      }

      for (std::size_t pixel_y = 0;
           pixel_y < kMiniTilePixelsPerAxis;
           ++pixel_y) {
        for (std::size_t pixel_x = 0;
             pixel_x < kMiniTilePixelsPerAxis;
             ++pixel_x) {
          const auto source_x =
              flipped ? kMiniTilePixelsPerAxis - 1 - pixel_x : pixel_x;
          const auto palette_index = ReadUint8(
              vr4,
              vr4_index * kVr4MiniTileBytes +
                  pixel_y * kMiniTilePixelsPerAxis + source_x);
          const auto palette_offset =
              static_cast<std::size_t>(palette_index) * kWpeColorBytes;
          const auto output_x = mini_x * kMiniTilePixelsPerAxis + pixel_x;
          const auto output_y = mini_y * kMiniTilePixelsPerAxis + pixel_y;
          const auto output_offset =
              tile_start + (output_y * 32 + output_x) * 4;
          (*rgba_bytes)[output_offset] =
              static_cast<std::byte>(ReadUint8(wpe, palette_offset));
          (*rgba_bytes)[output_offset + 1] =
              static_cast<std::byte>(ReadUint8(wpe, palette_offset + 1));
          (*rgba_bytes)[output_offset + 2] =
              static_cast<std::byte>(ReadUint8(wpe, palette_offset + 2));
          (*rgba_bytes)[output_offset + 3] = static_cast<std::byte>(0xFF);
        }
      }
    }
  }
  return true;
}

}  // namespace

TilesetTileDecodeResult DecodeTilesetTiles(
    const std::array<std::vector<std::byte>, kRenderAssetCount>& assets,
    const std::vector<std::uint32_t>& raw_values) {
  const auto& cv5 = assets[0];
  const auto& vx4ex = assets[1];
  const auto& vr4 = assets[2];
  const auto& wpe = assets[3];
  if (cv5.empty() || cv5.size() % kCv5GroupBytes != 0 ||
      cv5.size() / kCv5GroupBytes > kMaximumCv5Groups) {
    return Failure(
        "The StarCraft CV5 asset has an invalid byte length (" +
        std::to_string(cv5.size()) + " bytes).");
  }
  if (vx4ex.empty() || vx4ex.size() % kVx4ExMegaTileBytes != 0) {
    return Failure(
        "The StarCraft VX4EX asset has an invalid byte length (" +
        std::to_string(vx4ex.size()) + " bytes).");
  }
  if (vr4.empty() || vr4.size() % kVr4MiniTileBytes != 0) {
    return Failure(
        "The StarCraft VR4 asset has an invalid byte length (" +
        std::to_string(vr4.size()) + " bytes).");
  }
  if (wpe.size() != kWpeBytes) {
    return Failure(
        "The StarCraft WPE asset has an invalid byte length (" +
        std::to_string(wpe.size()) + " bytes).");
  }

  TilesetTileDecodeResult result;
  result.rgba_bytes.reserve(raw_values.size() * kRgbaBytesPerTile);
  try {
    for (const auto raw_value : raw_values) {
      if (AppendTile(assets, raw_value, &result.rgba_bytes)) {
        result.rendered_raw_values.push_back(
            static_cast<std::uint16_t>(raw_value));
      } else {
        result.unsupported_raw_values.push_back(raw_value);
      }
    }
  } catch (const std::out_of_range&) {
    return Failure(
        "A StarCraft tile rendering asset contains an invalid reference.");
  }

  result.success = true;
  return result;
}

}  // namespace starcraft_map_editor::starcraft_data
