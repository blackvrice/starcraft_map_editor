#pragma once

#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <string>
#include <vector>

namespace starcraft_map_editor::archive {

inline constexpr char kScenarioArchivePath[] = "staredit\\scenario.chk";
inline constexpr std::size_t kMaximumListedArchiveEntries = 1024;

struct ArchiveEntryMetadata {
  std::string path;
  std::uint32_t uncompressed_size_bytes = 0;
  std::uint32_t compressed_size_bytes = 0;
  std::uint32_t flags = 0;
  std::uint32_t locale = 0;
  bool name_is_synthetic = false;
};

struct ArchiveMetadata {
  std::uint64_t archive_size_bytes = 0;
  std::uint32_t format_version = 0;
  std::uint32_t total_entry_count = 0;
  std::vector<ArchiveEntryMetadata> entries;
  bool listing_complete = false;
  std::uint32_t listing_native_error = 0;
};

struct ScenarioMetadata {
  std::uint32_t uncompressed_size_bytes = 0;
  std::uint32_t compressed_size_bytes = 0;
  std::uint32_t locale = 0;
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

struct ReplaceResult {
  bool success = false;
  std::uint64_t archive_size_bytes = 0;
  std::uint64_t scenario_size_bytes = 0;
  std::string error_code;
  std::string message;
  std::string stage;
  std::uint32_t native_error = 0;
};

ExtractResult ExtractScenario(
    const std::filesystem::path& source_archive_path,
    const std::filesystem::path& scenario_output_path);

ReplaceResult ReplaceScenario(
    const std::filesystem::path& source_archive_path,
    const std::filesystem::path& scenario_input_path,
    const std::filesystem::path& archive_output_path);

}  // namespace starcraft_map_editor::archive
