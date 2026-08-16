#include "object_sprite_reference.h"

#include <algorithm>
#include <string_view>
#include <utility>

namespace starcraft_map_editor::starcraft_data {
namespace {

constexpr std::size_t kMaximumGrpPathBytes = 255;

ObjectSpriteReferenceResult Failure(
    const ObjectGraphicKind kind,
    const std::uint16_t object_id,
    std::string code,
    std::string message,
    std::string stage) {
  ObjectSpriteReferenceResult result;
  result.kind = kind;
  result.object_id = object_id;
  result.error_code = std::move(code);
  result.message = std::move(message);
  result.stage = std::move(stage);
  return result;
}

std::uint16_t ReadUint16(
    const std::vector<std::byte>& bytes,
    const std::size_t offset) {
  return static_cast<std::uint16_t>(
      std::to_integer<std::uint8_t>(bytes[offset]) |
      (static_cast<std::uint16_t>(
           std::to_integer<std::uint8_t>(bytes[offset + 1]))
       << 8U));
}

std::uint32_t ReadUint32(
    const std::vector<std::byte>& bytes,
    const std::size_t offset) {
  std::uint32_t value = 0;
  for (std::size_t index = 0; index < 4; ++index) {
    value |= static_cast<std::uint32_t>(
                 std::to_integer<std::uint8_t>(bytes[offset + index]))
             << (index * 8U);
  }
  return value;
}

bool HasClassicMetadataSizes(const ObjectSpriteReferenceAssets& assets) {
  return assets.units_dat.size() == kClassicUnitsDatBytes &&
         assets.flingy_dat.size() == kClassicFlingyDatBytes &&
         assets.sprites_dat.size() == kClassicSpritesDatBytes &&
         assets.images_dat.size() == kClassicImagesDatBytes;
}

bool IsAsciiPathByte(const std::uint8_t value) {
  return value >= 0x20U && value <= 0x7EU;
}

char NormalizeAsciiPathCharacter(const std::uint8_t value) {
  if (value == static_cast<std::uint8_t>('/')) {
    return '\\';
  }
  if (value >= static_cast<std::uint8_t>('A') &&
      value <= static_cast<std::uint8_t>('Z')) {
    return static_cast<char>(value +
                             (static_cast<std::uint8_t>('a') -
                              static_cast<std::uint8_t>('A')));
  }
  return static_cast<char>(value);
}

bool HasGrpExtension(const std::string& path) {
  constexpr std::string_view extension = ".grp";
  return path.size() > extension.size() &&
         std::string_view(path).substr(path.size() - extension.size()) ==
             extension;
}

bool IsSafeRelativeGrpPath(const std::string& path) {
  if (!HasGrpExtension(path) || path.front() == '\\' ||
      path.find(':') != std::string::npos) {
    return false;
  }

  std::size_t segment_start = 0;
  while (segment_start < path.size()) {
    const auto separator = path.find('\\', segment_start);
    const auto segment_end =
        separator == std::string::npos ? path.size() : separator;
    const auto segment = std::string_view(path).substr(
        segment_start, segment_end - segment_start);
    if (segment.empty() || segment == "." || segment == "..") {
      return false;
    }
    if (separator == std::string::npos) {
      break;
    }
    segment_start = separator + 1;
  }
  return true;
}

bool ValidateTbl(
    const std::vector<std::byte>& bytes,
    std::uint16_t* const string_count) {
  if (bytes.size() < 4) {
    return false;
  }
  const auto count = ReadUint16(bytes, 0);
  const auto header_bytes =
      std::size_t{2} + static_cast<std::size_t>(count) * 2;
  if (count == 0 || header_bytes > bytes.size()) {
    return false;
  }

  for (std::size_t index = 0; index < count; ++index) {
    const auto string_offset =
        static_cast<std::size_t>(ReadUint16(bytes, 2 + index * 2));
    if (string_offset < header_bytes || string_offset >= bytes.size()) {
      return false;
    }
    const auto terminator = std::find(
        bytes.begin() + static_cast<std::ptrdiff_t>(string_offset),
        bytes.end(),
        std::byte{0});
    if (terminator == bytes.end()) {
      return false;
    }
  }

  *string_count = count;
  return true;
}

bool ReadGrpPath(
    const std::vector<std::byte>& images_tbl,
    const std::uint32_t grp_file_id,
    const std::uint16_t string_count,
    std::string* const asset_path) {
  if (grp_file_id == 0 || grp_file_id > string_count) {
    return false;
  }

  const auto table_index = static_cast<std::size_t>(grp_file_id - 1);
  const auto string_offset = static_cast<std::size_t>(
      ReadUint16(images_tbl, 2 + table_index * 2));
  const auto terminator = std::find(
      images_tbl.begin() + static_cast<std::ptrdiff_t>(string_offset),
      images_tbl.end(),
      std::byte{0});
  const auto length = static_cast<std::size_t>(std::distance(
      images_tbl.begin() + static_cast<std::ptrdiff_t>(string_offset),
      terminator));
  if (length == 0 || length > kMaximumGrpPathBytes) {
    return false;
  }

  std::string normalized;
  normalized.reserve(length);
  for (std::size_t index = 0; index < length; ++index) {
    const auto value = std::to_integer<std::uint8_t>(
        images_tbl[string_offset + index]);
    if (!IsAsciiPathByte(value)) {
      return false;
    }
    normalized.push_back(NormalizeAsciiPathCharacter(value));
  }
  if (!IsSafeRelativeGrpPath(normalized)) {
    return false;
  }

  *asset_path = "unit\\" + normalized;
  return true;
}

}  // namespace

ObjectSpriteReferenceResult ResolveObjectSpriteReference(
    const ObjectSpriteReferenceAssets& assets,
    const ObjectGraphicKind kind,
    const std::uint16_t object_id) {
  if (kind != ObjectGraphicKind::kUnit &&
      kind != ObjectGraphicKind::kSprite) {
    return Failure(
        kind,
        object_id,
        "SC_CASC_OBJECT_KIND_INVALID",
        "The requested object graphic kind is not supported.",
        "validate-object");
  }
  if (!HasClassicMetadataSizes(assets)) {
    return Failure(
        kind,
        object_id,
        "SC_CASC_OBJECT_METADATA_INVALID",
        "A classic StarCraft DAT file has an unsupported size.",
        "parse-metadata");
  }

  std::uint16_t tbl_string_count = 0;
  if (!ValidateTbl(assets.images_tbl, &tbl_string_count)) {
    return Failure(
        kind,
        object_id,
        "SC_CASC_OBJECT_METADATA_INVALID",
        "The StarCraft images.tbl metadata is malformed.",
        "parse-metadata");
  }

  ObjectSpriteReferenceResult result;
  result.kind = kind;
  result.object_id = object_id;

  if (kind == ObjectGraphicKind::kUnit) {
    if (object_id >= kClassicUnitCount) {
      return Failure(
          kind,
          object_id,
          "SC_CASC_OBJECT_UNIT_ID_UNSUPPORTED",
          "The requested unit ID is outside the classic units.dat range.",
          "resolve-reference");
    }
    result.has_flingy_id = true;
    result.flingy_id = std::to_integer<std::uint8_t>(
        assets.units_dat[object_id]);
    if (result.flingy_id >= kClassicFlingyCount) {
      return Failure(
          kind,
          object_id,
          "SC_CASC_OBJECT_REFERENCE_OUT_OF_RANGE",
          "The unit references a flingy ID outside flingy.dat.",
          "resolve-reference");
    }
    result.sprite_id = ReadUint16(
        assets.flingy_dat,
        static_cast<std::size_t>(result.flingy_id) * 2);
  } else {
    if (object_id >= kClassicSpriteCount) {
      return Failure(
          kind,
          object_id,
          "SC_CASC_OBJECT_SPRITE_ID_UNSUPPORTED",
          "The requested sprite ID is outside the classic sprites.dat range.",
          "resolve-reference");
    }
    result.sprite_id = object_id;
  }

  if (result.sprite_id >= kClassicSpriteCount) {
    return Failure(
        kind,
        object_id,
        "SC_CASC_OBJECT_REFERENCE_OUT_OF_RANGE",
        "The object references a sprite ID outside sprites.dat.",
        "resolve-reference");
  }
  result.image_id = ReadUint16(
      assets.sprites_dat,
      static_cast<std::size_t>(result.sprite_id) * 2);
  if (result.image_id >= kClassicImageCount) {
    return Failure(
        kind,
        object_id,
        "SC_CASC_OBJECT_REFERENCE_OUT_OF_RANGE",
        "The sprite references an image ID outside images.dat.",
        "resolve-reference");
  }

  result.grp_file_id = ReadUint32(
      assets.images_dat,
      static_cast<std::size_t>(result.image_id) * 4);
  if (result.grp_file_id == 0) {
    return Failure(
        kind,
        object_id,
        "SC_CASC_OBJECT_GRP_UNAVAILABLE",
        "The image does not reference a GRP asset.",
        "resolve-reference");
  }
  if (result.grp_file_id > tbl_string_count) {
    return Failure(
        kind,
        object_id,
        "SC_CASC_OBJECT_REFERENCE_OUT_OF_RANGE",
        "The image references an entry outside images.tbl.",
        "resolve-reference");
  }
  if (!ReadGrpPath(
          assets.images_tbl,
          result.grp_file_id,
          tbl_string_count,
          &result.grp_asset_path)) {
    return Failure(
        kind,
        object_id,
        "SC_CASC_OBJECT_GRP_PATH_INVALID",
        "The referenced GRP path is not a safe supported CASC path.",
        "resolve-reference");
  }

  result.success = true;
  return result;
}

}  // namespace starcraft_map_editor::starcraft_data
