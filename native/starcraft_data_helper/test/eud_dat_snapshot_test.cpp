#include "eud_dat_snapshot.h"
#include <iostream>

int main() {
  namespace sc = starcraft_map_editor::starcraft_data;
  std::array<std::vector<std::byte>, 7> assets;
  for (std::size_t i = 0; i < assets.size(); ++i) assets[i].resize(sc::kEudDatSizes[i]);
  // Independent layout checks: shields at 2472/2700, range at 1170, image flags at 3996.
  assets[0][2472] = std::byte{1};
  assets[0][2700] = std::byte{0x34}; assets[0][2701] = std::byte{0x12};
  assets[1][1170] = std::byte{0xef}; assets[1][1173] = std::byte{0x89};
  assets[6][3996] = std::byte{1};
  assets[0][3156] = std::byte{0x80}; assets[0][3157] = std::byte{0x28};
  assets[0][8856] = std::byte{3};
  assets[0][14860] = std::byte{50}; assets[0][15316] = std::byte{25};
  assets[0][15772] = std::byte{0x68}; assets[0][15773] = std::byte{1};
  assets[1][3640] = std::byte{6}; assets[1][3900] = std::byte{1};
  const auto data = sc::DecodeEudDat(assets);
  if (!data.success) return 1;
  for (std::size_t i = 0; i < sc::kEudDatColumns.size(); ++i) {
    const std::string key(sc::kEudDatColumns[i].key);
    if (key == "unit.hasShield" && data.columns[i][0] != 1) return 2;
    if (key == "unit.maxShield" && data.columns[i][0] != 0x1234) return 3;
    if (key == "weapon.minRange" && data.columns[i][0] != 0x890000ef) return 4;
    if (key == "image.isTurnable" && data.columns[i][0] != 1) return 5;
    if (data.columns[i].size() != sc::kEudDatColumns[i].count) return 6;
    if (key == "unit.hitpoints" && data.columns[i][0] != 0x2880) return 9;
    if (key == "unit.armor" && data.columns[i][0] != 3) return 10;
    if (key == "unit.minerals" && data.columns[i][0] != 50) return 11;
    if (key == "unit.gas" && data.columns[i][0] != 25) return 12;
    if (key == "unit.buildTime" && data.columns[i][0] != 360) return 13;
    if (key == "weapon.baseDamage" && data.columns[i][0] != 6) return 14;
    if (key == "weapon.bonusDamage" && data.columns[i][0] != 1) return 15;
  }
  for (std::size_t i = 0; i < assets.size(); ++i) {
    assets[i].push_back(std::byte{0});
    if (sc::DecodeEudDat(assets).success) return 7;
    assets[i].pop_back();
    assets[i].pop_back();
    if (sc::DecodeEudDat(assets).success) return 8;
    assets[i].push_back(std::byte{0});
  }
  std::cout << "EUD DAT sizes, endian, partial arrays and SHA256 passed\n";
  return 0;
}
