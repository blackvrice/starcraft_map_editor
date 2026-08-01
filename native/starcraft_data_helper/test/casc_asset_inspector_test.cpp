#include "casc_asset_inspector.h"
#include "tile_atlas_protocol.h"
#include "tileset_asset_reader.h"

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

  atlas_file.close();
  std::filesystem::remove_all(empty_storage, error);

  return 0;
}
