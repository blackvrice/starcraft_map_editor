#include "object_sprite_reference.h"

#include <cstddef>
#include <cstdint>
#include <iostream>
#include <string>
#include <vector>

namespace {

using starcraft_map_editor::starcraft_data::ObjectGraphicKind;
using starcraft_map_editor::starcraft_data::ObjectSpriteReferenceAssets;

int Fail(const std::string& message) {
  std::cerr << message << '\n';
  return 1;
}

void PutUint16(
    std::vector<std::byte>* const bytes,
    const std::size_t offset,
    const std::uint16_t value) {
  (*bytes)[offset] = static_cast<std::byte>(value & 0xFFU);
  (*bytes)[offset + 1] =
      static_cast<std::byte>((value >> 8U) & 0xFFU);
}

void PutUint32(
    std::vector<std::byte>* const bytes,
    const std::size_t offset,
    const std::uint32_t value) {
  for (std::size_t index = 0; index < 4; ++index) {
    (*bytes)[offset + index] =
        static_cast<std::byte>((value >> (index * 8U)) & 0xFFU);
  }
}

void AppendString(
    std::vector<std::byte>* const bytes,
    const std::string& value) {
  for (const auto character : value) {
    bytes->push_back(static_cast<std::byte>(
        static_cast<unsigned char>(character)));
  }
  bytes->push_back(std::byte{0});
}

ObjectSpriteReferenceAssets MakeAssets() {
  using namespace starcraft_map_editor::starcraft_data;
  ObjectSpriteReferenceAssets assets{
      std::vector<std::byte>(kClassicUnitsDatBytes),
      std::vector<std::byte>(kClassicFlingyDatBytes),
      std::vector<std::byte>(kClassicSpritesDatBytes),
      std::vector<std::byte>(kClassicImagesDatBytes),
      {},
  };

  constexpr std::uint16_t unit_id = 7;
  constexpr std::uint16_t flingy_id = 3;
  constexpr std::uint16_t sprite_id = 11;
  constexpr std::uint16_t image_id = 42;
  assets.units_dat[unit_id] = static_cast<std::byte>(flingy_id);
  PutUint16(&assets.flingy_dat, flingy_id * 2, sprite_id);
  PutUint16(&assets.sprites_dat, sprite_id * 2, image_id);
  PutUint32(&assets.images_dat, image_id * 4, 2);

  assets.images_tbl.resize(6);
  PutUint16(&assets.images_tbl, 0, 2);
  PutUint16(&assets.images_tbl, 2, 6);
  AppendString(&assets.images_tbl, "zerg\\unused.grp");
  PutUint16(
      &assets.images_tbl,
      4,
      static_cast<std::uint16_t>(assets.images_tbl.size()));
  AppendString(&assets.images_tbl, "Terran/Marine.GRP");
  return assets;
}

}  // namespace

int main() {
  using namespace starcraft_map_editor::starcraft_data;

  const auto assets = MakeAssets();
  const auto unit = ResolveObjectSpriteReference(
      assets, ObjectGraphicKind::kUnit, 7);
  if (!unit.success || unit.object_id != 7 || !unit.has_flingy_id ||
      unit.flingy_id != 3 || unit.sprite_id != 11 ||
      unit.image_id != 42 || unit.grp_file_id != 2 ||
      unit.grp_asset_path != "unit\\terran\\marine.grp") {
    return Fail("A unit DAT chain did not resolve to its normalized GRP path.");
  }

  const auto sprite = ResolveObjectSpriteReference(
      assets, ObjectGraphicKind::kSprite, 11);
  if (!sprite.success || sprite.has_flingy_id || sprite.sprite_id != 11 ||
      sprite.image_id != 42 ||
      sprite.grp_asset_path != "unit\\terran\\marine.grp") {
    return Fail("A pure sprite DAT chain did not resolve directly to its image.");
  }

  if (ResolveObjectSpriteReference(
          assets, ObjectGraphicKind::kUnit, 228).error_code !=
          "SC_CASC_OBJECT_UNIT_ID_UNSUPPORTED" ||
      ResolveObjectSpriteReference(
          assets, ObjectGraphicKind::kSprite, 517).error_code !=
          "SC_CASC_OBJECT_SPRITE_ID_UNSUPPORTED") {
    return Fail("Classic object ID limits were not enforced.");
  }

  auto invalid_kind_assets = assets;
  if (ResolveObjectSpriteReference(
          invalid_kind_assets,
          static_cast<ObjectGraphicKind>(2),
          0).error_code != "SC_CASC_OBJECT_KIND_INVALID") {
    return Fail("An unknown object graphic kind was accepted.");
  }

  auto truncated = assets;
  truncated.images_dat.pop_back();
  if (ResolveObjectSpriteReference(
          truncated, ObjectGraphicKind::kSprite, 11).error_code !=
      "SC_CASC_OBJECT_METADATA_INVALID") {
    return Fail("A truncated classic DAT file was accepted.");
  }

  auto invalid_flingy = assets;
  invalid_flingy.units_dat[7] =
      static_cast<std::byte>(kClassicFlingyCount);
  if (ResolveObjectSpriteReference(
          invalid_flingy, ObjectGraphicKind::kUnit, 7).error_code !=
      "SC_CASC_OBJECT_REFERENCE_OUT_OF_RANGE") {
    return Fail("An out-of-range unit-to-flingy reference was accepted.");
  }

  auto invalid_sprite = assets;
  PutUint16(
      &invalid_sprite.flingy_dat,
      3 * 2,
      static_cast<std::uint16_t>(kClassicSpriteCount));
  if (ResolveObjectSpriteReference(
          invalid_sprite, ObjectGraphicKind::kUnit, 7).error_code !=
      "SC_CASC_OBJECT_REFERENCE_OUT_OF_RANGE") {
    return Fail("An out-of-range flingy-to-sprite reference was accepted.");
  }

  auto invalid_image = assets;
  PutUint16(
      &invalid_image.sprites_dat,
      11 * 2,
      static_cast<std::uint16_t>(kClassicImageCount));
  if (ResolveObjectSpriteReference(
          invalid_image, ObjectGraphicKind::kSprite, 11).error_code !=
      "SC_CASC_OBJECT_REFERENCE_OUT_OF_RANGE") {
    return Fail("An out-of-range sprite-to-image reference was accepted.");
  }

  auto no_grp = assets;
  PutUint32(&no_grp.images_dat, 42 * 4, 0);
  if (ResolveObjectSpriteReference(
          no_grp, ObjectGraphicKind::kSprite, 11).error_code !=
      "SC_CASC_OBJECT_GRP_UNAVAILABLE") {
    return Fail("An image without a GRP reference was treated as renderable.");
  }

  auto invalid_tbl_reference = assets;
  PutUint32(&invalid_tbl_reference.images_dat, 42 * 4, 3);
  if (ResolveObjectSpriteReference(
          invalid_tbl_reference,
          ObjectGraphicKind::kSprite,
          11).error_code != "SC_CASC_OBJECT_REFERENCE_OUT_OF_RANGE") {
    return Fail("An out-of-range images.tbl reference was accepted.");
  }

  auto malformed_tbl = assets;
  malformed_tbl.images_tbl.back() = static_cast<std::byte>('x');
  if (ResolveObjectSpriteReference(
          malformed_tbl, ObjectGraphicKind::kSprite, 11).error_code !=
      "SC_CASC_OBJECT_METADATA_INVALID") {
    return Fail("A TBL string without a terminator was accepted.");
  }

  auto unsafe_path = assets;
  unsafe_path.images_tbl.resize(6);
  PutUint16(&unsafe_path.images_tbl, 0, 2);
  PutUint16(&unsafe_path.images_tbl, 2, 6);
  AppendString(&unsafe_path.images_tbl, "safe.grp");
  PutUint16(
      &unsafe_path.images_tbl,
      4,
      static_cast<std::uint16_t>(unsafe_path.images_tbl.size()));
  AppendString(&unsafe_path.images_tbl, "../outside.grp");
  if (ResolveObjectSpriteReference(
          unsafe_path, ObjectGraphicKind::kSprite, 11).error_code !=
      "SC_CASC_OBJECT_GRP_PATH_INVALID") {
    return Fail("A GRP path traversal was accepted.");
  }

  auto wrong_extension = unsafe_path;
  wrong_extension.images_tbl.resize(6);
  PutUint16(&wrong_extension.images_tbl, 0, 2);
  PutUint16(&wrong_extension.images_tbl, 2, 6);
  AppendString(&wrong_extension.images_tbl, "safe.grp");
  PutUint16(
      &wrong_extension.images_tbl,
      4,
      static_cast<std::uint16_t>(wrong_extension.images_tbl.size()));
  AppendString(&wrong_extension.images_tbl, "terran\\marine.png");
  if (ResolveObjectSpriteReference(
          wrong_extension, ObjectGraphicKind::kSprite, 11).error_code !=
      "SC_CASC_OBJECT_GRP_PATH_INVALID") {
    return Fail("A non-GRP object asset path was accepted.");
  }

  return 0;
}

