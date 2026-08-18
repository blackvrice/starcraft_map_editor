#pragma once

#include "object_atlas_protocol.h"

#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <string>
#include <vector>

namespace starcraft_map_editor::starcraft_data {

struct ObjectRenderRequest {
  ObjectGraphicKind kind = ObjectGraphicKind::kUnit;
  std::uint16_t object_id = 0;
  std::uint8_t player_color = kNeutralObjectPlayerColor;
  std::uint8_t direction = 0;
};

struct UnsupportedObjectRender {
  ObjectRenderRequest request;
  std::string error_code;
};

struct ObjectAssetRenderResult {
  bool success = false;
  std::string installation_path;
  std::string storage_product;
  std::uint32_t storage_build_number = 0;
  std::uint32_t read_asset_count = 0;
  std::uint64_t total_asset_bytes = 0;
  std::vector<ObjectAtlasEntry> entries;
  std::vector<UnsupportedObjectRender> unsupported_objects;
  std::string error_code;
  std::string message;
  std::string stage;
  std::uint32_t native_error = 0;
};

bool ValidateObjectRenderRequests(
    const std::vector<ObjectRenderRequest>& requests);

ObjectAssetRenderResult RenderObjectAssets(
    const std::filesystem::path& installation_path,
    std::uint32_t tileset,
    const std::vector<ObjectRenderRequest>& requests);

}  // namespace starcraft_map_editor::starcraft_data
