#include "terrain_placement_snapshot.h"
#include "terrain_connection_snapshot.h"

namespace starcraft_map_editor::starcraft_data {
namespace {
std::uint16_t U16(const std::vector<std::byte>& bytes, std::size_t at) {
  return static_cast<std::uint16_t>(std::to_integer<unsigned>(bytes[at]) |
      (std::to_integer<unsigned>(bytes[at + 1]) << 8U));
}
}  // namespace

TerrainPlacementSnapshot ReadTerrainPlacement(
    const std::array<std::vector<std::byte>, 2>& assets) {
  TerrainPlacementSnapshot result;
  const auto& cv5 = assets[0];
  const auto& vf4 = assets[1];
  if (cv5.empty() || cv5.size() % 52 != 0 || cv5.size() / 52 > 4096 ||
      vf4.empty() || vf4.size() % 32 != 0 || vf4.size() / 32 > 65536) {
    result.error_code = "SC_CASC_TERRAIN_PLACEMENT_INVALID";
    return result;
  }
  for (std::size_t i = 0; i < assets.size(); ++i) {
    result.asset_sha256[i] = TerrainAssetSha256(assets[i]);
  }
  for (std::size_t group = 0; group < cv5.size() / 52; ++group) {
    const auto flags = U16(cv5, group * 52 + 2);
    // CV5 Unbuildable=bit7. Walkable bits in CV5 cannot replace VF4.
    result.group_buildable.push_back((flags & 0x80U) == 0);
    // Independent source bits, not a has-creep boolean or tile coverage.
    result.creep_candidate_flags.push_back(flags & 0x5040U);
    std::array<std::uint16_t, 16> references{};
    for (std::size_t member = 0; member < 16; ++member) {
      // Preserve missing references; consumers must report unknown, not pass.
      references[member] = U16(cv5, group * 52 + 20 + member * 2);
    }
    result.mega_tile_references.push_back(references);
  }
  for (std::size_t mega = 0; mega < vf4.size() / 32; ++mega) {
    std::uint16_t mask = 0, mid = 0, high = 0;
    for (std::size_t mini = 0; mini < 16; ++mini) {
      const auto flags = U16(vf4, mega * 32 + mini * 2);
      if ((flags & 1U) != 0) {
        mask = static_cast<std::uint16_t>(mask | (1U << mini));
      }
      // VF4 MiniTileFlags bit1=mid, bit2=high. Preserve both; high takes
      // display precedence. Chkdraft sc.h at 32d27861b16d, lines 3743-3764.
      if ((flags & 2U) != 0) mid = static_cast<std::uint16_t>(mid | (1U << mini));
      if ((flags & 4U) != 0) high = static_cast<std::uint16_t>(high | (1U << mini));
    }
    result.walkable_masks.push_back(mask);
    result.mid_elevation_masks.push_back(mid);
    result.high_elevation_masks.push_back(high);
  }
  result.success = true;
  return result;
}
}  // namespace starcraft_map_editor::starcraft_data
