#pragma once

#include <cstdint>
#include <filesystem>
#include <string>

namespace starcraft_map_editor::archive {

inline constexpr char kScenarioArchivePath[] = "staredit\\scenario.chk";

struct ArchiveMetadata {
  std::uint64_t archive_size_bytes = 0;
  std::uint32_t total_entry_count = 0;
};

struct ScenarioMetadata {
  std::uint32_t uncompressed_size_bytes = 0;
  std::uint32_t compressed_size_bytes = 0;
};

struct ExtractResult {
  bool success = false;
  ArchiveMetadata archive;
  ScenarioMetadata scenario;
  std::string error_code;
  std::string message;
  std::string stage;
  std::uint32_t native_error = 0;
};

ExtractResult ExtractScenario(
    const std::filesystem::path& source_archive_path,
    const std::filesystem::path& scenario_output_path);

}  // namespace starcraft_map_editor::archive
