#include "doodad_recipe_decoder.h"

#include "object_sprite_reference.h"
#include "tileset_tile_decoder.h"

#include <Windows.h>

#include <algorithm>
#include <limits>
#include <utility>

namespace starcraft_map_editor::starcraft_data {
namespace {

constexpr std::size_t kDdDataEntryBytes = 256 * 2;
constexpr std::size_t kMaximumDdDataEntries = 512;
constexpr std::uint16_t kDoodadMarker = 1;
constexpr std::uint16_t kDrawAsSprite = 0x1000;
constexpr std::size_t kFlagsOffset = 2;
constexpr std::size_t kOverlayIndexOffset = 4;
constexpr std::size_t kDoodadNameOffset = 8;
constexpr std::size_t kDdDataIndexOffset = 12;
constexpr std::size_t kTileWidthOffset = 14;
constexpr std::size_t kTileHeightOffset = 16;
constexpr std::size_t kMegaTileReferencesOffset = 20;
constexpr std::uint16_t kMaximumFootprintAxis = 16;

std::uint8_t ReadUint8(
    const std::vector<std::byte>& bytes,
    const std::size_t offset) {
  return std::to_integer<std::uint8_t>(bytes[offset]);
}

std::uint16_t ReadUint16(
    const std::vector<std::byte>& bytes,
    const std::size_t offset) {
  return static_cast<std::uint16_t>(
      ReadUint8(bytes, offset) |
      (static_cast<std::uint16_t>(ReadUint8(bytes, offset + 1)) << 8U));
}

DoodadCatalogResult Failure(std::string message) {
  DoodadCatalogResult result;
  result.error_code = "SC_CASC_DOODAD_ASSET_INVALID";
  result.message = std::move(message);
  result.stage = "decode-doodads";
  result.native_error = ERROR_INVALID_DATA;
  return result;
}

std::string ValidateHeader(
    const std::vector<std::byte>& cv5,
    const std::vector<std::byte>& dddata,
    const std::size_t group,
    DoodadPlacementRecipe* const recipe) {
  const auto base = group * kCv5GroupBytes;
  const auto flags = ReadUint16(cv5, base + kFlagsOffset);
  const auto overlay_id = ReadUint16(cv5, base + kOverlayIndexOffset);
  const auto dddata_id = ReadUint16(cv5, base + kDdDataIndexOffset);
  const auto width = ReadUint16(cv5, base + kTileWidthOffset);
  const auto height = ReadUint16(cv5, base + kTileHeightOffset);
  recipe->start_tile_group = static_cast<std::uint16_t>(group);
  recipe->doodad_id = dddata_id;
  recipe->width = width;
  recipe->height = height;

  const auto group_count = cv5.size() / kCv5GroupBytes;
  const auto dddata_count = dddata.size() / kDdDataEntryBytes;
  if (flags == 0) {
    return "SC_CASC_DOODAD_FLAGS_INVALID";
  }
  if (width == 0 || height == 0 || width > kMaximumFootprintAxis ||
      height > kMaximumFootprintAxis ||
      static_cast<std::size_t>(width) * height > 256) {
    return "SC_CASC_DOODAD_FOOTPRINT_INVALID";
  }
  if (group + height > group_count) {
    return "SC_CASC_DOODAD_FOOTPRINT_TRUNCATED";
  }
  if (dddata_id >= dddata_count) {
    return "SC_CASC_DOODAD_PLACIBILITY_MISSING";
  }
  if (overlay_id != 0) {
    const auto is_sprite = (flags & kDrawAsSprite) != 0;
    if ((is_sprite && overlay_id >= kClassicSpriteCount) ||
        (!is_sprite && overlay_id >= kClassicUnitCount)) {
      return "SC_CASC_DOODAD_OVERLAY_INVALID";
    }
    recipe->overlay = DoodadOverlayRecipe{
        is_sprite ? DoodadOverlayKind::kSprite
                  : DoodadOverlayKind::kUnit,
        overlay_id,
    };
  }
  recipe->center_offset_x = static_cast<std::uint16_t>(width * 16U);
  recipe->center_offset_y = static_cast<std::uint16_t>(height * 16U);
  return {};
}

std::string PopulateFootprint(
    const std::vector<std::byte>& cv5,
    const std::vector<std::byte>& dddata,
    DoodadPlacementRecipe* const recipe) {
  const auto dddata_base =
      static_cast<std::size_t>(recipe->doodad_id) * kDdDataEntryBytes;
  recipe->footprint.reserve(
      static_cast<std::size_t>(recipe->width) * recipe->height);
  bool has_tile = false;
  for (std::uint16_t y = 0; y < recipe->height; ++y) {
    const auto group =
        static_cast<std::size_t>(recipe->start_tile_group) + y;
    const auto cv5_base = group * kCv5GroupBytes;
    for (std::uint16_t x = 0; x < recipe->width; ++x) {
      const auto cell_index =
          static_cast<std::size_t>(y) * recipe->width + x;
      const auto mega_tile = ReadUint16(
          cv5, cv5_base + kMegaTileReferencesOffset + x * 2U);
      const auto required_group =
          ReadUint16(dddata, dddata_base + cell_index * 2U);
      std::optional<std::uint16_t> raw_tile_value;
      if (mega_tile != 0) {
        const auto raw = group * 16U + x;
        if (raw > std::numeric_limits<std::uint16_t>::max()) {
          return "SC_CASC_DOODAD_TILE_VALUE_INVALID";
        }
        raw_tile_value = static_cast<std::uint16_t>(raw);
        has_tile = true;
      }
      recipe->footprint.push_back(
          DoodadFootprintCell{x, y, raw_tile_value, required_group});
    }
  }
  return has_tile ? std::string{} : "SC_CASC_DOODAD_FOOTPRINT_EMPTY";
}

}  // namespace

DoodadCatalogResult ListDoodadRecipes(
    const std::array<std::vector<std::byte>, kDoodadAssetCount>& assets,
    const std::uint32_t offset,
    const std::uint32_t limit) {
  if (offset > 0xFFFFU || limit == 0 || limit > kMaximumCatalogPageSize) {
    auto result = Failure("The doodad catalog page is outside the supported range.");
    result.error_code = "SC_CASC_PROTOCOL_INVALID_CATALOG_PAGE";
    result.stage = "protocol";
    return result;
  }

  const auto& cv5 = assets[0];
  const auto& dddata = assets[4];
  const auto& vf4 = assets[5];
  if (vf4.empty() || vf4.size() % 32 != 0 ||
      vf4.size() / 32 != assets[1].size() / 64) {
    return Failure("The StarCraft VF4 elevation metadata has an invalid byte length.");
  }
  if (cv5.empty() || cv5.size() % kCv5GroupBytes != 0 ||
      cv5.size() / kCv5GroupBytes > kMaximumCv5Groups) {
    return Failure("The StarCraft CV5 doodad metadata has an invalid byte length.");
  }
  if (dddata.empty() || dddata.size() % kDdDataEntryBytes != 0 ||
      dddata.size() / kDdDataEntryBytes > kMaximumDdDataEntries) {
    return Failure("The StarCraft DDData placibility metadata has an invalid byte length.");
  }

  std::array<std::vector<std::byte>, kRenderAssetCount> render_assets;
  std::copy_n(assets.begin(), kRenderAssetCount, render_assets.begin());
  const auto tile_validation = DecodeTilesetTiles(render_assets, {});
  if (!tile_validation.success) {
    return Failure(tile_validation.message);
  }

  std::vector<DoodadPlacementRecipe> all_entries;
  const auto group_count = cv5.size() / kCv5GroupBytes;
  for (std::size_t group = 0; group < group_count; ++group) {
    const auto base = group * kCv5GroupBytes;
    if (ReadUint16(cv5, base) != kDoodadMarker ||
        ReadUint16(cv5, base + kDoodadNameOffset) == 0) {
      continue;
    }
    DoodadPlacementRecipe recipe;
    recipe.issue_code = ValidateHeader(cv5, dddata, group, &recipe);
    if (recipe.issue_code.empty()) {
      recipe.issue_code = PopulateFootprint(cv5, dddata, &recipe);
      if (recipe.issue_code.empty()) {
        const auto mini_width = recipe.width * 4U;
        std::vector<std::uint16_t> mini_flags(mini_width * recipe.height * 4U);
        for (const auto& cell : recipe.footprint) {
          if (!cell.raw_tile_value.has_value()) continue;
          const auto raw = *cell.raw_tile_value;
          const auto mega = ReadUint16(cv5,
              (raw / 16U) * kCv5GroupBytes + 20 + (raw % 16U) * 2);
          if (mega >= vf4.size() / 32) {
            recipe.issue_code = "SC_CASC_DOODAD_VF4_REFERENCE_INVALID";
            break;
          }
          for (std::size_t mini = 0; mini < 16; ++mini) {
            mini_flags[(cell.y * 4U + mini / 4U) * mini_width +
                cell.x * 4U + mini % 4U] = ReadUint16(vf4, mega * 32 + mini * 2);
          }
        }
        std::vector<bool> visited(mini_flags.size());
        for (std::size_t at = 0; at < mini_flags.size(); ++at) {
          if (visited[at] || (mini_flags[at] & 1U) == 0) continue;
          unsigned elevation_mask = 0;
          bool walkable_ramp = false;
          std::vector<std::size_t> pending{at};
          visited[at] = true;
          for (std::size_t next = 0; next < pending.size(); ++next) {
            const auto index = pending[next];
            const auto flags = mini_flags[index];
            elevation_mask |= (flags & 4U) != 0 ? 4U :
                (flags & 2U) != 0 ? 2U : 1U;
            if ((flags & 0x10U) != 0) walkable_ramp = true;
            const auto enqueue = [&](std::size_t neighbor) {
              if (!visited[neighbor] && (mini_flags[neighbor] & 1U) != 0) {
                visited[neighbor] = true;
                pending.push_back(neighbor);
              }
            };
            if (index % mini_width > 0) enqueue(index - 1);
            if (index % mini_width + 1 < mini_width) enqueue(index + 1);
            if (index >= mini_width) enqueue(index - mini_width);
            if (index + mini_width < mini_flags.size()) enqueue(index + mini_width);
          }
          if (walkable_ramp && (elevation_mask & (elevation_mask - 1U)) != 0) {
            recipe.has_ramp = true;
            break;
          }
        }
      }
    }
    all_entries.push_back(std::move(recipe));
  }
  std::sort(
      all_entries.begin(),
      all_entries.end(),
      [](const DoodadPlacementRecipe& left,
         const DoodadPlacementRecipe& right) {
        if (left.doodad_id != right.doodad_id) {
          return left.doodad_id < right.doodad_id;
        }
        return left.start_tile_group < right.start_tile_group;
      });

  DoodadCatalogResult result;
  result.total_entries = all_entries.size();
  const auto start = std::min<std::size_t>(offset, all_entries.size());
  const auto end = std::min<std::size_t>(
      all_entries.size(), start + static_cast<std::size_t>(limit));
  result.entries.assign(all_entries.begin() + start, all_entries.begin() + end);
  result.success = true;
  return result;
}

}  // namespace starcraft_map_editor::starcraft_data
