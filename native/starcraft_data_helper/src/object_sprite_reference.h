#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace starcraft_map_editor::starcraft_data {

inline constexpr std::size_t kClassicUnitCount = 228;
inline constexpr std::size_t kClassicFlingyCount = 209;
inline constexpr std::size_t kClassicSpriteCount = 517;
inline constexpr std::size_t kClassicImageCount = 999;

inline constexpr std::size_t kClassicUnitsDatBytes = 19876;
inline constexpr std::size_t kClassicFlingyDatBytes = 3135;
inline constexpr std::size_t kClassicSpritesDatBytes = 3229;
inline constexpr std::size_t kClassicImagesDatBytes = 37962;

enum class ObjectGraphicKind : std::uint8_t {
  kUnit = 0,
  kSprite = 1,
};

struct ObjectSpriteReferenceAssets {
  std::vector<std::byte> units_dat;
  std::vector<std::byte> flingy_dat;
  std::vector<std::byte> sprites_dat;
  std::vector<std::byte> images_dat;
  std::vector<std::byte> images_tbl;
};

struct ObjectSpriteReferenceResult {
  bool success = false;
  ObjectGraphicKind kind = ObjectGraphicKind::kUnit;
  std::uint16_t object_id = 0;
  bool has_flingy_id = false;
  std::uint16_t flingy_id = 0;
  std::uint16_t sprite_id = 0;
  std::uint16_t image_id = 0;
  std::uint32_t grp_file_id = 0;
  std::string grp_asset_path;
  std::string error_code;
  std::string message;
  std::string stage;
};

ObjectSpriteReferenceResult ResolveObjectSpriteReference(
    const ObjectSpriteReferenceAssets& assets,
    ObjectGraphicKind kind,
    std::uint16_t object_id);

}  // namespace starcraft_map_editor::starcraft_data

