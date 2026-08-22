#include "tileset_asset_reader.h"

#include "casc_asset_inspector.h"

#include <Windows.h>

#include <CascLib.h>

#include <algorithm>
#include <array>
#include <limits>
#include <string>
#include <system_error>
#include <utility>

namespace starcraft_map_editor::starcraft_data {
namespace {

constexpr std::array<
    std::array<std::string_view, kRenderAssetCount>,
    kTilesetCount>
    kRenderAssetPaths = {{
        {"tileset\\badlands.cv5", "tileset\\badlands.vx4ex",
         "tileset\\badlands.vr4", "tileset\\badlands.wpe"},
        {"tileset\\platform.cv5", "tileset\\platform.vx4ex",
         "tileset\\platform.vr4", "tileset\\platform.wpe"},
        {"tileset\\install.cv5", "tileset\\install.vx4ex",
         "tileset\\install.vr4", "tileset\\install.wpe"},
        {"tileset\\ashworld.cv5", "tileset\\ashworld.vx4ex",
         "tileset\\ashworld.vr4", "tileset\\ashworld.wpe"},
        {"tileset\\jungle.cv5", "tileset\\jungle.vx4ex",
         "tileset\\jungle.vr4", "tileset\\jungle.wpe"},
        {"tileset\\desert.cv5", "tileset\\desert.vx4ex",
         "tileset\\desert.vr4", "tileset\\desert.wpe"},
        {"tileset\\ice.cv5", "tileset\\ice.vx4ex",
         "tileset\\ice.vr4", "tileset\\ice.wpe"},
        {"tileset\\twilight.cv5", "tileset\\twilight.vx4ex",
         "tileset\\twilight.vr4", "tileset\\twilight.wpe"},
    }};

constexpr std::array<
    std::array<std::string_view, kDoodadAssetCount>,
    kTilesetCount>
    kDoodadAssetPaths = {{
        {"tileset\\badlands.cv5", "tileset\\badlands.vx4ex",
         "tileset\\badlands.vr4", "tileset\\badlands.wpe",
         "tileset\\badlands\\dddata.bin"},
        {"tileset\\platform.cv5", "tileset\\platform.vx4ex",
         "tileset\\platform.vr4", "tileset\\platform.wpe",
         "tileset\\platform\\dddata.bin"},
        {"tileset\\install.cv5", "tileset\\install.vx4ex",
         "tileset\\install.vr4", "tileset\\install.wpe",
         "tileset\\install\\dddata.bin"},
        {"tileset\\ashworld.cv5", "tileset\\ashworld.vx4ex",
         "tileset\\ashworld.vr4", "tileset\\ashworld.wpe",
         "tileset\\ashworld\\dddata.bin"},
        {"tileset\\jungle.cv5", "tileset\\jungle.vx4ex",
         "tileset\\jungle.vr4", "tileset\\jungle.wpe",
         "tileset\\jungle\\dddata.bin"},
        {"tileset\\desert.cv5", "tileset\\desert.vx4ex",
         "tileset\\desert.vr4", "tileset\\desert.wpe",
         "tileset\\desert\\dddata.bin"},
        {"tileset\\ice.cv5", "tileset\\ice.vx4ex",
         "tileset\\ice.vr4", "tileset\\ice.wpe",
         "tileset\\ice\\dddata.bin"},
        {"tileset\\twilight.cv5", "tileset\\twilight.vx4ex",
         "tileset\\twilight.vr4", "tileset\\twilight.wpe",
         "tileset\\twilight\\dddata.bin"},
    }};

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

template <typename Result>
Result Failure(
    const std::filesystem::path& installation_path,
    std::string code,
    std::string message,
    std::string stage,
    const std::uint32_t native_error) {
  Result result;
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

std::uint32_t ReadAsset(
    const HANDLE storage,
    const std::string_view path,
    std::vector<std::byte>* const bytes) {
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
  if (size == 0 || size > kMaximumAssetBytes ||
      size > static_cast<ULONGLONG>(
                 std::numeric_limits<std::size_t>::max())) {
    return ERROR_FILE_INVALID;
  }

  bytes->resize(static_cast<std::size_t>(size));
  ULONGLONG total_read = 0;
  while (total_read < size) {
    const auto remaining = size - total_read;
    const auto requested = static_cast<DWORD>(
        std::min<ULONGLONG>(remaining, 64ULL * 1024ULL));
    DWORD bytes_read = 0;
    if (!CascReadFile(
            file.get(),
            bytes->data() + static_cast<std::size_t>(total_read),
            requested,
            &bytes_read)) {
      return GetCascError();
    }
    if (bytes_read == 0 || bytes_read > requested) {
      return ERROR_INVALID_DATA;
    }
    total_read += bytes_read;
  }
  return total_read == size ? ERROR_SUCCESS : ERROR_HANDLE_EOF;
}

template <typename Result, std::size_t AssetCount>
Result ReadAssets(
    const std::filesystem::path& installation_path,
    const std::uint32_t tileset,
    const std::array<
        std::array<std::string_view, AssetCount>,
        kTilesetCount>& paths_by_tileset,
    const std::string_view missing_code,
    const std::string_view invalid_code,
    const std::string_view missing_message,
    const std::string_view invalid_message) {
  if (tileset >= kTilesetCount) {
    return Failure<Result>(
        installation_path,
        "SC_CASC_PROTOCOL_INVALID_TILESET",
        "The requested StarCraft tileset is not supported.",
        "validate",
        ERROR_INVALID_DATA);
  }

  std::error_code filesystem_error;
  if (!std::filesystem::exists(installation_path, filesystem_error)) {
    return Failure<Result>(
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
    return Failure<Result>(
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
          installation_path.c_str(), CASC_LOCALE_NONE, &raw_storage)) {
    return Failure<Result>(
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
    return Failure<Result>(
        installation_path,
        "SC_CASC_STORAGE_INFO_FAILED",
        "The StarCraft CASC product metadata could not be read.",
        "inspect-storage",
        GetCascError());
  }

  Result result;
  result.installation_path = installation_path.u8string();
  const auto product_end = std::find(
      std::begin(product.szCodeName), std::end(product.szCodeName), '\0');
  result.storage_product.assign(std::begin(product.szCodeName), product_end);
  if (result.storage_product.empty()) {
    result.storage_product = "unknown";
  }
  result.storage_build_number = product.BuildNumber;

  const auto& paths = paths_by_tileset[tileset];
  for (std::size_t index = 0; index < paths.size(); ++index) {
    const auto error =
        ReadAsset(storage.get(), paths[index], &result.assets[index]);
    if (error != ERROR_SUCCESS) {
      return Failure<Result>(
          installation_path,
          std::string(IsMissingError(error) ? missing_code : invalid_code),
          std::string(IsMissingError(error) ? missing_message : invalid_message),
          "read-assets",
          error);
    }
    const auto size =
        static_cast<std::uint64_t>(result.assets[index].size());
    if (result.total_asset_bytes > kMaximumTotalAssetBytes - size) {
      return Failure<Result>(
          installation_path,
          std::string(invalid_code),
          "The StarCraft tileset assets exceed the byte limit.",
          "read-assets",
          ERROR_FILE_TOO_LARGE);
    }
    result.total_asset_bytes += size;
  }

  result.success = true;
  return result;
}

}  // namespace

const std::array<
    std::array<std::string_view, kRenderAssetCount>,
    kTilesetCount>&
RenderTilesetAssetPaths() {
  return kRenderAssetPaths;
}

const std::array<
    std::array<std::string_view, kDoodadAssetCount>,
    kTilesetCount>&
DoodadTilesetAssetPaths() {
  return kDoodadAssetPaths;
}

TilesetAssetReadResult ReadTilesetAssets(
    const std::filesystem::path& installation_path,
    const std::uint32_t tileset) {
  return ReadAssets<TilesetAssetReadResult>(
      installation_path,
      tileset,
      kRenderAssetPaths,
      "SC_CASC_TILE_ASSET_MISSING",
      "SC_CASC_TILE_ASSET_INVALID",
      "A required StarCraft tile rendering asset is missing.",
      "A required StarCraft tile rendering asset is unreadable.");
}

DoodadAssetReadResult ReadDoodadAssets(
    const std::filesystem::path& installation_path,
    const std::uint32_t tileset) {
  return ReadAssets<DoodadAssetReadResult>(
      installation_path,
      tileset,
      kDoodadAssetPaths,
      "SC_CASC_DOODAD_ASSET_MISSING",
      "SC_CASC_DOODAD_ASSET_INVALID",
      "A required StarCraft doodad asset is missing.",
      "A required StarCraft doodad asset is unreadable.");
}

}  // namespace starcraft_map_editor::starcraft_data
