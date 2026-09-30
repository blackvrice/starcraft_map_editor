#include "terrain_connection_snapshot.h"
#include "tileset_tile_decoder.h"

#include <Windows.h>
#include <bcrypt.h>
#include <limits>
#include <stdexcept>

namespace starcraft_map_editor::starcraft_data {
namespace {
std::uint16_t U16(const std::vector<std::byte>& bytes, std::size_t at) {
  return static_cast<std::uint16_t>(std::to_integer<unsigned>(bytes[at]) |
      (std::to_integer<unsigned>(bytes[at + 1]) << 8U));
}

std::uint32_t U32(const std::vector<std::byte>& bytes, std::size_t at) {
  return static_cast<std::uint32_t>(U16(bytes, at)) |
      (static_cast<std::uint32_t>(U16(bytes, at + 2)) << 16U);
}
}  // namespace

std::string TerrainAssetSha256(const std::vector<std::byte>& bytes) {
  if (bytes.size() > std::numeric_limits<ULONG>::max()) {
    throw std::length_error("Terrain asset exceeds hash input limit.");
  }
  BCRYPT_ALG_HANDLE algorithm = nullptr;
  if (BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM,
                                  nullptr, 0) < 0) {
    throw std::runtime_error("SHA-256 provider unavailable.");
  }
  std::array<UCHAR, 32> digest{};
  const auto status = BCryptHash(algorithm, nullptr, 0,
      reinterpret_cast<PUCHAR>(const_cast<std::byte*>(bytes.data())),
      static_cast<ULONG>(bytes.size()), digest.data(),
      static_cast<ULONG>(digest.size()));
  BCryptCloseAlgorithmProvider(algorithm, 0);
  if (status < 0) throw std::runtime_error("Terrain SHA-256 failed.");
  constexpr char hex[] = "0123456789abcdef";
  std::string result;
  result.reserve(64);
  for (const auto byte : digest) {
    result.push_back(hex[byte >> 4U]);
    result.push_back(hex[byte & 15U]);
  }
  return result;
}

TerrainConnectionSnapshot ReadTerrainConnections(
    const std::array<std::vector<std::byte>, kRenderAssetCount>& assets) {
  TerrainConnectionSnapshot result;
  if (!DecodeTilesetTiles(assets, {}).success) {
    result.error_code = "SC_CASC_TERRAIN_ASSET_INVALID";
    return result;
  }
  // Validate references once per mega-tile, without allocating image pixels.
  std::vector<bool> valid_mega(assets[1].size() / 64, true);
  for (std::size_t mega = 0; mega < valid_mega.size(); ++mega) {
    for (std::size_t mini = 0; mini < 16; ++mini) {
      if ((U32(assets[1], mega * 64 + mini * 4) >> 1U) >=
          assets[2].size() / 64) {
        valid_mega[mega] = false;
      }
    }
  }
  for (std::size_t i = 0; i < assets.size(); ++i) {
    result.asset_sha256[i] = TerrainAssetSha256(assets[i]);
  }
  const auto& cv5 = assets[0];
  for (std::size_t group = 0; group < cv5.size() / kCv5GroupBytes; ++group) {
    const auto at = group * kCv5GroupBytes;
    TerrainGroupConnection entry;
    entry.group = static_cast<std::uint16_t>(group);
    entry.terrain_type = U16(cv5, at);
    entry.flags = U16(cv5, at + 2);
    for (std::size_t side = 0; side < 4; ++side) {
      entry.links[side] = U16(cv5, at + 4 + side * 2);
      entry.stack_connections[side] = U16(cv5, at + 12 + side * 2);
    }
    for (std::uint16_t member = 0; member < 16; ++member) {
      const auto mega = U16(cv5, at + 20 + member * 2);
      if (mega < valid_mega.size() && valid_mega[mega]) {
        entry.renderable_members.push_back(member);
      }
    }
    result.groups.push_back(std::move(entry));
  }
  result.success = true;
  return result;
}

}  // namespace starcraft_map_editor::starcraft_data
