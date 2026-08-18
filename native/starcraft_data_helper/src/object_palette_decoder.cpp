#include "object_palette_decoder.h"

#include <Windows.h>

#include <cstddef>
#include <utility>
#include <vector>

namespace starcraft_map_editor::starcraft_data {
namespace {

constexpr std::size_t kWpeBytes = 256 * 4;
constexpr std::size_t kPcxHeaderBytes = 128;
constexpr std::size_t kPcxPaletteBytes = 256 * 3;
constexpr std::size_t kPcxPaletteMarkerBytes = 1;
constexpr std::uint8_t kPcxPaletteMarker = 0x0c;
constexpr std::size_t kGradientWidth = 8;
constexpr std::size_t kColorTableWidth = 128;

ObjectPaletteDecodeResult Failure(std::string message) {
  ObjectPaletteDecodeResult result;
  result.error_code = "SC_CASC_OBJECT_PALETTE_INVALID";
  result.message = std::move(message);
  result.stage = "decode-palette";
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

}  // namespace

ObjectPaletteDecodeResult DecodeObjectPalettes(
    const std::vector<std::byte>& wpe_bytes,
    const std::vector<std::byte>& tunit_pcx_bytes) {
  if (wpe_bytes.size() != kWpeBytes) {
    return Failure("The object WPE palette must contain exactly 1,024 bytes.");
  }
  if (tunit_pcx_bytes.size() <
      kPcxHeaderBytes + kPcxPaletteMarkerBytes + kPcxPaletteBytes) {
    return Failure("The tunit PCX asset is truncated.");
  }
  if (ReadUint8(tunit_pcx_bytes, 0) != 0x0a ||
      ReadUint8(tunit_pcx_bytes, 2) != 1 ||
      ReadUint8(tunit_pcx_bytes, 3) != 8 ||
      ReadUint8(tunit_pcx_bytes, 65) != 1) {
    return Failure("The tunit PCX header is not supported.");
  }

  const auto left = ReadUint16(tunit_pcx_bytes, 4);
  const auto top = ReadUint16(tunit_pcx_bytes, 6);
  const auto right = ReadUint16(tunit_pcx_bytes, 8);
  const auto bottom = ReadUint16(tunit_pcx_bytes, 10);
  if (right < left || bottom < top) {
    return Failure("The tunit PCX dimensions are invalid.");
  }
  const auto width = static_cast<std::size_t>(right - left) + 1;
  const auto height = static_cast<std::size_t>(bottom - top) + 1;
  const auto bytes_per_line =
      static_cast<std::size_t>(ReadUint16(tunit_pcx_bytes, 66));
  if (width != kColorTableWidth || height != 1 || bytes_per_line < width ||
      bytes_per_line > 4096) {
    return Failure("The tunit PCX layout is not a supported color table (" +
                   std::to_string(width) + "x" + std::to_string(height) +
                   ", stride " + std::to_string(bytes_per_line) + ").");
  }

  const auto palette_marker_offset =
      tunit_pcx_bytes.size() - kPcxPaletteBytes - kPcxPaletteMarkerBytes;
  if (ReadUint8(tunit_pcx_bytes, palette_marker_offset) !=
      kPcxPaletteMarker) {
    return Failure("The tunit PCX palette marker is missing.");
  }
  const auto decoded_size = bytes_per_line * height;
  std::vector<std::uint8_t> decoded;
  decoded.reserve(decoded_size);
  auto cursor = kPcxHeaderBytes;
  while (decoded.size() < decoded_size) {
    if (cursor >= palette_marker_offset) {
      return Failure("The tunit PCX RLE data is truncated.");
    }
    const auto control = ReadUint8(tunit_pcx_bytes, cursor++);
    std::size_t run_length = 1;
    std::uint8_t palette_index = control;
    if ((control & 0xc0U) == 0xc0U) {
      run_length = control & 0x3fU;
      if (run_length == 0 || cursor >= palette_marker_offset) {
        return Failure("The tunit PCX contains an invalid RLE run.");
      }
      palette_index = ReadUint8(tunit_pcx_bytes, cursor++);
    }
    if (run_length > decoded_size - decoded.size()) {
      return Failure("The tunit PCX RLE data exceeds its dimensions.");
    }
    decoded.insert(decoded.end(), run_length, palette_index);
  }
  if (cursor != palette_marker_offset) {
    return Failure("The tunit PCX contains trailing compressed data.");
  }

  ObjectPaletteDecodeResult result;
  for (std::size_t index = 0; index < result.base_palette.size(); ++index) {
    const auto offset = index * 4;
    result.base_palette[index] = {
        ReadUint8(wpe_bytes, offset),
        ReadUint8(wpe_bytes, offset + 1),
        ReadUint8(wpe_bytes, offset + 2),
    };
  }
  const auto pcx_palette_offset = palette_marker_offset + 1;
  for (std::size_t player = 0; player < kObjectPlayerColorCount; ++player) {
    for (std::size_t shade = 0; shade < kGradientWidth; ++shade) {
      const auto palette_index = decoded[player * kGradientWidth + shade];
      const auto color_offset =
          pcx_palette_offset + static_cast<std::size_t>(palette_index) * 3;
      result.player_palettes[player][shade] = {
          ReadUint8(tunit_pcx_bytes, color_offset),
          ReadUint8(tunit_pcx_bytes, color_offset + 1),
          ReadUint8(tunit_pcx_bytes, color_offset + 2),
      };
    }
  }
  result.success = true;
  return result;
}

}  // namespace starcraft_map_editor::starcraft_data
