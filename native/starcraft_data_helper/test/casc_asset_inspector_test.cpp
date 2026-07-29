#include "casc_asset_inspector.h"

#include <Windows.h>

#include <algorithm>
#include <filesystem>
#include <iostream>
#include <set>
#include <string>

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
  std::filesystem::remove_all(empty_storage, error);
  if (result.success) {
    return Fail("An empty directory was accepted as StarCraft CASC storage.");
  }
  if (result.error_code != "SC_CASC_STORAGE_OPEN_FAILED") {
    return Fail("Unexpected diagnostic for an empty CASC directory.");
  }

  return 0;
}
