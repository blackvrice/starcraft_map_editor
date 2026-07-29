#pragma once

#include <array>
#include <cstdint>
#include <filesystem>
#include <string>
#include <string_view>
#include <vector>

namespace starcraft_map_editor::starcraft_data {

inline constexpr std::size_t kRequiredAssetCount = 40;
inline constexpr std::uint64_t kMaximumAssetBytes = 64ULL * 1024ULL * 1024ULL;
inline constexpr std::uint64_t kMaximumTotalAssetBytes =
    256ULL * 1024ULL * 1024ULL;

struct InvalidAsset {
  std::string path;
  std::uint32_t native_error = 0;
};

struct InspectionResult {
  bool success = false;
  std::string installation_path;
  std::string storage_product;
  std::uint32_t storage_build_number = 0;
  std::uint32_t found_asset_count = 0;
  std::uint64_t total_asset_bytes = 0;
  std::vector<std::string> missing_paths;
  std::vector<InvalidAsset> invalid_assets;
  std::string error_code;
  std::string message;
  std::string stage;
  std::uint32_t native_error = 0;
};

const std::array<std::string_view, kRequiredAssetCount>& RequiredAssetPaths();

InspectionResult InspectInstallation(
    const std::filesystem::path& installation_path);

}  // namespace starcraft_map_editor::starcraft_data
