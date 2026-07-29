#include "casc_asset_inspector.h"

#include <Windows.h>

#include <CascLib.h>

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstring>
#include <limits>
#include <string>
#include <system_error>
#include <utility>

namespace starcraft_map_editor::starcraft_data {
namespace {

constexpr std::array<std::string_view, kRequiredAssetCount> kAssetPaths = {
    "tileset\\badlands.cv5",
    "tileset\\badlands.vf4",
    "tileset\\badlands.vx4ex",
    "tileset\\badlands.vr4",
    "tileset\\badlands.wpe",
    "tileset\\platform.cv5",
    "tileset\\platform.vf4",
    "tileset\\platform.vx4ex",
    "tileset\\platform.vr4",
    "tileset\\platform.wpe",
    "tileset\\install.cv5",
    "tileset\\install.vf4",
    "tileset\\install.vx4ex",
    "tileset\\install.vr4",
    "tileset\\install.wpe",
    "tileset\\ashworld.cv5",
    "tileset\\ashworld.vf4",
    "tileset\\ashworld.vx4ex",
    "tileset\\ashworld.vr4",
    "tileset\\ashworld.wpe",
    "tileset\\jungle.cv5",
    "tileset\\jungle.vf4",
    "tileset\\jungle.vx4ex",
    "tileset\\jungle.vr4",
    "tileset\\jungle.wpe",
    "tileset\\desert.cv5",
    "tileset\\desert.vf4",
    "tileset\\desert.vx4ex",
    "tileset\\desert.vr4",
    "tileset\\desert.wpe",
    "tileset\\ice.cv5",
    "tileset\\ice.vf4",
    "tileset\\ice.vx4ex",
    "tileset\\ice.vr4",
    "tileset\\ice.wpe",
    "tileset\\twilight.cv5",
    "tileset\\twilight.vf4",
    "tileset\\twilight.vx4ex",
    "tileset\\twilight.vr4",
    "tileset\\twilight.wpe",
};

class StorageHandle final {
 public:
  explicit StorageHandle(HANDLE handle) : handle_(handle) {}
  ~StorageHandle() {
    if (handle_ != nullptr) {
      CascCloseStorage(handle_);
    }
  }

  StorageHandle(const StorageHandle&) = delete;
  StorageHandle& operator=(const StorageHandle&) = delete;

  HANDLE get() const { return handle_; }

 private:
  HANDLE handle_ = nullptr;
};

class FileHandle final {
 public:
  explicit FileHandle(HANDLE handle) : handle_(handle) {}
  ~FileHandle() {
    if (handle_ != nullptr) {
      CascCloseFile(handle_);
    }
  }

  FileHandle(const FileHandle&) = delete;
  FileHandle& operator=(const FileHandle&) = delete;

  HANDLE get() const { return handle_; }

 private:
  HANDLE handle_ = nullptr;
};

InspectionResult Failure(
    const std::filesystem::path& installation_path,
    std::string code,
    std::string message,
    std::string stage,
    const std::uint32_t native_error) {
  InspectionResult result;
  result.installation_path = installation_path.u8string();
  result.error_code = std::move(code);
  result.message = std::move(message);
  result.stage = std::move(stage);
  result.native_error = native_error;
  return result;
}

bool IsMissingError(const std::uint32_t error) {
  return error == ERROR_FILE_NOT_FOUND ||
         error == ERROR_PATH_NOT_FOUND ||
         error == ERROR_RESOURCE_NAME_NOT_FOUND;
}

std::uint32_t ValidateFile(
    const HANDLE storage,
    const std::string_view path,
    std::uint64_t* const file_size) {
  HANDLE raw_file = nullptr;
  const std::string path_string(path);
  if (!CascOpenFile(
          storage,
          path_string.c_str(),
          CASC_LOCALE_NONE,
          CASC_OPEN_BY_NAME | CASC_STRICT_DATA_CHECK,
          &raw_file)) {
    return GetCascError();
  }
  FileHandle file(raw_file);

  ULONGLONG size = 0;
  if (!CascGetFileSize64(file.get(), &size)) {
    return GetCascError();
  }
  if (size == 0 || size > kMaximumAssetBytes) {
    return ERROR_FILE_INVALID;
  }

  std::array<std::byte, 64 * 1024> buffer{};
  ULONGLONG total_read = 0;
  while (total_read < size) {
    const auto remaining = size - total_read;
    const auto requested = static_cast<DWORD>(
        std::min<ULONGLONG>(remaining, buffer.size()));
    DWORD bytes_read = 0;
    if (!CascReadFile(
            file.get(),
            buffer.data(),
            requested,
            &bytes_read)) {
      return GetCascError();
    }
    if (bytes_read == 0 || bytes_read > requested) {
      return ERROR_INVALID_DATA;
    }
    total_read += bytes_read;
  }
  if (total_read != size) {
    return ERROR_HANDLE_EOF;
  }

  *file_size = size;
  return ERROR_SUCCESS;
}

}  // namespace

const std::array<std::string_view, kRequiredAssetCount>& RequiredAssetPaths() {
  return kAssetPaths;
}

InspectionResult InspectInstallation(
    const std::filesystem::path& installation_path) {
  std::error_code filesystem_error;
  if (!std::filesystem::exists(installation_path, filesystem_error)) {
    return Failure(
        installation_path,
        "SC_CASC_INSTALLATION_NOT_FOUND",
        "The configured StarCraft installation does not exist.",
        "validate",
        filesystem_error
            ? static_cast<std::uint32_t>(filesystem_error.value())
            : ERROR_PATH_NOT_FOUND);
  }
  if (filesystem_error ||
      !std::filesystem::is_directory(installation_path, filesystem_error)) {
    return Failure(
        installation_path,
        "SC_CASC_INSTALLATION_NOT_DIRECTORY",
        "The configured StarCraft installation is not a directory.",
        "validate",
        filesystem_error
            ? static_cast<std::uint32_t>(filesystem_error.value())
            : ERROR_DIRECTORY);
  }

  HANDLE raw_storage = nullptr;
  if (!CascOpenStorage(
          installation_path.c_str(),
          CASC_LOCALE_NONE,
          &raw_storage)) {
    return Failure(
        installation_path,
        "SC_CASC_STORAGE_OPEN_FAILED",
        "The StarCraft CASC storage could not be opened.",
        "open-storage",
        GetCascError());
  }
  StorageHandle storage(raw_storage);

  CASC_STORAGE_PRODUCT product{};
  if (!CascGetStorageInfo(
          storage.get(),
          CascStorageProduct,
          &product,
          sizeof(product),
          nullptr)) {
    return Failure(
        installation_path,
        "SC_CASC_STORAGE_INFO_FAILED",
        "The StarCraft CASC product metadata could not be read.",
        "inspect-storage",
        GetCascError());
  }

  InspectionResult result;
  result.installation_path = installation_path.u8string();
  const auto product_end = std::find(
      std::begin(product.szCodeName),
      std::end(product.szCodeName),
      '\0');
  result.storage_product.assign(
      std::begin(product.szCodeName),
      product_end);
  if (result.storage_product.empty()) {
    result.storage_product = "unknown";
  }
  result.storage_build_number = product.BuildNumber;

  for (const auto path : kAssetPaths) {
    std::uint64_t file_size = 0;
    const auto error = ValidateFile(storage.get(), path, &file_size);
    if (error == ERROR_SUCCESS) {
      if (result.total_asset_bytes >
          kMaximumTotalAssetBytes - file_size) {
        result.invalid_assets.push_back({
            std::string(path),
            ERROR_FILE_TOO_LARGE,
        });
        continue;
      }
      result.total_asset_bytes += file_size;
      result.found_asset_count++;
      continue;
    }
    if (IsMissingError(error)) {
      result.missing_paths.emplace_back(path);
      continue;
    }
    result.invalid_assets.push_back({std::string(path), error});
  }

  result.success = true;
  return result;
}

}  // namespace starcraft_map_editor::starcraft_data
