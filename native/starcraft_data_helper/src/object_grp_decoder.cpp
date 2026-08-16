#include "object_grp_decoder.h"

#include <cstddef>
#include <limits>
#include <utility>

namespace starcraft_map_editor::starcraft_data {
namespace {

constexpr std::size_t kGrpHeaderBytes = 6;
constexpr std::size_t kGrpFrameHeaderBytes = 8;
constexpr std::uint16_t kMaximumGrpFrameCount = 2400;

ObjectGrpDecodeResult Failure(std::string code, std::string message,
                              std::string stage) {
  ObjectGrpDecodeResult result;
  result.error_code = std::move(code);
  result.message = std::move(message);
  result.stage = std::move(stage);
  return result;
}

std::uint16_t ReadUint16(const std::vector<std::byte> &bytes,
                         const std::size_t offset) {
  return static_cast<std::uint16_t>(
      std::to_integer<std::uint8_t>(bytes[offset]) |
      (static_cast<std::uint16_t>(
           std::to_integer<std::uint8_t>(bytes[offset + 1]))
       << 8U));
}

std::uint32_t ReadUint32(const std::vector<std::byte> &bytes,
                         const std::size_t offset) {
  std::uint32_t value = 0;
  for (std::size_t index = 0; index < 4; ++index) {
    value |= static_cast<std::uint32_t>(
                 std::to_integer<std::uint8_t>(bytes[offset + index]))
             << (index * 8U);
  }
  return value;
}

const ObjectRgbColor &
ResolveColor(const std::uint8_t palette_index,
             const ObjectRgbPalette &base_palette,
             const ObjectPlayerRgbPalette *const player_palette) {
  if (player_palette != nullptr && palette_index >= 8U &&
      palette_index <= 15U) {
    return (*player_palette)[palette_index - 8U];
  }
  return base_palette[palette_index];
}

void PutPixel(std::vector<std::byte> *const rgba_bytes,
              const std::size_t pixel_index, const ObjectRgbColor &color) {
  const auto offset = pixel_index * 4;
  (*rgba_bytes)[offset] = static_cast<std::byte>(color.red);
  (*rgba_bytes)[offset + 1] = static_cast<std::byte>(color.green);
  (*rgba_bytes)[offset + 2] = static_cast<std::byte>(color.blue);
  (*rgba_bytes)[offset + 3] = static_cast<std::byte>(0xFFU);
}

} // namespace

ObjectGrpDecodeResult
DecodeObjectGrpFirstFrame(const std::vector<std::byte> &grp_bytes,
                          const ObjectRgbPalette &base_palette,
                          const ObjectPlayerRgbPalette *const player_palette) {
  if (grp_bytes.size() < kGrpHeaderBytes ||
      grp_bytes.size() > kMaximumObjectGrpBytes) {
    return Failure("SC_CASC_OBJECT_GRP_INVALID",
                   "The object GRP size is outside the supported range.",
                   "decode-grp");
  }

  const auto frame_count = ReadUint16(grp_bytes, 0);
  const auto canvas_width = ReadUint16(grp_bytes, 2);
  const auto canvas_height = ReadUint16(grp_bytes, 4);
  if (frame_count == 0 || frame_count > kMaximumGrpFrameCount ||
      canvas_width == 0 || canvas_height == 0) {
    return Failure("SC_CASC_OBJECT_GRP_INVALID",
                   "The object GRP header is invalid.", "decode-grp");
  }
  if (canvas_width > kMaximumObjectGrpDimension ||
      canvas_height > kMaximumObjectGrpDimension) {
    return Failure("SC_CASC_OBJECT_GRP_TOO_LARGE",
                   "The object GRP canvas exceeds the dimension limit.",
                   "decode-grp");
  }

  const auto frame_table_bytes =
      static_cast<std::size_t>(frame_count) * kGrpFrameHeaderBytes;
  const auto frame_data_minimum = kGrpHeaderBytes + frame_table_bytes;
  if (frame_data_minimum > grp_bytes.size()) {
    return Failure("SC_CASC_OBJECT_GRP_INVALID",
                   "The object GRP frame table is truncated.", "decode-grp");
  }

  const auto pixel_count =
      static_cast<std::size_t>(canvas_width) * canvas_height;
  if (pixel_count > kMaximumObjectFrameBytes / 4) {
    return Failure("SC_CASC_OBJECT_GRP_TOO_LARGE",
                   "The decoded object frame exceeds the byte limit.",
                   "decode-grp");
  }

  const auto frame_x =
      std::to_integer<std::uint8_t>(grp_bytes[kGrpHeaderBytes]);
  const auto frame_y =
      std::to_integer<std::uint8_t>(grp_bytes[kGrpHeaderBytes + 1]);
  const auto frame_width =
      std::to_integer<std::uint8_t>(grp_bytes[kGrpHeaderBytes + 2]);
  const auto frame_height =
      std::to_integer<std::uint8_t>(grp_bytes[kGrpHeaderBytes + 3]);
  const auto frame_offset =
      static_cast<std::size_t>(ReadUint32(grp_bytes, kGrpHeaderBytes + 4));
  if (frame_width == 0 || frame_height == 0 ||
      static_cast<std::size_t>(frame_x) + frame_width > canvas_width ||
      static_cast<std::size_t>(frame_y) + frame_height > canvas_height ||
      frame_offset < frame_data_minimum || frame_offset > grp_bytes.size()) {
    return Failure("SC_CASC_OBJECT_GRP_INVALID",
                   "The first object GRP frame header is invalid.",
                   "decode-grp");
  }

  const auto row_table_bytes =
      static_cast<std::size_t>(frame_height) * sizeof(std::uint16_t);
  if (row_table_bytes > grp_bytes.size() - frame_offset) {
    return Failure("SC_CASC_OBJECT_GRP_INVALID",
                   "The first object GRP row table is truncated.",
                   "decode-grp");
  }

  std::vector<std::size_t> row_offsets(frame_height);
  std::size_t previous_row_offset = 0;
  for (std::size_t row = 0; row < frame_height; ++row) {
    const auto relative_offset =
        static_cast<std::size_t>(ReadUint16(grp_bytes, frame_offset + row * 2));
    if (relative_offset < row_table_bytes ||
        relative_offset >= grp_bytes.size() - frame_offset ||
        (row > 0 && relative_offset <= previous_row_offset)) {
      return Failure("SC_CASC_OBJECT_GRP_INVALID",
                     "An object GRP row offset is invalid.", "decode-grp");
    }
    row_offsets[row] = frame_offset + relative_offset;
    previous_row_offset = relative_offset;
  }

  ObjectGrpDecodeResult result;
  result.width = canvas_width;
  result.height = canvas_height;
  result.anchor_x = static_cast<std::int16_t>(canvas_width / 2);
  result.anchor_y = static_cast<std::int16_t>(canvas_height / 2);
  result.rgba_bytes.resize(pixel_count * 4);

  for (std::size_t row = 0; row < frame_height; ++row) {
    auto cursor = row_offsets[row];
    const auto row_end =
        row + 1 < frame_height ? row_offsets[row + 1] : grp_bytes.size();
    std::size_t decoded_x = 0;
    while (decoded_x < frame_width) {
      if (cursor >= row_end) {
        return Failure("SC_CASC_OBJECT_GRP_INVALID",
                       "An object GRP row is truncated.", "decode-grp");
      }
      const auto control = std::to_integer<std::uint8_t>(grp_bytes[cursor++]);
      const bool transparent = (control & 0x80U) != 0;
      const bool solid = !transparent && (control & 0x40U) != 0;
      const auto run_length =
          static_cast<std::size_t>(control & (transparent ? 0x7FU
                                              : solid     ? 0x3FU
                                                          : 0x3FU));
      if (run_length == 0 || run_length > frame_width - decoded_x) {
        return Failure("SC_CASC_OBJECT_GRP_INVALID",
                       "An object GRP RLE run has an invalid length.",
                       "decode-grp");
      }

      if (transparent) {
        decoded_x += run_length;
        continue;
      }
      if (solid) {
        if (cursor >= row_end) {
          return Failure("SC_CASC_OBJECT_GRP_INVALID",
                         "An object GRP solid run is truncated.", "decode-grp");
        }
        const auto palette_index =
            std::to_integer<std::uint8_t>(grp_bytes[cursor++]);
        const auto &color =
            ResolveColor(palette_index, base_palette, player_palette);
        for (std::size_t index = 0; index < run_length; ++index) {
          const auto canvas_pixel =
              (static_cast<std::size_t>(frame_y) + row) * canvas_width +
              frame_x + decoded_x + index;
          PutPixel(&result.rgba_bytes, canvas_pixel, color);
        }
      } else {
        if (run_length > row_end - cursor) {
          return Failure("SC_CASC_OBJECT_GRP_INVALID",
                         "An object GRP literal run is truncated.",
                         "decode-grp");
        }
        for (std::size_t index = 0; index < run_length; ++index) {
          const auto palette_index =
              std::to_integer<std::uint8_t>(grp_bytes[cursor++]);
          const auto &color =
              ResolveColor(palette_index, base_palette, player_palette);
          const auto canvas_pixel =
              (static_cast<std::size_t>(frame_y) + row) * canvas_width +
              frame_x + decoded_x + index;
          PutPixel(&result.rgba_bytes, canvas_pixel, color);
        }
      }
      decoded_x += run_length;
    }
  }

  result.success = true;
  return result;
}

} // namespace starcraft_map_editor::starcraft_data
