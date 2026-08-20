#include "object_atlas_protocol.h"
#include "object_asset_reader.h"
#include "object_grp_decoder.h"
#include "object_palette_decoder.h"

#include <Windows.h>

#include <array>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

namespace {

using starcraft_map_editor::starcraft_data::ObjectAtlasEntry;
using starcraft_map_editor::starcraft_data::ObjectGraphicKind;
using starcraft_map_editor::starcraft_data::ObjectPlayerRgbPalette;
using starcraft_map_editor::starcraft_data::ObjectRgbPalette;

int Fail(const std::string &message) {
  std::cerr << message << '\n';
  return 1;
}

void PutUint16(std::vector<std::byte> *const bytes, const std::size_t offset,
               const std::uint16_t value) {
  (*bytes)[offset] = static_cast<std::byte>(value & 0xFFU);
  (*bytes)[offset + 1] = static_cast<std::byte>((value >> 8U) & 0xFFU);
}

void PutUint32(std::vector<std::byte> *const bytes, const std::size_t offset,
               const std::uint32_t value) {
  for (std::size_t index = 0; index < 4; ++index) {
    (*bytes)[offset + index] =
        static_cast<std::byte>((value >> (index * 8U)) & 0xFFU);
  }
}

std::uint16_t ReadUint16(const std::vector<unsigned char> &bytes,
                         const std::size_t offset) {
  return static_cast<std::uint16_t>(
      bytes[offset] | (static_cast<std::uint16_t>(bytes[offset + 1]) << 8U));
}

std::uint32_t ReadUint32(const std::vector<unsigned char> &bytes,
                         const std::size_t offset) {
  std::uint32_t value = 0;
  for (std::size_t index = 0; index < 4; ++index) {
    value |= static_cast<std::uint32_t>(bytes[offset + index]) << (index * 8U);
  }
  return value;
}

std::vector<std::byte> MakeGrp() {
  std::vector<std::byte> grp(27);
  PutUint16(&grp, 0, 1);
  PutUint16(&grp, 2, 6);
  PutUint16(&grp, 4, 4);
  grp[6] = std::byte{1};
  grp[7] = std::byte{1};
  grp[8] = std::byte{4};
  grp[9] = std::byte{2};
  PutUint32(&grp, 10, 14);
  PutUint16(&grp, 14, 4);
  PutUint16(&grp, 16, 10);

  grp[18] = std::byte{0x81};
  grp[19] = std::byte{0x02};
  grp[20] = std::byte{2};
  grp[21] = std::byte{3};
  grp[22] = std::byte{0x41};
  grp[23] = std::byte{4};
  grp[24] = std::byte{0x42};
  grp[25] = std::byte{8};
  grp[26] = std::byte{0x82};
  return grp;
}

ObjectRgbPalette MakeBasePalette() {
  ObjectRgbPalette palette{};
  for (std::size_t index = 0; index < palette.size(); ++index) {
    palette[index] = {
        static_cast<std::uint8_t>(index),
        static_cast<std::uint8_t>(255 - index),
        static_cast<std::uint8_t>(index ^ 0x55U),
    };
  }
  return palette;
}

std::vector<std::byte> MakeWpe() {
  std::vector<std::byte> bytes(256 * 4);
  for (std::size_t index = 0; index < 256; ++index) {
    bytes[index * 4] = static_cast<std::byte>(index);
    bytes[index * 4 + 1] = static_cast<std::byte>(255 - index);
    bytes[index * 4 + 2] = static_cast<std::byte>(index ^ 0x55U);
  }
  return bytes;
}

std::vector<std::byte> MakeTunitPcx() {
  std::vector<std::byte> bytes(128 + 128 + 1 + 256 * 3);
  bytes[0] = std::byte{0x0a};
  bytes[2] = std::byte{1};
  bytes[3] = std::byte{8};
  PutUint16(&bytes, 8, 127);
  bytes[65] = std::byte{1};
  PutUint16(&bytes, 66, 128);
  for (std::size_t index = 0; index < 128; ++index) {
    bytes[128 + index] = static_cast<std::byte>(index);
  }
  const auto marker = 128 + 128;
  bytes[marker] = std::byte{0x0c};
  for (std::size_t index = 0; index < 256; ++index) {
    bytes[marker + 1 + index * 3] = static_cast<std::byte>(index);
    bytes[marker + 1 + index * 3 + 1] =
        static_cast<std::byte>(index ^ 0x33U);
    bytes[marker + 1 + index * 3 + 2] =
        static_cast<std::byte>(255 - index);
  }
  return bytes;
}

bool HasPixel(const std::vector<std::byte> &rgba, const std::size_t width,
              const std::size_t x, const std::size_t y, const std::uint8_t red,
              const std::uint8_t green, const std::uint8_t blue,
              const std::uint8_t alpha) {
  const auto offset = (y * width + x) * 4;
  return std::to_integer<std::uint8_t>(rgba[offset]) == red &&
         std::to_integer<std::uint8_t>(rgba[offset + 1]) == green &&
         std::to_integer<std::uint8_t>(rgba[offset + 2]) == blue &&
         std::to_integer<std::uint8_t>(rgba[offset + 3]) == alpha;
}

ObjectAtlasEntry MakeEntry(const ObjectGraphicKind kind,
                           const std::uint16_t object_id,
                           const std::uint8_t player_color,
                           const std::vector<std::byte> &rgba) {
  ObjectAtlasEntry entry;
  entry.kind = kind;
  entry.player_color = player_color;
  entry.object_id = object_id;
  entry.sprite_id = kind == ObjectGraphicKind::kSprite ? object_id : 11;
  entry.image_id = 42;
  entry.width = 6;
  entry.height = 4;
  entry.anchor_x = 3;
  entry.anchor_y = 2;
  entry.rgba_bytes = rgba;
  return entry;
}

} // namespace

int main() {
  using namespace starcraft_map_editor::starcraft_data;

  const auto grp = MakeGrp();
  const auto base_palette = MakeBasePalette();

  const auto palettes = DecodeObjectPalettes(MakeWpe(), MakeTunitPcx());
  if (!palettes.success || palettes.base_palette[0].red != 0 ||
      palettes.base_palette[0].green != 255 ||
      palettes.base_palette[255].blue != (255 ^ 0x55U) ||
      palettes.player_palettes[3][5].red != 29 ||
      palettes.player_palettes[3][5].green != (29 ^ 0x33U) ||
      palettes.player_palettes[3][5].blue != 226) {
    return Fail("Synthetic WPE and tunit PCX palettes decoded incorrectly.");
  }
  auto invalid_pcx = MakeTunitPcx();
  invalid_pcx[128 + 128] = std::byte{0};
  if (DecodeObjectPalettes(MakeWpe(), invalid_pcx).success) {
    return Fail("A tunit PCX without a palette marker was accepted.");
  }
  invalid_pcx = MakeTunitPcx();
  invalid_pcx.insert(invalid_pcx.begin() + 128, std::byte{1});
  if (DecodeObjectPalettes(MakeWpe(), invalid_pcx).success) {
    return Fail("A tunit PCX with trailing compressed data was accepted.");
  }
  auto invalid_wpe = MakeWpe();
  invalid_wpe.pop_back();
  if (DecodeObjectPalettes(invalid_wpe, MakeTunitPcx()).success) {
    return Fail("A truncated WPE palette was accepted.");
  }

  const std::vector<ObjectRenderRequest> render_requests = {
      {ObjectGraphicKind::kUnit, 0, 0, 0},
      {ObjectGraphicKind::kSprite, 1, kNeutralObjectPlayerColor, 0},
  };
  if (!ValidateObjectRenderRequests(render_requests)) {
    return Fail("Valid object render requests were rejected.");
  }
  auto invalid_requests = render_requests;
  invalid_requests[1] = invalid_requests[0];
  if (ValidateObjectRenderRequests(invalid_requests)) {
    return Fail("Duplicate object render requests were accepted.");
  }
  invalid_requests = render_requests;
  invalid_requests[0].player_color = 8;
  if (ValidateObjectRenderRequests(invalid_requests)) {
    return Fail("An invalid render request player color was accepted.");
  }
  invalid_requests = render_requests;
  invalid_requests[0].direction = kObjectPreviewDirection + 1;
  if (ValidateObjectRenderRequests(invalid_requests)) {
    return Fail("An unsupported preview direction was accepted.");
  }

  const auto decoded = DecodeObjectGrpFirstFrame(grp, base_palette);
  if (!decoded.success || decoded.width != 6 || decoded.height != 4 ||
      decoded.anchor_x != 3 || decoded.anchor_y != 2 ||
      decoded.frame_index != kObjectPreviewFrameIndex ||
      decoded.rgba_bytes.size() != 6 * 4 * 4) {
    return Fail("A synthetic GRP did not decode to its logical RGBA canvas.");
  }
  if (!HasPixel(decoded.rgba_bytes, 6, 0, 0, 0, 0, 0, 0) ||
      !HasPixel(decoded.rgba_bytes, 6, 1, 1, 0, 0, 0, 0) ||
      !HasPixel(decoded.rgba_bytes, 6, 2, 1, 2, 253, 0x57, 255) ||
      !HasPixel(decoded.rgba_bytes, 6, 3, 1, 3, 252, 0x56, 255) ||
      !HasPixel(decoded.rgba_bytes, 6, 4, 1, 4, 251, 0x51, 255) ||
      !HasPixel(decoded.rgba_bytes, 6, 1, 2, 8, 247, 0x5D, 255) ||
      !HasPixel(decoded.rgba_bytes, 6, 3, 2, 0, 0, 0, 0)) {
    return Fail("GRP RLE runs, offsets, or transparency decoded incorrectly.");
  }

  ObjectPlayerRgbPalette player_palette{};
  player_palette[0] = {201, 37, 99};
  const auto player_decoded =
      DecodeObjectGrpFirstFrame(grp, base_palette, &player_palette);
  if (!player_decoded.success ||
      !HasPixel(player_decoded.rgba_bytes, 6, 1, 2, 201, 37, 99, 255) ||
      !HasPixel(player_decoded.rgba_bytes, 6, 2, 1, 2, 253, 0x57, 255)) {
    return Fail("GRP player-color palette remapping is incorrect.");
  }

  auto invalid = grp;
  invalid.pop_back();
  if (DecodeObjectGrpFirstFrame(invalid, base_palette).error_code !=
      "SC_CASC_OBJECT_GRP_INVALID") {
    return Fail("A truncated GRP row was accepted.");
  }
  invalid = grp;
  PutUint16(&invalid, 0, 0);
  if (DecodeObjectGrpFirstFrame(invalid, base_palette).success) {
    return Fail("A GRP without frames was accepted.");
  }
  invalid = grp;
  PutUint16(&invalid, 2, 1025);
  if (DecodeObjectGrpFirstFrame(invalid, base_palette).error_code !=
      "SC_CASC_OBJECT_GRP_TOO_LARGE") {
    return Fail("An oversized GRP canvas was accepted.");
  }
  invalid = grp;
  PutUint32(&invalid, 10, 13);
  if (DecodeObjectGrpFirstFrame(invalid, base_palette).success) {
    return Fail("A GRP frame offset inside the header was accepted.");
  }
  invalid = grp;
  invalid[6] = std::byte{3};
  if (DecodeObjectGrpFirstFrame(invalid, base_palette).success) {
    return Fail("A GRP frame outside its logical canvas was accepted.");
  }
  invalid = grp;
  PutUint16(&invalid, 14, 2);
  if (DecodeObjectGrpFirstFrame(invalid, base_palette).success) {
    return Fail("A GRP row offset inside its row table was accepted.");
  }
  invalid = grp;
  PutUint16(&invalid, 16, 4);
  if (DecodeObjectGrpFirstFrame(invalid, base_palette).success) {
    return Fail("Non-increasing GRP row offsets were accepted.");
  }
  invalid = grp;
  invalid[18] = std::byte{0};
  if (DecodeObjectGrpFirstFrame(invalid, base_palette).success) {
    return Fail("A zero-length GRP RLE run was accepted.");
  }
  invalid = grp;
  invalid[18] = std::byte{0x85};
  if (DecodeObjectGrpFirstFrame(invalid, base_palette).success) {
    return Fail("A GRP RLE run beyond the row width was accepted.");
  }
  invalid = grp;
  PutUint16(&invalid, 16, 8);
  invalid[18] = std::byte{4};
  if (DecodeObjectGrpFirstFrame(invalid, base_palette).success) {
    return Fail("A truncated GRP literal run was accepted.");
  }
  invalid = grp;
  PutUint16(&invalid, 16, 6);
  invalid[18] = std::byte{0x83};
  invalid[19] = std::byte{0x41};
  if (DecodeObjectGrpFirstFrame(invalid, base_palette).success) {
    return Fail("A truncated GRP solid run was accepted.");
  }

  const auto unit_entry =
      MakeEntry(ObjectGraphicKind::kUnit, 7, 0, player_decoded.rgba_bytes);
  const auto sprite_entry =
      MakeEntry(ObjectGraphicKind::kSprite, 11, kNeutralObjectPlayerColor,
                decoded.rgba_bytes);
  const std::vector<ObjectAtlasEntry> entries = {unit_entry, sprite_entry};
  if (!ValidateObjectAtlasEntries(entries)) {
    return Fail("Valid object atlas entries were rejected.");
  }
  auto invalid_entries = entries;
  invalid_entries[1] = invalid_entries[0];
  if (ValidateObjectAtlasEntries(invalid_entries)) {
    return Fail("Duplicate object atlas keys were accepted.");
  }
  invalid_entries = entries;
  invalid_entries[0].rgba_bytes.pop_back();
  if (ValidateObjectAtlasEntries(invalid_entries)) {
    return Fail("An inconsistent object RGBA byte length was accepted.");
  }
  invalid_entries = entries;
  invalid_entries[0].player_color = 8;
  if (ValidateObjectAtlasEntries(invalid_entries)) {
    return Fail("An unsupported object player color was accepted.");
  }

  std::vector<ObjectAtlasEntry> oversized_entries;
  for (std::uint8_t player_color = 0; player_color < 8; ++player_color) {
    ObjectAtlasEntry entry;
    entry.kind = ObjectGraphicKind::kUnit;
    entry.player_color = player_color;
    entry.object_id = 0;
    entry.sprite_id = 0;
    entry.image_id = 0;
    entry.width = 1024;
    entry.height = 1024;
    entry.anchor_x = 512;
    entry.anchor_y = 512;
    entry.rgba_bytes.resize(kMaximumObjectFrameBytes);
    oversized_entries.push_back(std::move(entry));
  }
  if (!ValidateObjectAtlasEntries(oversized_entries) ||
      WriteObjectAtlas({}, oversized_entries).error_code !=
          "SC_CASC_OBJECT_ATLAS_OUTPUT_TOO_LARGE") {
    return Fail("The object atlas 32 MiB limit was not enforced.");
  }

  wchar_t temporary_root[MAX_PATH] = {};
  if (GetTempPathW(MAX_PATH, temporary_root) == 0) {
    return Fail("Windows temporary path is unavailable.");
  }
  const auto test_root = std::filesystem::path(temporary_root) /
                         ("starcraft_object_graphics_native_" +
                          std::to_string(GetCurrentProcessId()));
  std::error_code filesystem_error;
  std::filesystem::remove_all(test_root, filesystem_error);
  filesystem_error.clear();
  if (!std::filesystem::create_directory(test_root, filesystem_error) ||
      filesystem_error) {
    return Fail("Could not create the object graphics test directory.");
  }

  const auto atlas = WriteObjectAtlas(test_root, entries);
  if (!atlas.success || atlas.entry_count != 2 || atlas.pixel_bytes != 192 ||
      atlas.file_bytes != 32 + 2 * 32 + 192) {
    std::filesystem::remove_all(test_root, filesystem_error);
    return Fail("A valid object atlas could not be written.");
  }
  std::vector<unsigned char> atlas_bytes(
      static_cast<std::size_t>(atlas.file_bytes));
  {
    std::ifstream atlas_file(test_root / kObjectAtlasFileName,
                             std::ios::binary);
    atlas_file.read(reinterpret_cast<char *>(atlas_bytes.data()),
                    static_cast<std::streamsize>(atlas_bytes.size()));
    if (atlas_file.gcount() !=
        static_cast<std::streamsize>(atlas_bytes.size())) {
      std::filesystem::remove_all(test_root, filesystem_error);
      return Fail("The object atlas output was truncated.");
    }
  }
  if (atlas_bytes[0] != 'S' || atlas_bytes[1] != 'C' || atlas_bytes[2] != 'O' ||
      atlas_bytes[6] != 'A' || atlas_bytes[7] != 0 ||
      ReadUint16(atlas_bytes, 8) != 1 || ReadUint16(atlas_bytes, 10) != 32 ||
      ReadUint32(atlas_bytes, 12) != 2 || ReadUint32(atlas_bytes, 16) != 64 ||
      ReadUint32(atlas_bytes, 20) != 192 || atlas_bytes[32] != 0 ||
      atlas_bytes[33] != 0 || ReadUint16(atlas_bytes, 36) != 7 ||
      ReadUint16(atlas_bytes, 38) != 11 || ReadUint16(atlas_bytes, 40) != 42 ||
      ReadUint16(atlas_bytes, 42) != 6 || ReadUint16(atlas_bytes, 44) != 4 ||
      ReadUint16(atlas_bytes, 46) != 3 || ReadUint16(atlas_bytes, 48) != 2 ||
      ReadUint32(atlas_bytes, 52) != 0 || ReadUint32(atlas_bytes, 56) != 96 ||
      atlas_bytes[64] != 1 || atlas_bytes[65] != 255 ||
      ReadUint32(atlas_bytes, 84) != 96 || ReadUint32(atlas_bytes, 88) != 96 ||
      atlas_bytes[96 + (2 * 6 + 1) * 4] != 201) {
    std::filesystem::remove_all(test_root, filesystem_error);
    return Fail("The object atlas binary fields are invalid.");
  }

  const auto duplicate_output = WriteObjectAtlas(test_root, entries);
  if (duplicate_output.success ||
      duplicate_output.error_code != "SC_CASC_OBJECT_ATLAS_OUTPUT_EXISTS") {
    std::filesystem::remove_all(test_root, filesystem_error);
    return Fail("An existing object atlas output was overwritten.");
  }

  const auto empty_root = test_root / "empty";
  if (!std::filesystem::create_directory(empty_root, filesystem_error) ||
      filesystem_error) {
    std::filesystem::remove_all(test_root, filesystem_error);
    return Fail("Could not create the empty object atlas directory.");
  }
  const auto empty_atlas = WriteObjectAtlas(empty_root, {});
  if (!empty_atlas.success || empty_atlas.entry_count != 0 ||
      empty_atlas.pixel_bytes != 0 || empty_atlas.file_bytes != 32) {
    std::filesystem::remove_all(test_root, filesystem_error);
    return Fail("An empty object atlas envelope could not be written.");
  }

  std::filesystem::remove_all(test_root, filesystem_error);
  return 0;
}
