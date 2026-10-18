#include "terrain_connection_snapshot.h"
#include "terrain_placement_snapshot.h"
#include "tileset_tile_decoder.h"

#ifdef NDEBUG
#error Tests require active assertions.
#endif
#include <cassert>
#include <iostream>

namespace sc = starcraft_map_editor::starcraft_data;

void Put(std::vector<std::byte>& bytes, std::size_t at, std::uint16_t value) {
  bytes[at] = static_cast<std::byte>(value & 255U);
  bytes[at + 1] = static_cast<std::byte>(value >> 8U);
}

int main() {
  std::array<std::vector<std::byte>, 2> placement;
  placement[0].resize(2 * 52);
  placement[1].resize(2 * 32);
  Put(placement[0], 2, 0x80);
  Put(placement[0], 54, 0x0001);  // CV5 Walkable is not VF4 walkability.
  for (std::size_t member = 0; member < 16; ++member) {
    Put(placement[0], 20 + member * 2, static_cast<std::uint16_t>(member % 2));
    Put(placement[1], member * 2, member % 2 == 0 ? 0x11 : 0x10);
  }
  Put(placement[0], 52 + 20 + 15 * 2, 65535);  // Unknown reference stays unknown.
  const auto placement_original = placement;
  const auto projected = sc::ReadTerrainPlacement(placement);
  assert(projected.success && projected.group_buildable.size() == 2);
  assert(!projected.group_buildable[0] && projected.group_buildable[1]);
  assert((projected.walkable_masks == std::vector<std::uint16_t>{0x5555, 0}));
  assert(projected.mega_tile_references[0][15] == 1);
  assert(projected.mega_tile_references[1][15] == 65535);
  assert(placement == placement_original);
  auto elevations = placement_original;
  for (std::size_t mini = 0; mini < 16; ++mini) {
    Put(elevations[1], mini * 2, static_cast<std::uint16_t>((mini % 4) * 2));
  }
  const auto elevation_original = elevations;
  const auto elevation = sc::ReadTerrainPlacement(elevations);
  assert(elevation.success);
  assert((elevation.mid_elevation_masks == std::vector<std::uint16_t>{0xaaaa, 0}));
  assert((elevation.high_elevation_masks == std::vector<std::uint16_t>{0xcccc, 0}));
  assert(elevations == elevation_original);
  // All independent combinations survive unrelated header bits unchanged.
  auto candidates = placement_original;
  candidates[0].resize(8 * 52);
  const std::vector<std::uint16_t> candidate_flags{
      0, 0x40, 0x1000, 0x1040, 0x4000, 0x4040, 0x5000, 0x5040};
  for (std::size_t group = 0; group < 8; ++group) {
    Put(candidates[0], group * 52 + 2, candidate_flags[group] | 0xafbfU);
  }
  const auto candidates_original = candidates;
  const auto candidate_projection = sc::ReadTerrainPlacement(candidates);
  assert(candidate_projection.success);
  assert(candidate_projection.creep_candidate_flags == candidate_flags);
  assert(candidates == candidates_original);
  for (std::size_t i = 0; i < 2; ++i) {
    auto bad = placement_original;
    bad[i].pop_back();
    assert(!sc::ReadTerrainPlacement(bad).success);
    bad[i].clear();
    assert(!sc::ReadTerrainPlacement(bad).success);
    bad = placement_original;
    bad[i][0] = std::byte{255};
    const auto changed = sc::ReadTerrainPlacement(bad);
    assert(changed.success && changed.asset_sha256[i] != projected.asset_sha256[i]);
    assert(changed.asset_sha256[1 - i] == projected.asset_sha256[1 - i]);
  }
  auto limits = placement_original;
  limits[0].resize(4096 * 52);
  limits[1].resize(65536 * 32);
  Put(limits[1], 65535 * 32 + 30, 1);
  Put(limits[0], 4095 * 52 + 2, 0xffff);
  const auto largest = sc::ReadTerrainPlacement(limits);
  assert(largest.success && largest.walkable_masks.back() == 0x8000);
  assert(largest.creep_candidate_flags.size() == 4096);
  assert(largest.creep_candidate_flags.back() == 0x5040);
  limits[0].resize(4097 * 52);
  assert(!sc::ReadTerrainPlacement(limits).success);
  limits[0].resize(4096 * 52);
  limits[1].resize(65537 * 32);
  assert(!sc::ReadTerrainPlacement(limits).success);
  assert(sc::TerrainAssetSha256({}) ==
      "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
  assert(sc::TerrainAssetSha256({std::byte{'a'}, std::byte{'b'}, std::byte{'c'}}) ==
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
  std::array<std::vector<std::byte>, sc::kRenderAssetCount> assets;
  assets[0].resize(2 * 52);
  assets[1].resize(2 * 64);
  assets[2].resize(64);
  assets[3].resize(1024);
  Put(assets[0], 0, 0xffff);
  Put(assets[0], 2, 0x8123);
  for (std::size_t i = 0; i < 4; ++i) {
    Put(assets[0], 4 + i * 2, static_cast<std::uint16_t>(49 + i));
    Put(assets[0], 12 + i * 2, static_cast<std::uint16_t>(0x102 + i));
  }
  Put(assets[0], 20 + 3 * 2, 2);  // Missing mega-tile.
  Put(assets[0], 20 + 4 * 2, 1);  // Mega-tile with missing mini-tile.
  Put(assets[1], 64, 2);
  const auto original = assets;
  const auto result = sc::ReadTerrainConnections(assets);
  assert(result.success && result.groups.size() == 2);
  assert(result.groups[0].terrain_type == 0xffff);
  assert(result.groups[0].flags == 0x8123);
  assert((result.groups[0].links == std::array<std::uint16_t, 4>{49, 50, 51, 52}));
  assert((result.groups[0].stack_connections ==
      std::array<std::uint16_t, 4>{258, 259, 260, 261}));
  assert((result.groups[0].renderable_members ==
      std::vector<std::uint16_t>{0, 1, 2, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15}));
  assert(result.groups[1].group == 1 && result.groups[1].renderable_members.size() == 16);
  assert(result.groups[0].mega_tile_references[0] == 0);
  assert(result.groups[0].mega_tile_references[3] == 2);
  assert(result.groups[0].mega_tile_references[4] == 1);
  assert(assets == original);
  assert(sc::ReadTerrainConnections(assets).asset_sha256 == result.asset_sha256);
  assets[3][0] = std::byte{1};
  const auto changed = sc::ReadTerrainConnections(assets);
  assert(changed.asset_sha256[0] == result.asset_sha256[0]);
  assert(changed.asset_sha256[3] != result.asset_sha256[3]);
  for (std::size_t i = 0; i < 4; ++i) {
    auto bad = original;
    bad[i].pop_back();
    const auto rejected = sc::ReadTerrainConnections(bad);
    assert(!rejected.success && rejected.groups.empty());
    assert(rejected.error_code == "SC_CASC_TERRAIN_ASSET_INVALID");
  }
  auto maximum = original;
  maximum[0].resize(4096 * 52);
  const auto last = sc::ReadTerrainConnections(maximum);
  assert(last.success && last.groups.back().group == 4095);
  maximum[0].resize(4097 * 52);
  assert(!sc::ReadTerrainConnections(maximum).success);
  std::cout << "Terrain connection projection, SHA-256 and invalid references passed.\n";
}
