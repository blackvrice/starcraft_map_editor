#include "archive_extractor.h"

#include <Windows.h>

#include <StormLib.h>

#include <algorithm>
#include <array>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <string_view>
#include <vector>

namespace {

using starcraft_map_editor::archive::ExtractScenario;
using starcraft_map_editor::archive::kScenarioArchivePath;
using starcraft_map_editor::archive::ReplaceScenario;

constexpr char kExtraArchivePath[] = "staredit\\units.dat";

class TemporaryDirectory final {
 public:
  TemporaryDirectory() {
    const auto root = std::filesystem::temp_directory_path();
    for (std::uint32_t attempt = 0; attempt < 100; ++attempt) {
      path_ =
          root /
          (L"starcraft_map_editor_맵 추출_" +
           std::to_wstring(GetCurrentProcessId()) +
           L"_" +
           std::to_wstring(attempt));
      std::error_code error;
      if (std::filesystem::create_directory(path_, error)) {
        return;
      }
    }
    throw std::runtime_error("Could not create a temporary test directory.");
  }

  ~TemporaryDirectory() {
    std::error_code error;
    std::filesystem::remove_all(path_, error);
  }

  TemporaryDirectory(const TemporaryDirectory&) = delete;
  TemporaryDirectory& operator=(const TemporaryDirectory&) = delete;

  const std::filesystem::path& path() const { return path_; }

 private:
  std::filesystem::path path_;
};

class ArchiveHandle final {
 public:
  explicit ArchiveHandle(HANDLE handle) : handle_(handle) {}
  ~ArchiveHandle() {
    if (handle_ != nullptr) {
      SFileCloseArchive(handle_);
    }
  }

  ArchiveHandle(const ArchiveHandle&) = delete;
  ArchiveHandle& operator=(const ArchiveHandle&) = delete;

  HANDLE get() const { return handle_; }

 private:
  HANDLE handle_ = nullptr;
};

bool Check(const bool condition, const char* const message) {
  if (!condition) {
    std::cerr << "FAILED: " << message << '\n';
  }
  return condition;
}

bool WriteBytes(
    const std::filesystem::path& path,
    const std::vector<std::uint8_t>& bytes) {
  std::ofstream stream(path, std::ios::binary);
  if (!stream) {
    return false;
  }
  stream.write(
      reinterpret_cast<const char*>(bytes.data()),
      static_cast<std::streamsize>(bytes.size()));
  return stream.good();
}

bool AddArchiveFile(
    const HANDLE archive,
    const std::filesystem::path& source_path,
    const char* const archive_path) {
  const bool added = SFileAddFileEx(
      archive,
      source_path.c_str(),
      archive_path,
      MPQ_FILE_COMPRESS,
      MPQ_COMPRESSION_ZLIB,
      MPQ_COMPRESSION_ZLIB);
  if (!added) {
    std::cerr << "FAILED: add archive entry "
              << archive_path
              << " error="
              << GetLastError()
              << '\n';
  }
  return added;
}

bool CreateArchive(
    const std::filesystem::path& archive_path,
    const std::filesystem::path* const scenario_path,
    const std::filesystem::path* const extra_path = nullptr,
    const bool include_list_file = false) {
  SFILE_CREATE_MPQ create_info{};
  create_info.cbSize = sizeof(create_info);
  create_info.dwMpqVersion = MPQ_FORMAT_VERSION_1;
  create_info.dwStreamFlags =
      STREAM_PROVIDER_FLAT | BASE_PROVIDER_FILE;
  create_info.dwFileFlags1 =
      include_list_file ? MPQ_FILE_DEFAULT_INTERNAL : 0;
  create_info.dwSectorSize = 0x1000;
  create_info.dwMaxFileCount = 8;

  HANDLE raw_archive = nullptr;
  if (!SFileCreateArchive2(
          archive_path.c_str(),
          &create_info,
          &raw_archive)) {
    return false;
  }
  const ArchiveHandle archive(raw_archive);

  if (scenario_path != nullptr &&
      !AddArchiveFile(
          archive.get(),
          *scenario_path,
          kScenarioArchivePath)) {
    return false;
  }
  if (extra_path != nullptr &&
      !AddArchiveFile(archive.get(), *extra_path, kExtraArchivePath)) {
    return false;
  }
  return true;
}

std::vector<std::uint8_t> ReadBytes(
    const std::filesystem::path& path) {
  std::ifstream stream(path, std::ios::binary);
  return {
      std::istreambuf_iterator<char>(stream),
      std::istreambuf_iterator<char>()};
}

std::vector<std::uint8_t> ScenarioBytes() {
  return {
      'T', 'Y', 'P', 'E', 4, 0, 0, 0, 'R', 'A', 'W', 'B',
      'V', 'E', 'R', ' ', 2, 0, 0, 0, 205, 0,
      'I', 'V', 'E', 'R', 2, 0, 0, 0, 10, 0,
      'E', 'R', 'A', ' ', 2, 0, 0, 0, 4, 0,
      'D', 'I', 'M', ' ', 4, 0, 0, 0, 128, 0, 64, 0};
}

bool CreateIntegrationFixture(
    const std::filesystem::path& archive_path,
    const std::filesystem::path& scenario_path) {
  const auto scenario_bytes = ScenarioBytes();
  const auto extra_path = scenario_path.parent_path() / L"units.dat";
  const std::vector<std::uint8_t> extra_bytes{1, 2, 3, 4};
  return WriteBytes(scenario_path, scenario_bytes) &&
         WriteBytes(extra_path, extra_bytes) &&
         CreateArchive(
             archive_path,
             &scenario_path,
             &extra_path,
             true);
}

bool ExtractArchiveFile(
    const std::filesystem::path& archive_path,
    const char* const entry_path,
    const std::filesystem::path& output_path) {
  HANDLE raw_archive = nullptr;
  if (!SFileOpenArchive(
          archive_path.c_str(),
          0,
          MPQ_OPEN_READ_ONLY,
          &raw_archive)) {
    return false;
  }
  const ArchiveHandle archive(raw_archive);
  return SFileExtractFile(
      archive.get(),
      entry_path,
      output_path.c_str(),
      SFILE_OPEN_FROM_MPQ);
}

bool TestExtractsScenarioWithoutChangingSource() {
  const TemporaryDirectory temporary;
  const auto archive_path = temporary.path() / L"입력 맵.scx";
  const auto scenario_path = temporary.path() / L"scenario.chk";
  const auto extra_path = temporary.path() / L"units.dat";
  const auto output_path = temporary.path() / L"extracted.chk";
  const auto scenario_bytes = ScenarioBytes();
  const std::vector<std::uint8_t> extra_bytes{1, 2, 3, 4};

  if (!Check(
          WriteBytes(scenario_path, scenario_bytes),
          "write scenario fixture") ||
      !Check(
          WriteBytes(extra_path, extra_bytes),
          "write extra fixture") ||
      !Check(
          CreateArchive(
              archive_path,
              &scenario_path,
              &extra_path,
              true),
          "create MPQ fixture")) {
    return false;
  }

  const auto source_bytes_before = ReadBytes(archive_path);
  const auto result = ExtractScenario(archive_path, output_path);
  const auto source_bytes_after = ReadBytes(archive_path);

  return Check(!source_bytes_before.empty(), "reads source archive bytes") &&
         Check(result.success, "extract succeeds") &&
         Check(
             result.archive.format_version == 1,
             "reports MPQ format version") &&
         Check(
             result.archive.total_entry_count == 3,
             "reports archive entry count") &&
         Check(
             result.archive.listing_complete,
             "reports complete archive listing") &&
         Check(
             result.archive.listing_native_error == 0,
             "does not report a listing error") &&
         Check(
             result.archive.entries.size() == 3,
             "lists every archive entry") &&
         Check(
             std::any_of(
                 result.archive.entries.begin(),
                 result.archive.entries.end(),
                 [](const auto& entry) {
                   return entry.path == kExtraArchivePath &&
                          entry.uncompressed_size_bytes == 4 &&
                          !entry.name_is_synthetic;
                 }),
             "reports extra entry metadata") &&
         Check(
             result.scenario.uncompressed_size_bytes ==
                 scenario_bytes.size(),
             "reports scenario size") &&
         Check(
             ReadBytes(output_path) == scenario_bytes,
             "preserves scenario bytes") &&
         Check(
             source_bytes_before == source_bytes_after,
             "does not change source archive bytes");
}

bool TestReportsSyntheticNamesWithoutListFile() {
  const TemporaryDirectory temporary;
  const auto archive_path = temporary.path() / L"no-listfile.scx";
  const auto scenario_path = temporary.path() / L"scenario.chk";
  const auto extra_path = temporary.path() / L"units.dat";
  const auto output_path = temporary.path() / L"extracted.chk";
  const auto scenario_bytes = ScenarioBytes();
  const std::vector<std::uint8_t> extra_bytes{1, 2, 3, 4};

  if (!Check(
          WriteBytes(scenario_path, scenario_bytes),
          "write scenario fixture without listfile") ||
      !Check(
          WriteBytes(extra_path, extra_bytes),
          "write extra fixture without listfile") ||
      !Check(
          CreateArchive(archive_path, &scenario_path, &extra_path),
          "create MPQ fixture without listfile")) {
    return false;
  }

  const auto result = ExtractScenario(archive_path, output_path);
  if (std::none_of(
          result.archive.entries.begin(),
          result.archive.entries.end(),
          [](const auto& entry) {
            return entry.name_is_synthetic;
          })) {
    for (const auto& entry : result.archive.entries) {
      std::cerr << "listed entry without listfile: "
                << entry.path
                << '\n';
    }
  }
  return Check(result.success, "extract without listfile succeeds") &&
         Check(
             result.archive.listing_complete,
             "synthetic listing is structurally complete") &&
         Check(
             std::any_of(
                 result.archive.entries.begin(),
                 result.archive.entries.end(),
                 [](const auto& entry) {
                   return entry.name_is_synthetic;
                 }),
             "marks a recovered synthetic name");
}

bool TestReportsMissingScenarioWithoutOutput() {
  const TemporaryDirectory temporary;
  const auto archive_path = temporary.path() / L"empty.scx";
  const auto output_path = temporary.path() / L"missing.chk";

  if (!Check(
          CreateArchive(archive_path, nullptr),
          "create empty MPQ fixture")) {
    return false;
  }

  const auto result = ExtractScenario(archive_path, output_path);
  return Check(!result.success, "missing scenario fails") &&
         Check(
             result.error_code == "ARCHIVE_SCENARIO_NOT_FOUND",
             "uses stable missing scenario code") &&
         Check(
             !std::filesystem::exists(output_path),
             "does not leave an output file");
}

bool TestRefusesExistingOutput() {
  const TemporaryDirectory temporary;
  const auto archive_path = temporary.path() / L"input.scx";
  const auto scenario_path = temporary.path() / L"scenario.chk";
  const auto output_path = temporary.path() / L"existing.chk";
  const auto scenario_bytes = ScenarioBytes();
  const std::vector<std::uint8_t> existing_bytes{1, 2, 3};

  if (!Check(
          WriteBytes(scenario_path, scenario_bytes),
          "write scenario fixture") ||
      !Check(
          WriteBytes(output_path, existing_bytes),
          "write existing output") ||
      !Check(
          CreateArchive(archive_path, &scenario_path),
          "create MPQ fixture")) {
    return false;
  }

  const auto result = ExtractScenario(archive_path, output_path);
  return Check(!result.success, "existing output fails") &&
         Check(
             result.error_code == "ARCHIVE_OUTPUT_ALREADY_EXISTS",
             "uses stable existing output code") &&
         Check(
             ReadBytes(output_path) == existing_bytes,
             "does not overwrite existing output");
}

bool TestReplacesScenarioInCopiedArchive() {
  const TemporaryDirectory temporary;
  const auto archive_path = temporary.path() / L"source.scx";
  const auto original_scenario_path =
      temporary.path() / L"original-scenario.chk";
  const auto replacement_scenario_path =
      temporary.path() / L"replacement-scenario.chk";
  const auto extra_path = temporary.path() / L"units.dat";
  const auto output_path = temporary.path() / L"temporary-output.scx";
  const auto extracted_scenario_path =
      temporary.path() / L"verified-scenario.chk";
  const auto extracted_extra_path =
      temporary.path() / L"verified-units.dat";
  const auto original_scenario_bytes = ScenarioBytes();
  const std::vector<std::uint8_t> replacement_scenario_bytes{
      'V', 'E', 'R', ' ', 2, 0, 0, 0, 205, 0};
  const std::vector<std::uint8_t> extra_bytes{1, 2, 3, 4};

  if (!Check(
          WriteBytes(
              original_scenario_path,
              original_scenario_bytes),
          "write original scenario fixture") ||
      !Check(
          WriteBytes(
              replacement_scenario_path,
              replacement_scenario_bytes),
          "write replacement scenario fixture") ||
      !Check(
          WriteBytes(extra_path, extra_bytes),
          "write preserved extra fixture") ||
      !Check(
          CreateArchive(
              archive_path,
              &original_scenario_path,
              &extra_path,
              true),
          "create replace source archive")) {
    return false;
  }

  const auto source_bytes_before = ReadBytes(archive_path);
  const auto replace_result = ReplaceScenario(
      archive_path,
      replacement_scenario_path,
      output_path);
  const auto source_bytes_after = ReadBytes(archive_path);
  const auto extract_result =
      ExtractScenario(output_path, extracted_scenario_path);
  const auto extra_extracted = ExtractArchiveFile(
      output_path,
      kExtraArchivePath,
      extracted_extra_path);

  return Check(replace_result.success, "replace succeeds") &&
         Check(
             replace_result.scenario_size_bytes ==
                 replacement_scenario_bytes.size(),
             "reports replacement scenario size") &&
         Check(
             replace_result.archive_size_bytes > 0,
             "reports temporary archive size") &&
         Check(
             source_bytes_before == source_bytes_after,
             "replace does not change source archive bytes") &&
         Check(extract_result.success, "reopens temporary archive") &&
         Check(
             ReadBytes(extracted_scenario_path) ==
                 replacement_scenario_bytes,
             "temporary archive contains replacement scenario") &&
         Check(extra_extracted, "extracts preserved extra entry") &&
         Check(
             ReadBytes(extracted_extra_path) == extra_bytes,
             "preserves unrelated archive entries");
}

bool TestReplaceRefusesExistingOutput() {
  const TemporaryDirectory temporary;
  const auto archive_path = temporary.path() / L"source.scx";
  const auto scenario_path = temporary.path() / L"scenario.chk";
  const auto output_path = temporary.path() / L"existing.scx";
  const auto scenario_bytes = ScenarioBytes();
  const std::vector<std::uint8_t> existing_bytes{9, 8, 7};

  if (!Check(
          WriteBytes(scenario_path, scenario_bytes),
          "write replace scenario fixture") ||
      !Check(
          CreateArchive(archive_path, &scenario_path),
          "create replace fixture") ||
      !Check(
          WriteBytes(output_path, existing_bytes),
          "write existing archive output")) {
    return false;
  }

  const auto source_bytes_before = ReadBytes(archive_path);
  const auto result =
      ReplaceScenario(archive_path, scenario_path, output_path);
  return Check(!result.success, "replace existing output fails") &&
         Check(
             result.error_code == "ARCHIVE_OUTPUT_ALREADY_EXISTS",
             "uses stable replace existing output code") &&
         Check(
             ReadBytes(output_path) == existing_bytes,
             "does not overwrite existing archive output") &&
         Check(
             ReadBytes(archive_path) == source_bytes_before,
             "does not change source after refused replace");
}

bool TestReplaceRefusesSourceAsOutput() {
  const TemporaryDirectory temporary;
  const auto archive_path = temporary.path() / L"source.scx";
  const auto scenario_path = temporary.path() / L"scenario.chk";
  const auto scenario_bytes = ScenarioBytes();

  if (!Check(
          WriteBytes(scenario_path, scenario_bytes),
          "write same-path scenario fixture") ||
      !Check(
          CreateArchive(archive_path, &scenario_path),
          "create same-path fixture")) {
    return false;
  }

  const auto source_bytes_before = ReadBytes(archive_path);
  const auto result =
      ReplaceScenario(archive_path, scenario_path, archive_path);
  return Check(!result.success, "source as output fails") &&
         Check(
             result.error_code == "ARCHIVE_SOURCE_OUTPUT_SAME",
             "uses stable same-path code") &&
         Check(
             ReadBytes(archive_path) == source_bytes_before,
             "same-path failure preserves source bytes");
}

}  // namespace

int wmain(const int argument_count, wchar_t* arguments[]) {
  if (argument_count == 4 &&
      std::wstring_view(arguments[1]) == L"--create-fixture") {
    const auto archive_path = std::filesystem::path(arguments[2]);
    const auto scenario_path = std::filesystem::path(arguments[3]);
    if (!CreateIntegrationFixture(archive_path, scenario_path)) {
      std::cerr << "FAILED: create integration fixture\n";
      return 1;
    }
    std::cout << "integration fixture created\n";
    return 0;
  }

  const std::array tests{
      TestExtractsScenarioWithoutChangingSource,
      TestReportsSyntheticNamesWithoutListFile,
      TestReportsMissingScenarioWithoutOutput,
      TestRefusesExistingOutput,
      TestReplacesScenarioInCopiedArchive,
      TestReplaceRefusesExistingOutput,
      TestReplaceRefusesSourceAsOutput,
  };

  for (const auto test : tests) {
    if (!test()) {
      return 1;
    }
  }

  std::cout << "map_archive_helper native tests passed\n";
  return 0;
}
