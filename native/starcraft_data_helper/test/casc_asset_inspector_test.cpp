#include "casc_asset_inspector.h"
#include "tile_atlas_protocol.h"
#include "tileset_asset_reader.h"
#include "tileset_tile_decoder.h"

#include <Windows.h>

#include <algorithm>
#include <array>
#include <cstddef>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <set>
#include <string>
#include <vector>

namespace {

int Fail(const std::string& message) {
  std::cerr << message << '\n';
  return 1;
}

void PutUint16(
    std::vector<std::byte>* const bytes,
    const std::size_t offset,
    const std::uint16_t value) {
  (*bytes)[offset] = static_cast<std::byte>(value & 0xFFU);
  (*bytes)[offset + 1] =
      static_cast<std::byte>((value >> 8U) & 0xFFU);
}

void PutUint32(
    std::vector<std::byte>* const bytes,
    const std::size_t offset,
    const std::uint32_t value) {
  for (std::size_t index = 0; index < 4; ++index) {
    (*bytes)[offset + index] =
        static_cast<std::byte>((value >> (index * 8U)) & 0xFFU);
  }
}

std::array<std::vector<std::byte>, 4> MakeTileAssets() {
  std::array<std::vector<std::byte>, 4> assets = {
      std::vector<std::byte>(52),
      std::vector<std::byte>(2 * 64),
      std::vector<std::byte>(2 * 64),
      std::vector<std::byte>(256 * 4),
  };
  PutUint16(&assets[0], 20, 0);
  PutUint16(&assets[0], 22, 1);
  for (std::size_t mini_tile = 0; mini_tile < 16; ++mini_tile) {
    PutUint32(&assets[1], mini_tile * 4, 0);
    PutUint32(&assets[1], 64 + mini_tile * 4, 3);
  }
  for (std::size_t y = 0; y < 8; ++y) {
    for (std::size_t x = 0; x < 8; ++x) {
      assets[2][y * 8 + x] = static_cast<std::byte>(y * 8 + x);
      assets[2][64 + y * 8 + x] = static_cast<std::byte>(100 + x);
    }
  }
  for (std::size_t color = 0; color < 256; ++color) {
    assets[3][color * 4] = static_cast<std::byte>(color);
    assets[3][color * 4 + 1] = static_cast<std::byte>(255 - color);
    assets[3][color * 4 + 2] = static_cast<std::byte>(color ^ 0x55U);
    assets[3][color * 4 + 3] = static_cast<std::byte>(0x7FU);
  }
  return assets;
}

bool HasColor(
    const std::vector<std::byte>& pixels,
    const std::size_t pixel_offset,
    const std::uint8_t red,
    const std::uint8_t green,
    const std::uint8_t blue) {
  return std::to_integer<std::uint8_t>(pixels[pixel_offset]) == red &&
         std::to_integer<std::uint8_t>(pixels[pixel_offset + 1]) == green &&
         std::to_integer<std::uint8_t>(pixels[pixel_offset + 2]) == blue &&
         std::to_integer<std::uint8_t>(pixels[pixel_offset + 3]) == 0xFFU;
}

}  // namespace

int main() {
  const auto& paths =
      starcraft_map_editor::starcraft_data::RequiredAssetPaths();
  if (paths.size() !=
      starcraft_map_editor::starcraft_data::kRequiredAssetCount) {
    return Fail("Required StarCraft asset count is not 40.");
  }
  const std::set<std::string_view> unique_paths(paths.begin(), paths.end());
  if (unique_paths.size() != paths.size()) {
    return Fail("Required StarCraft asset paths contain duplicates.");
  }
  if (std::any_of(
          paths.begin(),
          paths.end(),
          [](const std::string_view path) {
            return path.rfind("tileset\\", 0) != 0;
          })) {
    return Fail("A required StarCraft asset is outside tileset.");
  }
  if (unique_paths.count("tileset\\badlands.vx4ex") != 1 ||
      std::any_of(
          paths.begin(),
          paths.end(),
          [](const std::string_view path) {
            constexpr std::string_view suffix = ".vx4";
            return path.size() >= suffix.size() &&
                   path.substr(path.size() - suffix.size()) == suffix;
          })) {
    return Fail("The SC:R manifest must use extended VX4EX megatiles.");
  }

  const auto& render_paths =
      starcraft_map_editor::starcraft_data::RenderTilesetAssetPaths();
  if (render_paths.size() !=
      starcraft_map_editor::starcraft_data::kTilesetCount) {
    return Fail("Render manifest does not contain eight tilesets.");
  }
  for (const auto& tileset_paths : render_paths) {
    if (tileset_paths.size() !=
        starcraft_map_editor::starcraft_data::kRenderAssetCount) {
      return Fail("Render manifest does not contain four assets per tileset.");
    }
    for (const auto path : tileset_paths) {
      if (unique_paths.count(path) != 1 ||
          path.find(".vf4") != std::string_view::npos) {
        return Fail("Render manifest escaped the inspected fixed paths.");
      }
    }
  }
  if (render_paths[0] !=
      std::array<std::string_view, 4>{
          "tileset\\badlands.cv5",
          "tileset\\badlands.vx4ex",
          "tileset\\badlands.vr4",
          "tileset\\badlands.wpe"}) {
    return Fail("Render asset order is not CV5/VX4EX/VR4/WPE.");
  }

  using starcraft_map_editor::starcraft_data::ValidateRawValues;
  if (!ValidateRawValues({0, 1, 0xFFFF}) ||
      ValidateRawValues({}) ||
      ValidateRawValues({1, 1}) ||
      ValidateRawValues({2, 1}) ||
      ValidateRawValues({0x10000})) {
    return Fail("Tile raw-value protocol validation is inconsistent.");
  }
  std::vector<std::uint32_t> maximum_raw_values(
      starcraft_map_editor::starcraft_data::kMaximumRawValues);
  for (std::size_t index = 0; index < maximum_raw_values.size(); ++index) {
    maximum_raw_values[index] = static_cast<std::uint32_t>(index);
  }
  if (!ValidateRawValues(maximum_raw_values)) {
    return Fail("A maximum-size raw-value batch was rejected.");
  }
  maximum_raw_values.push_back(0xFFFF);
  if (ValidateRawValues(maximum_raw_values)) {
    return Fail("An oversized raw-value batch was accepted.");
  }

  const auto valid_tile_assets = MakeTileAssets();
  const auto decoded =
      starcraft_map_editor::starcraft_data::DecodeTilesetTiles(
          valid_tile_assets, {0, 1, 16, 0x4000, 0xFFFF});
  if (!decoded.success ||
      decoded.rendered_raw_values != std::vector<std::uint16_t>({0, 1}) ||
      decoded.unsupported_raw_values !=
          std::vector<std::uint32_t>({16, 0x4000, 0xFFFF}) ||
      decoded.rgba_bytes.size() != 2 * 32 * 32 * 4) {
    return Fail("Synthetic tiles were not decoded into the expected batch.");
  }
  if (!HasColor(decoded.rgba_bytes, 0, 0, 255, 0x55) ||
      !HasColor(decoded.rgba_bytes, 7 * 4, 7, 248, 0x52) ||
      !HasColor(decoded.rgba_bytes, 32 * 32 * 4, 107, 148, 0x3E) ||
      !HasColor(decoded.rgba_bytes, 32 * 32 * 4 + 7 * 4, 100, 155, 0x31)) {
    return Fail("Palette colors or VX4EX horizontal flipping are incorrect.");
  }

  for (std::size_t asset_index = 0; asset_index < 4; ++asset_index) {
    auto truncated = valid_tile_assets;
    truncated[asset_index].pop_back();
    const auto invalid =
        starcraft_map_editor::starcraft_data::DecodeTilesetTiles(
            truncated, {0});
    if (invalid.success ||
        invalid.error_code != "SC_CASC_TILE_ASSET_INVALID") {
      return Fail("A truncated tile asset was accepted by the decoder.");
    }
  }
  auto oversized_cv5 = valid_tile_assets;
  oversized_cv5[0].resize(4097 * 52);
  if (starcraft_map_editor::starcraft_data::DecodeTilesetTiles(
          oversized_cv5, {0}).success) {
    return Fail("A CV5 with more than 4,096 addressable groups was accepted.");
  }
  auto invalid_cv5_reference = valid_tile_assets;
  PutUint16(&invalid_cv5_reference[0], 20, 2);
  if (starcraft_map_editor::starcraft_data::DecodeTilesetTiles(
          invalid_cv5_reference, {0}).success) {
    return Fail("An out-of-range CV5 mega-tile reference was accepted.");
  }
  auto invalid_vx4ex_reference = valid_tile_assets;
  PutUint32(&invalid_vx4ex_reference[1], 0, 4);
  if (starcraft_map_editor::starcraft_data::DecodeTilesetTiles(
          invalid_vx4ex_reference, {0}).success) {
    return Fail("An out-of-range VX4EX mini-tile reference was accepted.");
  }

  wchar_t temporary_root[MAX_PATH] = {};
  if (GetTempPathW(MAX_PATH, temporary_root) == 0) {
    return Fail("Windows temporary path is unavailable.");
  }
  const auto empty_storage =
      std::filesystem::path(temporary_root) /
      ("starcraft_data_helper_native_" + std::to_string(GetCurrentProcessId()));
  std::error_code error;
  std::filesystem::remove_all(empty_storage, error);
  error.clear();
  if (!std::filesystem::create_directory(empty_storage, error) || error) {
    return Fail("Could not create the empty CASC test directory.");
  }

  const auto result =
      starcraft_map_editor::starcraft_data::InspectInstallation(empty_storage);
  if (result.success) {
    return Fail("An empty directory was accepted as StarCraft CASC storage.");
  }
  if (result.error_code != "SC_CASC_STORAGE_OPEN_FAILED") {
    return Fail("Unexpected diagnostic for an empty CASC directory.");
  }

  const auto tile_assets =
      starcraft_map_editor::starcraft_data::ReadTilesetAssets(empty_storage, 0);
  if (tile_assets.success ||
      tile_assets.error_code != "SC_CASC_STORAGE_OPEN_FAILED") {
    return Fail("Tile asset reading accepted an empty CASC directory.");
  }
  const auto invalid_tileset =
      starcraft_map_editor::starcraft_data::ReadTilesetAssets(empty_storage, 8);
  if (invalid_tileset.success ||
      invalid_tileset.error_code != "SC_CASC_PROTOCOL_INVALID_TILESET") {
    return Fail("Tile asset reading accepted an arbitrary tileset.");
  }

  const auto atlas =
      starcraft_map_editor::starcraft_data::WriteEmptyTileAtlas(empty_storage);
  if (!atlas.success || atlas.file_bytes != 32) {
    return Fail("An empty tile atlas envelope could not be written.");
  }
  std::array<unsigned char, 32> atlas_header{};
  std::ifstream atlas_file(
      empty_storage / "tile-atlas.rgba", std::ios::binary);
  atlas_file.read(
      reinterpret_cast<char*>(atlas_header.data()),
      static_cast<std::streamsize>(atlas_header.size()));
  if (atlas_file.gcount() !=
          static_cast<std::streamsize>(atlas_header.size()) ||
      atlas_header[0] != 'S' || atlas_header[1] != 'C' ||
      atlas_header[2] != 'T' || atlas_header[7] != 0 ||
      atlas_header[8] != 1 || atlas_header[10] != 32) {
    return Fail("The empty tile atlas header is invalid.");
  }
  const auto duplicate_atlas =
      starcraft_map_editor::starcraft_data::WriteEmptyTileAtlas(empty_storage);
  if (duplicate_atlas.success ||
      duplicate_atlas.error_code != "SC_CASC_TILE_ATLAS_OUTPUT_EXISTS") {
    return Fail("An existing tile atlas output was overwritten.");
  }

  const auto filled_atlas_directory = empty_storage / "filled";
  if (!std::filesystem::create_directory(filled_atlas_directory, error) ||
      error) {
    return Fail("Could not create the filled-atlas test directory.");
  }
  const auto filled_atlas =
      starcraft_map_editor::starcraft_data::WriteTileAtlas(
          filled_atlas_directory,
          decoded.rendered_raw_values,
          decoded.rgba_bytes);
  if (!filled_atlas.success || filled_atlas.columns != 2 ||
      filled_atlas.rows != 1 || filled_atlas.tile_count != 2 ||
      filled_atlas.file_bytes != 32 + 2 * 4 + 2 * 32 * 32 * 4) {
    return Fail("A decoded tile atlas envelope could not be written.");
  }
  std::ifstream filled_file(
      filled_atlas_directory / "tile-atlas.rgba", std::ios::binary);
  std::vector<unsigned char> filled_bytes(
      static_cast<std::size_t>(filled_atlas.file_bytes));
  filled_file.read(
      reinterpret_cast<char*>(filled_bytes.data()),
      static_cast<std::streamsize>(filled_bytes.size()));
  if (filled_file.gcount() !=
          static_cast<std::streamsize>(filled_bytes.size()) ||
      filled_bytes[12] != 2 || filled_bytes[14] != 1 ||
      filled_bytes[16] != 2 || filled_bytes[20] != 8 ||
      filled_bytes[32] != 0 || filled_bytes[36] != 1 ||
      filled_bytes[40] != 0 || filled_bytes[41] != 255 ||
      filled_bytes[42] != 0x55 || filled_bytes[43] != 255) {
    return Fail("The decoded tile atlas envelope fields are invalid.");
  }

  atlas_file.close();
  std::filesystem::remove_all(empty_storage, error);

  return 0;
}
