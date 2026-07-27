#include "archive_extractor.h"

#include <Windows.h>

#include <StormLib.h>

#include <iomanip>
#include <filesystem>
#include <sstream>
#include <string_view>
#include <unordered_set>
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

  bool Close() {
    if (handle_ == nullptr) {
      return true;
    }
    const HANDLE handle = std::exchange(handle_, nullptr);
    return SFileCloseArchive(handle);
  }

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
  FileHandle(FileHandle&& other) noexcept
      : handle_(std::exchange(other.handle_, nullptr)) {}
  FileHandle& operator=(FileHandle&& other) noexcept {
    if (this != &other) {
      if (handle_ != nullptr) {
        SFileCloseFile(handle_);
      }
      handle_ = std::exchange(other.handle_, nullptr);
    }
    return *this;
  }

  HANDLE get() const { return handle_; }

 private:
  HANDLE handle_ = nullptr;
};

class LocaleScope final {
 public:
  explicit LocaleScope(const LCID locale)
      : previous_locale_(SFileSetLocale(locale)) {}
  ~LocaleScope() { SFileSetLocale(previous_locale_); }

  LocaleScope(const LocaleScope&) = delete;
  LocaleScope& operator=(const LocaleScope&) = delete;

  void Set(const LCID locale) const { SFileSetLocale(locale); }

 private:
  LCID previous_locale_;
};

class SearchHandle final {
 public:
  explicit SearchHandle(HANDLE handle) : handle_(handle) {}
  ~SearchHandle() {
    if (handle_ != nullptr) {
      SFileFindClose(handle_);
    }
  }

  SearchHandle(const SearchHandle&) = delete;
  SearchHandle& operator=(const SearchHandle&) = delete;

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

ReplaceResult ReplaceFailure(
    std::string code,
    std::string message,
    std::string stage,
    const DWORD native_error) {
  ReplaceResult result;
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

bool IsSyntheticName(
    const std::string_view path,
    const std::uint32_t block_index) {
  std::ostringstream prefix;
  prefix << "File"
         << std::setfill('0')
         << std::setw(8)
         << block_index
         << '.';
  return path.rfind(prefix.str(), 0) == 0;
}

void AppendEntry(
    ArchiveMetadata* const archive,
    const SFILE_FIND_DATA& find_data) {
  const std::string path(find_data.cFileName);
  archive->entries.push_back({
      path,
      find_data.dwFileSize,
      find_data.dwCompSize,
      find_data.dwFileFlags,
      static_cast<std::uint32_t>(find_data.lcLocale),
      IsSyntheticName(path, find_data.dwBlockIndex),
  });
}

bool EqualsAsciiCaseInsensitive(
    const std::string_view left,
    const std::string_view right) {
  if (left.size() != right.size()) {
    return false;
  }
  for (std::size_t index = 0; index < left.size(); ++index) {
    auto left_character = static_cast<unsigned char>(left[index]);
    auto right_character = static_cast<unsigned char>(right[index]);
    if (left_character >= 'A' && left_character <= 'Z') {
      left_character =
          static_cast<unsigned char>(left_character - 'A' + 'a');
    }
    if (right_character >= 'A' && right_character <= 'Z') {
      right_character =
          static_cast<unsigned char>(right_character - 'A' + 'a');
    }
    if (left_character != right_character) {
      return false;
    }
  }
  return true;
}

void EnsureScenarioEntry(
    const HANDLE scenario_handle,
    const std::uint32_t uncompressed_size_bytes,
    const std::uint32_t compressed_size_bytes,
    const std::uint32_t locale,
    ArchiveMetadata* const archive) {
  for (const auto& entry : archive->entries) {
    if (EqualsAsciiCaseInsensitive(entry.path, kScenarioArchivePath) &&
        entry.uncompressed_size_bytes == uncompressed_size_bytes &&
        entry.compressed_size_bytes == compressed_size_bytes &&
        entry.locale == locale) {
      return;
    }
  }

  DWORD flags = 0;
  if (!ReadInfo(scenario_handle, SFileInfoFlags, &flags) &&
      archive->listing_native_error == 0) {
    archive->listing_native_error = GetLastError();
  }
  for (auto& entry : archive->entries) {
    if (entry.name_is_synthetic &&
        entry.uncompressed_size_bytes == uncompressed_size_bytes &&
        entry.compressed_size_bytes == compressed_size_bytes &&
        entry.locale == locale) {
      entry.path = kScenarioArchivePath;
      entry.flags = flags;
      entry.name_is_synthetic = false;
      return;
    }
  }
  if (archive->entries.size() >= kMaximumListedArchiveEntries) {
    archive->entries.pop_back();
  }
  archive->entries.push_back({
      kScenarioArchivePath,
      uncompressed_size_bytes,
      compressed_size_bytes,
      flags,
      locale,
      false,
  });
}

void FinalizeArchiveListing(ArchiveMetadata* const archive) {
  if (archive->listing_native_error != 0) {
    return;
  }
  if (archive->entries.size() != archive->total_entry_count) {
    archive->listing_native_error = ERROR_PARTIAL_COPY;
    return;
  }
  archive->listing_complete = true;
}

void ListArchiveEntries(
    const HANDLE archive_handle,
    const HANDLE scenario_handle,
    const std::uint32_t scenario_uncompressed_size_bytes,
    const std::uint32_t scenario_compressed_size_bytes,
    const std::uint32_t scenario_locale,
    ArchiveMetadata* const archive) {
  SFILE_FIND_DATA find_data{};
  HANDLE raw_search = SFileFindFirstFile(
      archive_handle,
      "*",
      &find_data,
      nullptr);
  if (raw_search == nullptr) {
    const DWORD native_error = GetLastError();
    if (native_error != ERROR_NO_MORE_FILES) {
      archive->listing_native_error = native_error;
    }
    EnsureScenarioEntry(
        scenario_handle,
        scenario_uncompressed_size_bytes,
        scenario_compressed_size_bytes,
        scenario_locale,
        archive);
    FinalizeArchiveListing(archive);
    return;
  }
  const SearchHandle search(raw_search);

  std::unordered_set<std::uint32_t> listed_block_indices;
  while (true) {
    if (listed_block_indices.insert(find_data.dwBlockIndex).second) {
      AppendEntry(archive, find_data);
    }

    if (archive->entries.size() >= kMaximumListedArchiveEntries &&
        archive->total_entry_count > kMaximumListedArchiveEntries) {
      archive->listing_native_error = ERROR_MORE_DATA;
      break;
    }
    if (!SFileFindNextFile(search.get(), &find_data)) {
      const DWORD native_error = GetLastError();
      if (native_error != ERROR_NO_MORE_FILES) {
        archive->listing_native_error = native_error;
      }
      break;
    }
  }

  EnsureScenarioEntry(
      scenario_handle,
      scenario_uncompressed_size_bytes,
      scenario_compressed_size_bytes,
      scenario_locale,
      archive);
  FinalizeArchiveListing(archive);
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
  const LocaleScope locale_scope(0);

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
  FileHandle scenario_file(raw_file);

  DWORD uncompressed_size = 0;
  DWORD compressed_size = 0;
  DWORD scenario_locale = 0;
  if (!ReadInfo(
          scenario_file.get(),
          SFileInfoFileSize,
          &uncompressed_size) ||
      !ReadInfo(
          scenario_file.get(),
          SFileInfoCompressedSize,
          &compressed_size) ||
      !ReadInfo(
          scenario_file.get(),
          SFileInfoLocale,
          &scenario_locale)) {
    return Failure(
        "ARCHIVE_METADATA_READ_FAILED",
        "Archive metadata could not be read.",
        "inspect",
        GetLastError());
  }

  constexpr DWORD kEuddraftPlaceholderMaximumBytes = 1200;
  constexpr LCID kEuddraftScenarioLocale = 0x0409;
  if (uncompressed_size <= kEuddraftPlaceholderMaximumBytes) {
    locale_scope.Set(kEuddraftScenarioLocale);
    HANDLE raw_localized_file = nullptr;
    if (SFileOpenFileEx(
            archive.get(),
            kScenarioArchivePath,
            SFILE_OPEN_FROM_MPQ,
            &raw_localized_file)) {
      FileHandle localized_file(raw_localized_file);
      DWORD localized_locale = 0;
      DWORD localized_uncompressed_size = 0;
      DWORD localized_compressed_size = 0;
      if (!ReadInfo(
              localized_file.get(),
              SFileInfoLocale,
              &localized_locale) ||
          !ReadInfo(
              localized_file.get(),
              SFileInfoFileSize,
              &localized_uncompressed_size) ||
          !ReadInfo(
              localized_file.get(),
              SFileInfoCompressedSize,
              &localized_compressed_size)) {
        return Failure(
            "ARCHIVE_METADATA_READ_FAILED",
            "Localized scenario.chk metadata could not be read.",
            "inspect",
            GetLastError());
      }
      if (localized_locale == kEuddraftScenarioLocale) {
        scenario_file = std::move(localized_file);
        uncompressed_size = localized_uncompressed_size;
        compressed_size = localized_compressed_size;
        scenario_locale = localized_locale;
      } else {
        locale_scope.Set(0);
      }
    } else {
      locale_scope.Set(0);
    }
  }

  ULONGLONG archive_size = 0;
  TMPQHeader archive_header{};
  DWORD total_entry_count = 0;
  if (!ReadInfo(
          archive.get(),
          SFileMpqArchiveSize64,
          &archive_size) ||
      !ReadInfo(
          archive.get(),
          SFileMpqHeader,
          &archive_header) ||
      !ReadInfo(
          archive.get(),
          SFileMpqNumberOfFiles,
          &total_entry_count)) {
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
    if (native_error != ERROR_FILE_EXISTS &&
        native_error != ERROR_ALREADY_EXISTS) {
      RemovePartialOutput(scenario_output_path);
    }
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
  result.archive.format_version =
      static_cast<std::uint32_t>(archive_header.wFormatVersion) + 1;
  result.archive.total_entry_count = total_entry_count;
  result.scenario.uncompressed_size_bytes = uncompressed_size;
  result.scenario.compressed_size_bytes = compressed_size;
  result.scenario.locale = scenario_locale;
  ListArchiveEntries(
      archive.get(),
      scenario_file.get(),
      uncompressed_size,
      compressed_size,
      scenario_locale,
      &result.archive);
  return result;
}

ReplaceResult ReplaceScenario(
    const std::filesystem::path& source_archive_path,
    const std::filesystem::path& scenario_input_path,
    const std::filesystem::path& archive_output_path) {
  if (!source_archive_path.is_absolute() ||
      !scenario_input_path.is_absolute() ||
      !archive_output_path.is_absolute()) {
    return ReplaceFailure(
        "ARCHIVE_PATH_NOT_ABSOLUTE",
        "Source, scenario input, and output paths must be absolute.",
        "validate",
        ERROR_INVALID_PARAMETER);
  }

  std::error_code file_error;
  const auto canonical_source =
      std::filesystem::weakly_canonical(source_archive_path, file_error);
  if (file_error) {
    return ReplaceFailure(
        "ARCHIVE_SOURCE_PATH_CHECK_FAILED",
        "The source archive path could not be resolved.",
        "validate",
        static_cast<DWORD>(file_error.value()));
  }
  const auto canonical_output =
      std::filesystem::weakly_canonical(archive_output_path, file_error);
  if (file_error) {
    return ReplaceFailure(
        "ARCHIVE_OUTPUT_PATH_CHECK_FAILED",
        "The archive output path could not be resolved.",
        "validate",
        static_cast<DWORD>(file_error.value()));
  }
  if (_wcsicmp(
          canonical_source.c_str(),
          canonical_output.c_str()) == 0) {
    return ReplaceFailure(
        "ARCHIVE_SOURCE_OUTPUT_SAME",
        "The source and temporary output paths must differ.",
        "validate",
        ERROR_INVALID_PARAMETER);
  }

  if (std::filesystem::exists(archive_output_path, file_error)) {
    return ReplaceFailure(
        "ARCHIVE_OUTPUT_ALREADY_EXISTS",
        "The temporary archive output path already exists.",
        "validate",
        ERROR_FILE_EXISTS);
  }
  if (file_error) {
    return ReplaceFailure(
        "ARCHIVE_OUTPUT_PATH_CHECK_FAILED",
        "The temporary archive output path could not be checked.",
        "validate",
        static_cast<DWORD>(file_error.value()));
  }

  const auto scenario_size =
      std::filesystem::file_size(scenario_input_path, file_error);
  if (file_error) {
    return ReplaceFailure(
        "ARCHIVE_SCENARIO_INPUT_READ_FAILED",
        "The replacement scenario.chk input could not be read.",
        "validate",
        static_cast<DWORD>(file_error.value()));
  }
  if (scenario_size > 0xffffffffULL) {
    return ReplaceFailure(
        "ARCHIVE_SCENARIO_INPUT_TOO_LARGE",
        "The replacement scenario.chk exceeds the MPQ file size limit.",
        "validate",
        ERROR_FILE_TOO_LARGE);
  }

  if (!std::filesystem::copy_file(
          source_archive_path,
          archive_output_path,
          std::filesystem::copy_options::none,
          file_error)) {
    const DWORD native_error =
        file_error
            ? static_cast<DWORD>(file_error.value())
            : ERROR_WRITE_FAULT;
    if (native_error != ERROR_FILE_EXISTS &&
        native_error != ERROR_ALREADY_EXISTS) {
      RemovePartialOutput(archive_output_path);
    }
    return ReplaceFailure(
        "ARCHIVE_SOURCE_COPY_FAILED",
        "The source archive could not be copied to temporary output.",
        "copy",
        native_error);
  }

  const DWORD output_attributes =
      GetFileAttributesW(archive_output_path.c_str());
  if (output_attributes == INVALID_FILE_ATTRIBUTES ||
      ((output_attributes & FILE_ATTRIBUTE_READONLY) != 0 &&
       !SetFileAttributesW(
           archive_output_path.c_str(),
           output_attributes & ~FILE_ATTRIBUTE_READONLY))) {
    const DWORD native_error = GetLastError();
    RemovePartialOutput(archive_output_path);
    return ReplaceFailure(
        "ARCHIVE_OUTPUT_ATTRIBUTE_UPDATE_FAILED",
        "The temporary archive could not be made writable.",
        "copy",
        native_error);
  }

  HANDLE raw_archive = nullptr;
  if (!SFileOpenArchive(
          archive_output_path.c_str(),
          0,
          0,
          &raw_archive)) {
    const DWORD native_error = GetLastError();
    RemovePartialOutput(archive_output_path);
    return ReplaceFailure(
        "ARCHIVE_OUTPUT_OPEN_FAILED",
        "The temporary archive could not be opened for writing.",
        "open",
        native_error);
  }
  ArchiveHandle archive(raw_archive);

  if (!SFileAddFileEx(
          archive.get(),
          scenario_input_path.c_str(),
          kScenarioArchivePath,
          MPQ_FILE_REPLACEEXISTING | MPQ_FILE_COMPRESS,
          MPQ_COMPRESSION_ZLIB,
          MPQ_COMPRESSION_ZLIB)) {
    const DWORD native_error = GetLastError();
    archive.Close();
    RemovePartialOutput(archive_output_path);
    return ReplaceFailure(
        "ARCHIVE_SCENARIO_REPLACE_FAILED",
        "scenario.chk could not be replaced in the temporary archive.",
        "replace",
        native_error);
  }

  if (!archive.Close()) {
    const DWORD native_error = GetLastError();
    RemovePartialOutput(archive_output_path);
    return ReplaceFailure(
        "ARCHIVE_OUTPUT_CLOSE_FAILED",
        "The temporary archive could not be finalized.",
        "finalize",
        native_error);
  }

  const auto archive_size =
      std::filesystem::file_size(archive_output_path, file_error);
  if (file_error) {
    const DWORD native_error = static_cast<DWORD>(file_error.value());
    RemovePartialOutput(archive_output_path);
    return ReplaceFailure(
        "ARCHIVE_OUTPUT_VERIFY_FAILED",
        "The temporary archive output could not be verified.",
        "verify",
        native_error);
  }

  ReplaceResult result;
  result.success = true;
  result.archive_size_bytes = archive_size;
  result.scenario_size_bytes = scenario_size;
  return result;
}

}  // namespace starcraft_map_editor::archive
