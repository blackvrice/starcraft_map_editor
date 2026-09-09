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
  std::uint8_t direction = kObjectPreviewDirection;
};

// The verified units.dat facts a CHK UNIT record needs. Only derived
// booleans and validated reference IDs leave the helper; raw DAT bytes stay local.
struct UnitCapability {
  std::uint16_t unit_id = 0;
  bool weapon_references_valid = false;
  std::uint8_t ground_weapon = 130;
  std::uint8_t air_weapon = 130;
  std::uint16_t subunit1 = 228;
  std::uint16_t subunit2 = 228;
  bool is_spellcaster = false;
  bool has_shields = false;
  bool is_resource_container = false;
  bool is_gas_resource_container = false;
  bool has_hangar = false;
  bool is_flying_building = false;
  bool is_burrowable = false;
  bool is_cloakable = false;
  bool is_invincible = false;
  bool is_building = false;
  bool requires_relation_link = false;
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
  std::vector<UnitCapability> unit_capabilities;
  std::vector<UnsupportedObjectRender> unsupported_objects;
  std::string error_code;
  std::string message;
  std::string stage;
  std::uint32_t native_error = 0;
};

// Fills the verified units.dat capability of one unit. Returns false when
// units.dat is not the classic fixed size or the id is out of range, in which
// case the caller reports the unit as unavailable instead of guessing a flag.
bool ReadUnitCapability(
    const std::vector<std::byte>& units_dat,
    std::uint16_t unit_id,
    UnitCapability* capability);

bool ValidateObjectRenderRequests(
    const std::vector<ObjectRenderRequest>& requests);

ObjectAssetRenderResult RenderObjectAssets(
    const std::filesystem::path& installation_path,
    std::uint32_t tileset,
    const std::vector<ObjectRenderRequest>& requests,
    bool metadata_only = false);

}  // namespace starcraft_map_editor::starcraft_data
