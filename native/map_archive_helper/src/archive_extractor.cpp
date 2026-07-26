#include "archive_extractor.h"

#include <Windows.h>

#include <StormLib.h>

#include <filesystem>
#include <utility>

namespace starcraft_map_editor::archive {
namespace {

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

class FileHandle final {
 public:
  explicit FileHandle(HANDLE handle) : handle_(handle) {}
  ~FileHandle() {
    if (handle_ != nullptr) {
      SFileCloseFile(handle_);
    }
  }

  FileHandle(const FileHandle&) = delete;
  FileHandle& operator=(const FileHandle&) = delete;

  HANDLE get() const { return handle_; }

 private:
  HANDLE handle_ = nullptr;
};

ExtractResult Failure(
    std::string code,
    std::string message,
    std::string stage,
    const DWORD native_error) {
  ExtractResult result;
  result.error_code = std::move(code);
  result.message = std::move(message);
  result.stage = std::move(stage);
  result.native_error = native_error;
  return result;
}

template <typename T>
bool ReadInfo(
    const HANDLE handle,
    const SFileInfoClass info_class,
    T* const output) {
  return SFileGetFileInfo(
      handle,
      info_class,
      output,
      static_cast<DWORD>(sizeof(T)),
      nullptr);
}

void RemovePartialOutput(const std::filesystem::path& output_path) {
  std::error_code error;
  std::filesystem::remove(output_path, error);
}

}  // namespace

ExtractResult ExtractScenario(
    const std::filesystem::path& source_archive_path,
    const std::filesystem::path& scenario_output_path) {
  if (!source_archive_path.is_absolute() ||
      !scenario_output_path.is_absolute()) {
    return Failure(
        "ARCHIVE_PATH_NOT_ABSOLUTE",
        "Source and output paths must be absolute.",
        "validate",
        ERROR_INVALID_PARAMETER);
  }

  std::error_code file_error;
  if (std::filesystem::exists(scenario_output_path, file_error)) {
    return Failure(
        "ARCHIVE_OUTPUT_ALREADY_EXISTS",
        "The scenario output path already exists.",
        "validate",
        ERROR_FILE_EXISTS);
  }
  if (file_error) {
    return Failure(
        "ARCHIVE_OUTPUT_PATH_CHECK_FAILED",
        "The scenario output path could not be checked.",
        "validate",
        static_cast<DWORD>(file_error.value()));
  }

  HANDLE raw_archive = nullptr;
  if (!SFileOpenArchive(
          source_archive_path.c_str(),
          0,
          MPQ_OPEN_READ_ONLY,
          &raw_archive)) {
    return Failure(
        "ARCHIVE_OPEN_FAILED",
        "The MPQ archive could not be opened in read-only mode.",
        "open",
        GetLastError());
  }
  const ArchiveHandle archive(raw_archive);

  HANDLE raw_file = nullptr;
  if (!SFileOpenFileEx(
          archive.get(),
          kScenarioArchivePath,
          SFILE_OPEN_FROM_MPQ,
          &raw_file)) {
    const DWORD native_error = GetLastError();
    const std::string code =
        native_error == ERROR_FILE_NOT_FOUND
            ? "ARCHIVE_SCENARIO_NOT_FOUND"
            : "ARCHIVE_SCENARIO_OPEN_FAILED";
    return Failure(
        code,
        "The archive does not contain a readable scenario.chk entry.",
        "extract",
        native_error);
  }
  const FileHandle scenario_file(raw_file);

  ULONGLONG archive_size = 0;
  DWORD total_entry_count = 0;
  DWORD uncompressed_size = 0;
  DWORD compressed_size = 0;
  if (!ReadInfo(
          archive.get(),
          SFileMpqArchiveSize64,
          &archive_size) ||
      !ReadInfo(
          archive.get(),
          SFileMpqNumberOfFiles,
          &total_entry_count) ||
      !ReadInfo(
          scenario_file.get(),
          SFileInfoFileSize,
          &uncompressed_size) ||
      !ReadInfo(
          scenario_file.get(),
          SFileInfoCompressedSize,
          &compressed_size)) {
    return Failure(
        "ARCHIVE_METADATA_READ_FAILED",
        "Archive metadata could not be read.",
        "inspect",
        GetLastError());
  }

  if (!SFileExtractFile(
          archive.get(),
          kScenarioArchivePath,
          scenario_output_path.c_str(),
          SFILE_OPEN_FROM_MPQ)) {
    const DWORD native_error = GetLastError();
    RemovePartialOutput(scenario_output_path);
    return Failure(
        "ARCHIVE_SCENARIO_EXTRACT_FAILED",
        "scenario.chk could not be extracted.",
        "extract",
        native_error);
  }

  const auto extracted_size =
      std::filesystem::file_size(scenario_output_path, file_error);
  if (file_error ||
      extracted_size != static_cast<std::uintmax_t>(uncompressed_size)) {
    const DWORD native_error =
        file_error ? static_cast<DWORD>(file_error.value()) : ERROR_BAD_LENGTH;
    RemovePartialOutput(scenario_output_path);
    return Failure(
        "ARCHIVE_SCENARIO_SIZE_MISMATCH",
        "The extracted scenario.chk size does not match the archive metadata.",
        "verify",
        native_error);
  }

  ExtractResult result;
  result.success = true;
  result.archive.archive_size_bytes = archive_size;
  result.archive.total_entry_count = total_entry_count;
  result.scenario.uncompressed_size_bytes = uncompressed_size;
  result.scenario.compressed_size_bytes = compressed_size;
  return result;
}

}  // namespace starcraft_map_editor::archive
