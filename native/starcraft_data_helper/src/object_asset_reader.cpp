#include "object_asset_reader.h"

#include "casc_asset_inspector.h"
#include "object_grp_decoder.h"
#include "object_palette_decoder.h"
#include "object_sprite_reference.h"
#include "tileset_asset_reader.h"

#include <Windows.h>

#include <CascLib.h>

#include <algorithm>
#include <array>
#include <cstddef>
#include <limits>
#include <string>
#include <string_view>
#include <system_error>
#include <tuple>
#include <unordered_map>
#include <utility>
#include <vector>

namespace starcraft_map_editor::starcraft_data {
namespace {

constexpr std::size_t kObjectMetadataAssetCount = 5;
constexpr std::size_t kObjectFixedAssetCount =
    kObjectMetadataAssetCount + 2;
constexpr std::array<std::string_view, kObjectMetadataAssetCount>
    kObjectMetadataPaths = {
        "arr\\units.dat",
        "arr\\flingy.dat",
        "arr\\sprites.dat",
        "arr\\images.dat",
        "arr\\images.tbl",
    };
constexpr std::string_view kTunitPcxPath = "game\\tunit.pcx";

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

struct CachedGrpAsset {
  bool success = false;
  std::uint32_t native_error = ERROR_SUCCESS;
  std::vector<std::byte> bytes;
};

ObjectAssetRenderResult Failure(
    const std::filesystem::path& installation_path,
    std::string code,
    std::string message,
    std::string stage,
    const std::uint32_t native_error) {
  ObjectAssetRenderResult result;
  result.installation_path = installation_path.u8string();
  result.error_code = std::move(code);
  result.message = std::move(message);
  result.stage = std::move(stage);
  result.native_error = native_error;
  return result;
}

bool IsMissingError(const std::uint32_t error) {
  return error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND ||
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
    const auto requested = static_cast<DWORD>(std::min<ULONGLONG>(
        size - total_read, 64ULL * 1024ULL));
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

bool AddAssetSize(
    ObjectAssetRenderResult* const result,
    const std::vector<std::byte>& bytes) {
  const auto size = static_cast<std::uint64_t>(bytes.size());
  if (result->total_asset_bytes > kMaximumTotalAssetBytes - size) {
    return false;
  }
  result->total_asset_bytes += size;
  result->read_asset_count++;
  return true;
}

auto RequestKey(const ObjectRenderRequest& request) {
  return std::tuple{
      static_cast<std::uint8_t>(request.kind),
      request.object_id,
      request.player_color,
      request.direction};
}

}  // namespace

bool ValidateObjectRenderRequests(
    const std::vector<ObjectRenderRequest>& requests) {
  if (requests.empty() || requests.size() > kMaximumObjectAtlasEntries) {
    return false;
  }
  for (std::size_t index = 0; index < requests.size(); ++index) {
    const auto& request = requests[index];
    if ((request.kind != ObjectGraphicKind::kUnit &&
         request.kind != ObjectGraphicKind::kSprite) ||
        (request.player_color > kMaximumObjectPlayerColor &&
         request.player_color != kNeutralObjectPlayerColor) ||
        request.direction != kObjectPreviewDirection ||
        (index > 0 &&
         !(RequestKey(requests[index - 1]) < RequestKey(request)))) {
      return false;
    }
  }
  return true;
}

ObjectAssetRenderResult RenderObjectAssets(
    const std::filesystem::path& installation_path,
    const std::uint32_t tileset,
    const std::vector<ObjectRenderRequest>& requests) {
  if (tileset >= kTilesetCount) {
    return Failure(
        installation_path,
        "SC_CASC_PROTOCOL_INVALID_TILESET",
        "The requested StarCraft tileset is not supported.",
        "validate",
        ERROR_INVALID_DATA);
  }
  if (!ValidateObjectRenderRequests(requests)) {
    return Failure(
        installation_path,
        "SC_CASC_PROTOCOL_INVALID_OBJECTS",
        "Object requests must be sorted, unique, and bounded.",
        "validate",
        ERROR_INVALID_DATA);
  }

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
          installation_path.c_str(), CASC_LOCALE_NONE, &raw_storage)) {
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

  ObjectAssetRenderResult result;
  result.installation_path = installation_path.u8string();
  const auto product_end = std::find(
      std::begin(product.szCodeName), std::end(product.szCodeName), '\0');
  result.storage_product.assign(std::begin(product.szCodeName), product_end);
  if (result.storage_product.empty()) {
    result.storage_product = "unknown";
  }
  result.storage_build_number = product.BuildNumber;

  std::array<std::vector<std::byte>, kObjectMetadataAssetCount> metadata{};
  for (std::size_t index = 0; index < metadata.size(); ++index) {
    const auto error =
        ReadAsset(storage.get(), kObjectMetadataPaths[index], &metadata[index]);
    if (error != ERROR_SUCCESS) {
      return Failure(
          installation_path,
          IsMissingError(error) ? "SC_CASC_OBJECT_METADATA_MISSING"
                                : "SC_CASC_OBJECT_METADATA_INVALID",
          IsMissingError(error)
              ? "A required StarCraft object metadata asset is missing."
              : "A required StarCraft object metadata asset is unreadable.",
          "read-object-assets",
          error);
    }
    if (!AddAssetSize(&result, metadata[index])) {
      return Failure(
          installation_path,
          "SC_CASC_OBJECT_ASSETS_TOO_LARGE",
          "The StarCraft object assets exceed the request byte limit.",
          "read-object-assets",
          ERROR_FILE_TOO_LARGE);
    }
  }

  std::vector<std::byte> wpe;
  const auto wpe_path = RenderTilesetAssetPaths()[tileset][3];
  auto error = ReadAsset(storage.get(), wpe_path, &wpe);
  if (error != ERROR_SUCCESS) {
    return Failure(
        installation_path,
        IsMissingError(error) ? "SC_CASC_OBJECT_PALETTE_MISSING"
                              : "SC_CASC_OBJECT_PALETTE_INVALID",
        IsMissingError(error)
            ? "The requested StarCraft tileset palette is missing."
            : "The requested StarCraft tileset palette is unreadable.",
        "read-object-assets",
        error);
  }
  if (!AddAssetSize(&result, wpe)) {
    return Failure(
        installation_path,
        "SC_CASC_OBJECT_ASSETS_TOO_LARGE",
        "The StarCraft object assets exceed the request byte limit.",
        "read-object-assets",
        ERROR_FILE_TOO_LARGE);
  }

  std::vector<std::byte> tunit_pcx;
  error = ReadAsset(storage.get(), kTunitPcxPath, &tunit_pcx);
  if (error != ERROR_SUCCESS) {
    return Failure(
        installation_path,
        IsMissingError(error) ? "SC_CASC_OBJECT_PALETTE_MISSING"
                              : "SC_CASC_OBJECT_PALETTE_INVALID",
        IsMissingError(error)
            ? "The StarCraft player color palette is missing."
            : "The StarCraft player color palette is unreadable.",
        "read-object-assets",
        error);
  }
  if (!AddAssetSize(&result, tunit_pcx)) {
    return Failure(
        installation_path,
        "SC_CASC_OBJECT_ASSETS_TOO_LARGE",
        "The StarCraft object assets exceed the request byte limit.",
        "read-object-assets",
        ERROR_FILE_TOO_LARGE);
  }

  const auto palettes = DecodeObjectPalettes(wpe, tunit_pcx);
  if (!palettes.success) {
    return Failure(
        installation_path,
        palettes.error_code,
        palettes.message,
        palettes.stage,
        palettes.native_error);
  }

  const ObjectSpriteReferenceAssets reference_assets{
      std::move(metadata[0]),
      std::move(metadata[1]),
      std::move(metadata[2]),
      std::move(metadata[3]),
      std::move(metadata[4]),
  };
  std::unordered_map<std::string, CachedGrpAsset> grp_cache;
  for (const auto& request : requests) {
    const auto reference = ResolveObjectSpriteReference(
        reference_assets, request.kind, request.object_id);
    if (!reference.success) {
      if (reference.error_code == "SC_CASC_OBJECT_METADATA_INVALID") {
        return Failure(
            installation_path,
            reference.error_code,
            reference.message,
            reference.stage,
            ERROR_INVALID_DATA);
      }
      result.unsupported_objects.push_back({request, reference.error_code});
      continue;
    }

    auto [iterator, inserted] = grp_cache.try_emplace(
        reference.grp_asset_path, CachedGrpAsset{});
    auto& grp_asset = iterator->second;
    if (inserted) {
      grp_asset.native_error = ReadAsset(
          storage.get(), reference.grp_asset_path, &grp_asset.bytes);
      grp_asset.success = grp_asset.native_error == ERROR_SUCCESS;
      if (grp_asset.success && !AddAssetSize(&result, grp_asset.bytes)) {
        return Failure(
            installation_path,
            "SC_CASC_OBJECT_ASSETS_TOO_LARGE",
            "The StarCraft object assets exceed the request byte limit.",
            "read-object-assets",
            ERROR_FILE_TOO_LARGE);
      }
    }
    if (!grp_asset.success) {
      result.unsupported_objects.push_back({
          request,
          IsMissingError(grp_asset.native_error)
              ? "SC_CASC_OBJECT_GRP_MISSING"
              : "SC_CASC_OBJECT_GRP_INVALID",
      });
      continue;
    }

    const ObjectPlayerRgbPalette* player_palette = nullptr;
    if (request.player_color != kNeutralObjectPlayerColor) {
      player_palette = &palettes.player_palettes[request.player_color];
    }
    auto decoded = DecodeObjectGrpFirstFrame(
        grp_asset.bytes, palettes.base_palette, player_palette);
    if (!decoded.success) {
      result.unsupported_objects.push_back({request, decoded.error_code});
      continue;
    }

    ObjectAtlasEntry entry;
    entry.kind = request.kind;
    entry.player_color = request.player_color;
    entry.direction = request.direction;
    entry.object_id = request.object_id;
    entry.sprite_id = reference.sprite_id;
    entry.image_id = reference.image_id;
    entry.width = decoded.width;
    entry.height = decoded.height;
    entry.anchor_x = decoded.anchor_x;
    entry.anchor_y = decoded.anchor_y;
    entry.frame_index = decoded.frame_index;
    entry.rgba_bytes = std::move(decoded.rgba_bytes);
    result.entries.push_back(std::move(entry));
  }

  if (result.read_asset_count < kObjectFixedAssetCount) {
    return Failure(
        installation_path,
        "SC_CASC_OBJECT_METADATA_INVALID",
        "The StarCraft object asset read count is inconsistent.",
        "read-object-assets",
        ERROR_INVALID_DATA);
  }
  result.success = true;
  return result;
}

}  // namespace starcraft_map_editor::starcraft_data
