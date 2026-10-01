#include "eud_dat_snapshot.h"
#include "terrain_connection_snapshot.h"

namespace starcraft_map_editor::starcraft_data {
EudDatSnapshot DecodeEudDat(const std::array<std::vector<std::byte>, 7>& assets) {
  EudDatSnapshot result;
  for (std::size_t i = 0; i < assets.size(); ++i) {
    if (assets[i].size() != kEudDatSizes[i]) return result;
    result.hashes[i] = TerrainAssetSha256(assets[i]);
    if (result.hashes[i].size() != 64) return result;
  }
  for (std::size_t i = 0; i < kEudDatColumns.size(); ++i) {
    const auto& column = kEudDatColumns[i];
    const auto& bytes = assets[column.asset];
    if (column.offset + column.width * column.count > bytes.size()) return result;
    for (std::size_t id = 0; id < column.count; ++id) {
      std::uint32_t value = 0;
      for (std::size_t b = 0; b < column.width; ++b) {
        value |= static_cast<std::uint32_t>(std::to_integer<std::uint8_t>(
            bytes[column.offset + id * column.width + b])) << (b * 8U);
      }
      result.columns[i].push_back(value);
    }
  }
  result.success = true;
  return result;
}
}  // namespace starcraft_map_editor::starcraft_data
