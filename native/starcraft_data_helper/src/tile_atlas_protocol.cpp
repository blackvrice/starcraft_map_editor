#include "tile_atlas_protocol.h"

#include <Windows.h>

#include <algorithm>
#include <array>
#include <cstddef>
#include <filesystem>
#include <limits>
#include <utility>
#include <vector>

namespace starcraft_map_editor::starcraft_data {
namespace {

constexpr std::size_t kHeaderBytes = 32;
constexpr std::array<std::uint8_t, 8> kMagic = {
    'S', 'C', 'T', 'R', 'G', 'B', 'A', 0};
constexpr std::size_t kEntryBytes = 4;
constexpr std::size_t kRgbaBytesPerTile = kTileSize * kTileSize * 4;
constexpr std::uint16_t kMaximumColumns = 64;

class WindowsFileHandle final {
 public:
  explicit WindowsFileHandle(HANDLE handle) : handle_(handle) {}
  ~WindowsFileHandle() {
    if (handle_ != INVALID_HANDLE_VALUE) {
      CloseHandle(handle_);
    }
  }

  WindowsFileHandle(const WindowsFileHandle&) = delete;
  WindowsFileHandle& operator=(const WindowsFileHandle&) = delete;

  HANDLE get() const { return handle_; }

 private:
  HANDLE handle_ = INVALID_HANDLE_VALUE;
};

AtlasWriteResult Failure(
    std::string code,
    std::string message,
    std::string stage,
    const std::uint32_t native_error) {
  AtlasWriteResult result;
  result.error_code = std::move(code);
  result.message = std::move(message);
  result.stage = std::move(stage);
  result.native_error = native_error;
  return result;
}

void PutUint16(
    std::array<std::byte, kHeaderBytes>* const header,
    const std::size_t offset,
    const std::uint16_t value) {
  (*header)[offset] = static_cast<std::byte>(value & 0xFFU);
  (*header)[offset + 1] = static_cast<std::byte>((value >> 8U) & 0xFFU);
}

void PutUint32(
    std::array<std::byte, kHeaderBytes>* const header,
    const std::size_t offset,
    const std::uint32_t value) {
  for (std::size_t index = 0; index < 4; ++index) {
    (*header)[offset + index] =
        static_cast<std::byte>((value >> (index * 8U)) & 0xFFU);
  }
}

bool WriteExact(
    const HANDLE file,
    const std::byte* bytes,
    const std::size_t size,
    std::uint32_t* const error) {
  std::size_t offset = 0;
  while (offset < size) {
    const auto remaining = size - offset;
    const auto requested = static_cast<DWORD>(std::min<std::size_t>(
        remaining, static_cast<std::size_t>(1024 * 1024)));
    DWORD written = 0;
    if (!WriteFile(file, bytes + offset, requested, &written, nullptr)) {
      *error = GetLastError();
      return false;
    }
    if (written == 0 || written > requested) {
      *error = ERROR_WRITE_FAULT;
      return false;
    }
    offset += written;
  }
  return true;
}

bool ValidateRenderedValues(const std::vector<std::uint16_t>& raw_values) {
  std::uint16_t previous = 0;
  bool has_previous = false;
  for (const auto value : raw_values) {
    if (value >= 0x4000U || (has_previous && value <= previous)) {
      return false;
    }
    previous = value;
    has_previous = true;
  }
  return raw_values.size() <= kMaximumRawValues;
}

}  // namespace

bool ValidateRawValues(const std::vector<std::uint32_t>& raw_values) {
  if (raw_values.empty() || raw_values.size() > kMaximumRawValues) {
    return false;
  }
  std::uint32_t previous = 0;
  bool has_previous = false;
  for (const auto value : raw_values) {
    if (value > 0xFFFFU || (has_previous && value <= previous)) {
      return false;
    }
    previous = value;
    has_previous = true;
  }
  return true;
}

AtlasWriteResult WriteEmptyTileAtlas(
    const std::filesystem::path& working_directory) {
  return WriteTileAtlas(working_directory, {}, {});
}

AtlasWriteResult WriteTileAtlas(
    const std::filesystem::path& working_directory,
    const std::vector<std::uint16_t>& raw_values,
    const std::vector<std::byte>& rgba_bytes) {
  if (!ValidateRenderedValues(raw_values) ||
      rgba_bytes.size() != raw_values.size() * kRgbaBytesPerTile) {
    return Failure(
        "SC_CASC_TILE_ATLAS_OUTPUT_INVALID",
        "The decoded tile atlas payload is inconsistent.",
        "write-atlas",
        ERROR_INVALID_DATA);
  }

  const auto tile_count = static_cast<std::uint32_t>(raw_values.size());
  const auto columns = raw_values.empty()
                           ? std::uint16_t{0}
                           : static_cast<std::uint16_t>(std::min<std::size_t>(
                                 raw_values.size(), kMaximumColumns));
  const auto rows = raw_values.empty()
                        ? std::uint16_t{0}
                        : static_cast<std::uint16_t>(
                              (raw_values.size() + columns - 1) / columns);
  const auto entry_bytes = raw_values.size() * kEntryBytes;
  const auto pixel_bytes =
      static_cast<std::size_t>(columns) * rows * kRgbaBytesPerTile;
  const auto file_bytes = kHeaderBytes + entry_bytes + pixel_bytes;
  if (entry_bytes > std::numeric_limits<std::uint32_t>::max() ||
      pixel_bytes > std::numeric_limits<std::uint32_t>::max() ||
      file_bytes > kMaximumAtlasFileBytes) {
    return Failure(
        "SC_CASC_TILE_ATLAS_OUTPUT_INVALID",
        "The decoded tile atlas exceeds the byte limit.",
        "write-atlas",
        ERROR_FILE_TOO_LARGE);
  }

  const auto attributes = GetFileAttributesW(working_directory.c_str());
  if (attributes == INVALID_FILE_ATTRIBUTES ||
      (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0 ||
      (attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0) {
    return Failure(
        "SC_CASC_TILE_ATLAS_OUTPUT_CREATE_FAILED",
        "The tile atlas working directory is not safe.",
        "write-atlas",
        attributes == INVALID_FILE_ATTRIBUTES ? GetLastError()
                                              : ERROR_REPARSE_TAG_INVALID);
  }

  const auto output_path = working_directory / kTileAtlasFileName;
  const auto partial_path = working_directory / "tile-atlas.rgba.partial";
  std::error_code filesystem_error;
  const auto output_exists =
      std::filesystem::exists(output_path, filesystem_error);
  if (filesystem_error) {
    return Failure(
        "SC_CASC_TILE_ATLAS_OUTPUT_CREATE_FAILED",
        "The tile atlas output path could not be inspected.",
        "write-atlas",
        static_cast<std::uint32_t>(filesystem_error.value()));
  }
  const auto partial_exists =
      std::filesystem::exists(partial_path, filesystem_error);
  if (filesystem_error) {
    return Failure(
        "SC_CASC_TILE_ATLAS_OUTPUT_CREATE_FAILED",
        "The temporary tile atlas path could not be inspected.",
        "write-atlas",
        static_cast<std::uint32_t>(filesystem_error.value()));
  }
  if (output_exists || partial_exists) {
    return Failure(
        "SC_CASC_TILE_ATLAS_OUTPUT_EXISTS",
        "The tile atlas output already exists.",
        "write-atlas",
        ERROR_FILE_EXISTS);
  }
  const auto raw_handle = CreateFileW(
      partial_path.c_str(),
      GENERIC_WRITE,
      0,
      nullptr,
      CREATE_NEW,
      FILE_ATTRIBUTE_TEMPORARY | FILE_FLAG_WRITE_THROUGH,
      nullptr);
  if (raw_handle == INVALID_HANDLE_VALUE) {
    return Failure(
        "SC_CASC_TILE_ATLAS_OUTPUT_CREATE_FAILED",
        "The temporary tile atlas could not be created.",
        "write-atlas",
        GetLastError());
  }

  std::uint32_t write_error = ERROR_SUCCESS;
  {
    WindowsFileHandle file(raw_handle);
    std::array<std::byte, kHeaderBytes> header{};
    for (std::size_t index = 0; index < kMagic.size(); ++index) {
      header[index] = static_cast<std::byte>(kMagic[index]);
    }
    PutUint16(&header, 8, kTileAtlasFormatVersion);
    PutUint16(&header, 10, kTileSize);
    PutUint16(&header, 12, columns);
    PutUint16(&header, 14, rows);
    PutUint32(&header, 16, tile_count);
    PutUint32(&header, 20, static_cast<std::uint32_t>(entry_bytes));
    PutUint32(&header, 24, static_cast<std::uint32_t>(pixel_bytes));
    PutUint32(&header, 28, 0);

    std::vector<std::byte> entries(entry_bytes);
    for (std::size_t index = 0; index < raw_values.size(); ++index) {
      const auto value = raw_values[index];
      entries[index * kEntryBytes] =
          static_cast<std::byte>(value & 0xFFU);
      entries[index * kEntryBytes + 1] =
          static_cast<std::byte>((value >> 8U) & 0xFFU);
    }
    const std::vector<std::byte> padding(pixel_bytes - rgba_bytes.size());
    if (!WriteExact(file.get(), header.data(), header.size(), &write_error) ||
        !WriteExact(file.get(), entries.data(), entries.size(), &write_error) ||
        !WriteExact(
            file.get(), rgba_bytes.data(), rgba_bytes.size(), &write_error) ||
        !WriteExact(file.get(), padding.data(), padding.size(), &write_error)) {
      // WriteExact records the native error.
    } else if (!FlushFileBuffers(file.get())) {
      write_error = GetLastError();
    }
  }
  if (write_error != ERROR_SUCCESS) {
    std::filesystem::remove(partial_path, filesystem_error);
    return Failure(
        "SC_CASC_TILE_ATLAS_OUTPUT_WRITE_FAILED",
        "The temporary tile atlas could not be written completely.",
        "write-atlas",
        write_error);
  }

  if (!MoveFileExW(
          partial_path.c_str(),
          output_path.c_str(),
          MOVEFILE_WRITE_THROUGH)) {
    const auto native_error = GetLastError();
    std::filesystem::remove(partial_path, filesystem_error);
    return Failure(
        "SC_CASC_TILE_ATLAS_OUTPUT_PROMOTE_FAILED",
        "The completed tile atlas could not be promoted.",
        "write-atlas",
        native_error);
  }

  AtlasWriteResult result;
  result.success = true;
  result.file_bytes = file_bytes;
  result.columns = columns;
  result.rows = rows;
  result.tile_count = tile_count;
  return result;
}

}  // namespace starcraft_map_editor::starcraft_data
