#include "terrain_connection_snapshot.h"
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
