#include "doodad_recipe_decoder.h"
#include "tileset_tile_decoder.h"

#include <cassert>
#include <cstddef>
#include <cstdint>
#include <iostream>
#include <vector>

namespace sc = starcraft_map_editor::starcraft_data;

namespace {

void WriteUint16(
    std::vector<std::byte>* const bytes,
    const std::size_t offset,
    const std::uint16_t value) {
  (*bytes)[offset] = static_cast<std::byte>(value & 0xffU);
  (*bytes)[offset + 1] = static_cast<std::byte>((value >> 8U) & 0xffU);
}

std::array<std::vector<std::byte>, sc::kDoodadAssetCount> Assets() {
  std::array<std::vector<std::byte>, sc::kDoodadAssetCount> assets;
  assets[0].resize(sc::kCv5GroupBytes * 6);
  assets[1].resize(64);
  assets[2].resize(64);
  assets[3].resize(256 * 4);
  assets[4].resize(4 * 256 * 2);

  const auto first = sc::kCv5GroupBytes;
  WriteUint16(&assets[0], first, 1);
  WriteUint16(&assets[0], first + 2, 0x1000);
  WriteUint16(&assets[0], first + 4, 130);
  WriteUint16(&assets[0], first + 8, 5);
  WriteUint16(&assets[0], first + 12, 3);
  WriteUint16(&assets[0], first + 14, 2);
  WriteUint16(&assets[0], first + 16, 2);
  WriteUint16(&assets[0], first + 20, 1);
  WriteUint16(&assets[0], first + 22, 2);

  const auto second_row = sc::kCv5GroupBytes * 2;
  WriteUint16(&assets[0], second_row + 20, 3);

  const auto dddata = 3 * 256 * 2;
  WriteUint16(&assets[4], dddata, 4);
  WriteUint16(&assets[4], dddata + 2, 0);
  WriteUint16(&assets[4], dddata + 4, 5);
  WriteUint16(&assets[4], dddata + 6, 6);

  const auto invalid = sc::kCv5GroupBytes * 4;
  WriteUint16(&assets[0], invalid, 1);
  WriteUint16(&assets[0], invalid + 2, 1);
  WriteUint16(&assets[0], invalid + 8, 6);
  WriteUint16(&assets[0], invalid + 12, 1);
  WriteUint16(&assets[0], invalid + 14, 17);
  WriteUint16(&assets[0], invalid + 16, 1);
  return assets;
}

void ListsValidatedRecipesAndIsolatesInvalidEntries() {
  const auto result = sc::ListDoodadRecipes(Assets(), 0, 8);
  assert(result.success);
  assert(result.total_entries == 2);
  assert(result.entries.size() == 2);

  const auto& invalid = result.entries[0];
  assert(invalid.doodad_id == 1);
  assert(invalid.start_tile_group == 4);
  assert(invalid.issue_code == "SC_CASC_DOODAD_FOOTPRINT_INVALID");
  assert(invalid.footprint.empty());

  const auto& recipe = result.entries[1];
  assert(recipe.doodad_id == 3);
  assert(recipe.start_tile_group == 1);
  assert(recipe.width == 2);
  assert(recipe.height == 2);
  assert(recipe.center_offset_x == 32);
  assert(recipe.center_offset_y == 32);
  assert(recipe.footprint.size() == 4);
  assert(recipe.footprint[0].raw_tile_value == 16);
  assert(recipe.footprint[1].raw_tile_value == 17);
  assert(recipe.footprint[2].raw_tile_value == 32);
  assert(!recipe.footprint[3].raw_tile_value.has_value());
  assert(recipe.footprint[0].required_tile_group == 4);
  assert(recipe.footprint[1].required_tile_group == 0);
  assert(recipe.footprint[2].required_tile_group == 5);
  assert(recipe.footprint[3].required_tile_group == 6);
  assert(recipe.overlay.has_value());
  assert(recipe.overlay->kind == sc::DoodadOverlayKind::kSprite);
  assert(recipe.overlay->id == 130);
  assert(recipe.issue_code.empty());
}

void PagesSortedStableKeys() {
  const auto first = sc::ListDoodadRecipes(Assets(), 0, 1);
  const auto second = sc::ListDoodadRecipes(Assets(), 1, 1);
  const auto exhausted = sc::ListDoodadRecipes(Assets(), 2, 1);
  assert(first.success && first.entries.size() == 1);
  assert(first.entries[0].doodad_id == 1);
  assert(second.success && second.entries.size() == 1);
  assert(second.entries[0].doodad_id == 3);
  assert(exhausted.success && exhausted.entries.empty());
  assert(exhausted.total_entries == 2);
}

void RejectsMalformedMetadata() {
  auto malformed_cv5 = Assets();
  malformed_cv5[0].push_back(std::byte{0});
  const auto cv5 = sc::ListDoodadRecipes(malformed_cv5, 0, 1);
  assert(!cv5.success);
  assert(cv5.error_code == "SC_CASC_DOODAD_ASSET_INVALID");

  auto malformed_dddata = Assets();
  malformed_dddata[4].pop_back();
  const auto dddata = sc::ListDoodadRecipes(malformed_dddata, 0, 1);
  assert(!dddata.success);
  assert(dddata.error_code == "SC_CASC_DOODAD_ASSET_INVALID");
}

}  // namespace

int main() {
  ListsValidatedRecipesAndIsolatesInvalidEntries();
  PagesSortedStableKeys();
  RejectsMalformedMetadata();
  std::cout << "starcraft_doodad_recipe_native_test passed\n";
  return 0;
}
