#include "object_atlas_protocol.h"

#include "object_grp_decoder.h"

#include <Windows.h>

#include <algorithm>
#include <array>
#include <cstddef>
#include <filesystem>
#include <limits>
#include <tuple>
#include <utility>
#include <vector>

namespace starcraft_map_editor::starcraft_data {
namespace {

constexpr std::size_t kObjectAtlasHeaderBytes = 32;
constexpr std::array<std::uint8_t, 8> kObjectAtlasMagic = {'S', 'C', 'O', 'R',
                                                           'G', 'B', 'A', 0};

class WindowsFileHandle final {
public:
  explicit WindowsFileHandle(HANDLE handle) : handle_(handle) {}
  ~WindowsFileHandle() {
    if (handle_ != INVALID_HANDLE_VALUE) {
      CloseHandle(handle_);
    }
  }

  WindowsFileHandle(const WindowsFileHandle &) = delete;
  WindowsFileHandle &operator=(const WindowsFileHandle &) = delete;

  HANDLE get() const { return handle_; }

private:
  HANDLE handle_ = INVALID_HANDLE_VALUE;
};

ObjectAtlasWriteResult Failure(std::string code, std::string message,
                               std::string stage,
                               const std::uint32_t native_error) {
  ObjectAtlasWriteResult result;
  result.error_code = std::move(code);
  result.message = std::move(message);
  result.stage = std::move(stage);
  result.native_error = native_error;
  return result;
}

void PutUint16(std::byte *const bytes, const std::size_t offset,
               const std::uint16_t value) {
  bytes[offset] = static_cast<std::byte>(value & 0xFFU);
  bytes[offset + 1] = static_cast<std::byte>((value >> 8U) & 0xFFU);
}

void PutUint32(std::byte *const bytes, const std::size_t offset,
               const std::uint32_t value) {
  for (std::size_t index = 0; index < 4; ++index) {
    bytes[offset + index] =
        static_cast<std::byte>((value >> (index * 8U)) & 0xFFU);
  }
}

bool WriteExact(const HANDLE file, const std::byte *bytes,
                const std::size_t size, std::uint32_t *const error) {
  std::size_t offset = 0;
  while (offset < size) {
    const auto requested = static_cast<DWORD>(std::min<std::size_t>(
        size - offset, static_cast<std::size_t>(1024 * 1024)));
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

auto EntryKey(const ObjectAtlasEntry &entry) {
  return std::tuple{static_cast<std::uint8_t>(entry.kind), entry.object_id,
                    entry.player_color, entry.direction};
}

bool IsEntryValid(const ObjectAtlasEntry &entry) {
  if ((entry.kind != ObjectGraphicKind::kUnit &&
       entry.kind != ObjectGraphicKind::kSprite) ||
      (entry.player_color > kMaximumObjectPlayerColor &&
       entry.player_color != kNeutralObjectPlayerColor) ||
      entry.direction != kObjectPreviewDirection ||
      entry.frame_index != kObjectPreviewFrameIndex ||
      entry.sprite_id >= kClassicSpriteCount ||
      entry.image_id >= kClassicImageCount || entry.width == 0 ||
      entry.height == 0 || entry.width > kMaximumObjectGrpDimension ||
      entry.height > kMaximumObjectGrpDimension) {
    return false;
  }
  if ((entry.kind == ObjectGraphicKind::kUnit &&
       entry.object_id >= kClassicUnitCount) ||
      (entry.kind == ObjectGraphicKind::kSprite &&
       (entry.object_id >= kClassicSpriteCount ||
        entry.sprite_id != entry.object_id))) {
    return false;
  }

  const auto pixel_count = static_cast<std::size_t>(entry.width) * entry.height;
  return pixel_count <= kMaximumObjectFrameBytes / 4 &&
         entry.rgba_bytes.size() == pixel_count * 4;
}

} // namespace

bool ValidateObjectAtlasEntries(const std::vector<ObjectAtlasEntry> &entries) {
  if (entries.size() > kMaximumObjectAtlasEntries) {
    return false;
  }
  for (std::size_t index = 0; index < entries.size(); ++index) {
    if (!IsEntryValid(entries[index]) ||
        (index > 0 &&
         !(EntryKey(entries[index - 1]) < EntryKey(entries[index])))) {
      return false;
    }
  }
  return true;
}

ObjectAtlasWriteResult
WriteObjectAtlas(const std::filesystem::path &working_directory,
                 const std::vector<ObjectAtlasEntry> &entries) {
  if (!ValidateObjectAtlasEntries(entries)) {
    return Failure("SC_CASC_OBJECT_ATLAS_OUTPUT_INVALID",
                   "The decoded object atlas entries are inconsistent.",
                   "write-object-atlas", ERROR_INVALID_DATA);
  }

  const auto entry_table_bytes =
      entries.size() * static_cast<std::size_t>(kObjectAtlasEntryBytes);
  std::uint64_t pixel_bytes = 0;
  for (const auto &entry : entries) {
    pixel_bytes += entry.rgba_bytes.size();
  }
  const auto file_bytes = static_cast<std::uint64_t>(kObjectAtlasHeaderBytes) +
                          entry_table_bytes + pixel_bytes;
  if (entry_table_bytes > std::numeric_limits<std::uint32_t>::max() ||
      pixel_bytes > std::numeric_limits<std::uint32_t>::max() ||
      file_bytes > kMaximumObjectAtlasFileBytes) {
    return Failure("SC_CASC_OBJECT_ATLAS_OUTPUT_TOO_LARGE",
                   "The decoded object atlas exceeds the byte limit.",
                   "write-object-atlas", ERROR_FILE_TOO_LARGE);
  }

  const auto attributes = GetFileAttributesW(working_directory.c_str());
  if (attributes == INVALID_FILE_ATTRIBUTES ||
      (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0 ||
      (attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0) {
    return Failure(
        "SC_CASC_OBJECT_ATLAS_OUTPUT_CREATE_FAILED",
        "The object atlas working directory is not safe.", "write-object-atlas",
        attributes == INVALID_FILE_ATTRIBUTES ? GetLastError()
                                              : ERROR_REPARSE_TAG_INVALID);
  }

  const auto output_path = working_directory / kObjectAtlasFileName;
  const auto partial_path = working_directory / "object-atlas.rgba.partial";
  std::error_code filesystem_error;
  const auto output_exists =
      std::filesystem::exists(output_path, filesystem_error);
  if (filesystem_error) {
    return Failure("SC_CASC_OBJECT_ATLAS_OUTPUT_CREATE_FAILED",
                   "The object atlas output path could not be inspected.",
                   "write-object-atlas",
                   static_cast<std::uint32_t>(filesystem_error.value()));
  }
  const auto partial_exists =
      std::filesystem::exists(partial_path, filesystem_error);
  if (filesystem_error) {
    return Failure("SC_CASC_OBJECT_ATLAS_OUTPUT_CREATE_FAILED",
                   "The temporary object atlas path could not be inspected.",
                   "write-object-atlas",
                   static_cast<std::uint32_t>(filesystem_error.value()));
  }
  if (output_exists || partial_exists) {
    return Failure("SC_CASC_OBJECT_ATLAS_OUTPUT_EXISTS",
                   "The object atlas output already exists.",
                   "write-object-atlas", ERROR_FILE_EXISTS);
  }

  const auto raw_handle =
      CreateFileW(partial_path.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_NEW,
                  FILE_ATTRIBUTE_TEMPORARY | FILE_FLAG_WRITE_THROUGH, nullptr);
  if (raw_handle == INVALID_HANDLE_VALUE) {
    return Failure("SC_CASC_OBJECT_ATLAS_OUTPUT_CREATE_FAILED",
                   "The temporary object atlas could not be created.",
                   "write-object-atlas", GetLastError());
  }

  std::uint32_t write_error = ERROR_SUCCESS;
  {
    WindowsFileHandle file(raw_handle);
    std::array<std::byte, kObjectAtlasHeaderBytes> header{};
    for (std::size_t index = 0; index < kObjectAtlasMagic.size(); ++index) {
      header[index] = static_cast<std::byte>(kObjectAtlasMagic[index]);
    }
    PutUint16(header.data(), 8, kObjectAtlasFormatVersion);
    PutUint16(header.data(), 10, kObjectAtlasEntryBytes);
    PutUint32(header.data(), 12, static_cast<std::uint32_t>(entries.size()));
    PutUint32(header.data(), 16, static_cast<std::uint32_t>(entry_table_bytes));
    PutUint32(header.data(), 20, static_cast<std::uint32_t>(pixel_bytes));

    std::vector<std::byte> entry_table(entry_table_bytes);
    std::uint32_t pixel_offset = 0;
    for (std::size_t index = 0; index < entries.size(); ++index) {
      const auto &entry = entries[index];
      auto *const encoded = entry_table.data() + index * kObjectAtlasEntryBytes;
      encoded[0] = static_cast<std::byte>(entry.kind);
      encoded[1] = static_cast<std::byte>(entry.player_color);
      encoded[2] = static_cast<std::byte>(entry.direction);
      PutUint16(encoded, 4, entry.object_id);
      PutUint16(encoded, 6, entry.sprite_id);
      PutUint16(encoded, 8, entry.image_id);
      PutUint16(encoded, 10, entry.width);
      PutUint16(encoded, 12, entry.height);
      PutUint16(encoded, 14, static_cast<std::uint16_t>(entry.anchor_x));
      PutUint16(encoded, 16, static_cast<std::uint16_t>(entry.anchor_y));
      PutUint16(encoded, 18, entry.frame_index);
      PutUint32(encoded, 20, pixel_offset);
      PutUint32(encoded, 24,
                static_cast<std::uint32_t>(entry.rgba_bytes.size()));
      pixel_offset += static_cast<std::uint32_t>(entry.rgba_bytes.size());
    }

    if (!WriteExact(file.get(), header.data(), header.size(), &write_error) ||
        !WriteExact(file.get(), entry_table.data(), entry_table.size(),
                    &write_error)) {
      // WriteExact records the native error.
    } else {
      for (const auto &entry : entries) {
        if (!WriteExact(file.get(), entry.rgba_bytes.data(),
                        entry.rgba_bytes.size(), &write_error)) {
          break;
        }
      }
      if (write_error == ERROR_SUCCESS && !FlushFileBuffers(file.get())) {
        write_error = GetLastError();
      }
    }
  }
  if (write_error != ERROR_SUCCESS) {
    std::filesystem::remove(partial_path, filesystem_error);
    return Failure(
        "SC_CASC_OBJECT_ATLAS_OUTPUT_WRITE_FAILED",
        "The temporary object atlas could not be written completely.",
        "write-object-atlas", write_error);
  }

  if (!MoveFileExW(partial_path.c_str(), output_path.c_str(),
                   MOVEFILE_WRITE_THROUGH)) {
    const auto native_error = GetLastError();
    std::filesystem::remove(partial_path, filesystem_error);
    return Failure("SC_CASC_OBJECT_ATLAS_OUTPUT_PROMOTE_FAILED",
                   "The completed object atlas could not be promoted.",
                   "write-object-atlas", native_error);
  }

  ObjectAtlasWriteResult result;
  result.success = true;
  result.file_bytes = file_bytes;
  result.entry_count = static_cast<std::uint32_t>(entries.size());
  result.pixel_bytes = static_cast<std::uint32_t>(pixel_bytes);
  return result;
}

} // namespace starcraft_map_editor::starcraft_data
