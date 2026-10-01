#pragma once
#include "eud_dat_layout.h"
#include "tileset_asset_reader.h"

namespace starcraft_map_editor::starcraft_data {
struct EudDatSnapshot {
  bool success = false;
  std::array<std::string, 7> hashes;
  std::array<std::vector<std::uint32_t>, 61> columns;
};
EudDatSnapshot DecodeEudDat(const std::array<std::vector<std::byte>, 7>& assets);
}  // namespace starcraft_map_editor::starcraft_data
