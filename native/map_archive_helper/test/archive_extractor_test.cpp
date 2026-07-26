#include "archive_extractor.h"

#include <Windows.h>

#include <StormLib.h>

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

bool CreateArchive(
    const std::filesystem::path& archive_path,
    const std::filesystem::path* const scenario_path) {
  HANDLE raw_archive = nullptr;
  if (!SFileCreateArchive(
          archive_path.c_str(),
          MPQ_CREATE_ARCHIVE_V1,
          4,
          &raw_archive)) {
    return false;
  }
  const ArchiveHandle archive(raw_archive);

  if (scenario_path == nullptr) {
    return true;
  }

  return SFileAddFileEx(
      archive.get(),
      scenario_path->c_str(),
      kScenarioArchivePath,
      MPQ_FILE_COMPRESS,
      MPQ_COMPRESSION_ZLIB,
      MPQ_COMPRESSION_ZLIB);
}

std::vector<std::uint8_t> ReadBytes(
    const std::filesystem::path& path) {
  std::ifstream stream(path, std::ios::binary);
  return {
      std::istreambuf_iterator<char>(stream),
      std::istreambuf_iterator<char>()};
}

std::vector<std::uint8_t> ScenarioBytes() {
  return {'V', 'E', 'R', ' ', 2, 0, 0, 0, 59, 0};
}

bool CreateIntegrationFixture(
    const std::filesystem::path& archive_path,
    const std::filesystem::path& scenario_path) {
  const auto scenario_bytes = ScenarioBytes();
  return WriteBytes(scenario_path, scenario_bytes) &&
         CreateArchive(archive_path, &scenario_path);
}

bool TestExtractsScenarioWithoutChangingSource() {
  const TemporaryDirectory temporary;
  const auto archive_path = temporary.path() / L"입력 맵.scx";
  const auto scenario_path = temporary.path() / L"scenario.chk";
  const auto output_path = temporary.path() / L"extracted.chk";
  const auto scenario_bytes = ScenarioBytes();

  if (!Check(
          WriteBytes(scenario_path, scenario_bytes),
          "write scenario fixture") ||
      !Check(
          CreateArchive(archive_path, &scenario_path),
          "create MPQ fixture")) {
    return false;
  }

  const auto source_bytes_before = ReadBytes(archive_path);
  const auto result = ExtractScenario(archive_path, output_path);
  const auto source_bytes_after = ReadBytes(archive_path);

  return Check(!source_bytes_before.empty(), "reads source archive bytes") &&
         Check(result.success, "extract succeeds") &&
         Check(
             result.archive.total_entry_count >= 1,
             "reports a nonzero archive entry count") &&
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
      TestReportsMissingScenarioWithoutOutput,
      TestRefusesExistingOutput,
  };

  for (const auto test : tests) {
    if (!test()) {
      return 1;
    }
  }

  std::cout << "map_archive_helper native tests passed\n";
  return 0;
}
