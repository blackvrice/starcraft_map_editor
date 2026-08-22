#include "casc_asset_inspector.h"
#include "object_asset_reader.h"
#include "object_atlas_protocol.h"
#include "object_sprite_reference.h"
#include "tile_atlas_protocol.h"
#include "tileset_asset_reader.h"
#include "tileset_tile_decoder.h"

#include <Windows.h>

#include <nlohmann/json.hpp>

#include <algorithm>
#include <cstdint>
#include <filesystem>
#include <iostream>
#include <string>
#include <vector>

namespace {

using json = nlohmann::json;

constexpr std::int32_t kProtocolVersion = 3;
constexpr std::size_t kMaximumRequestBytes = 64 * 1024;
constexpr char kInspectOperation[] = "inspectInstallation";
constexpr char kRenderOperation[] = "renderTileAtlas";
constexpr char kRenderObjectOperation[] = "renderObjectAtlas";
constexpr char kListCatalogOperation[] = "listPlacementCatalog";
constexpr char kHelperVersion[] = "0.6.0";
constexpr char kCascLibRevision[] =
    "4971d363e665551ac4142f541e5f2d71f1cda653";

json BaseResponse(
    const std::string& request_id,
    const std::string& operation) {
  return {
      {"protocolVersion", kProtocolVersion},
      {"requestId", request_id},
      {"operation", operation},
      {"helperVersion", kHelperVersion},
      {"cascLibRevision", kCascLibRevision},
  };
}

int WriteError(
    const std::string& request_id,
    const std::string& operation,
    const std::string& code,
    const std::string& message,
    const std::string& stage,
    const std::uint32_t native_error,
    const int exit_code) {
  auto response = BaseResponse(request_id, operation);
  response["status"] = "error";
  response["error"] = {
      {"code", code},
      {"message", message},
      {"stage", stage},
      {"nativeError", native_error},
  };
  std::cout << response.dump() << '\n';
  std::cerr << code << '\n';
  return exit_code;
}

bool IsNonEmptyString(const json& value, const char* const key) {
  return value.contains(key) && value[key].is_string() &&
         !value[key].get_ref<const std::string&>().empty();
}

int InspectInstallation(
    const std::string& request_id,
    const std::filesystem::path& installation_path) {
  const auto result =
      starcraft_map_editor::starcraft_data::InspectInstallation(
          installation_path);
  if (!result.success) {
    return WriteError(
        request_id,
        kInspectOperation,
        result.error_code,
        result.message,
        result.stage,
        result.native_error,
        3);
  }

  auto response = BaseResponse(request_id, kInspectOperation);
  response["status"] = "success";
  response["installation"] = {
      {"path", result.installation_path},
      {"storageProduct", result.storage_product},
      {"storageBuildNumber", result.storage_build_number},
  };
  response["assets"] = {
      {"requiredCount",
       starcraft_map_editor::starcraft_data::kRequiredAssetCount},
      {"foundCount", result.found_asset_count},
      {"totalBytes", result.total_asset_bytes},
      {"missingPaths", result.missing_paths},
      {"invalidAssets", json::array()},
  };
  for (const auto& invalid_asset : result.invalid_assets) {
    response["assets"]["invalidAssets"].push_back({
        {"path", invalid_asset.path},
        {"nativeError", invalid_asset.native_error},
    });
  }
  std::cout << response.dump() << '\n';
  return 0;
}

int RenderTileAtlas(
    const json& request,
    const std::string& request_id,
    const std::filesystem::path& installation_path) {
  if (!request.contains("tileset") ||
      !request["tileset"].is_number_integer() ||
      !request.contains("rawValues") ||
      !request["rawValues"].is_array() ||
      !IsNonEmptyString(request, "outputFileName")) {
    return WriteError(
        request_id,
        kRenderOperation,
        "SC_CASC_PROTOCOL_INVALID_REQUEST",
        "The tile atlas request is missing a required field.",
        "protocol",
        ERROR_INVALID_DATA,
        2);
  }

  const auto tileset_value = request["tileset"].get<std::int64_t>();
  if (tileset_value < 0 ||
      tileset_value >= static_cast<std::int64_t>(
                           starcraft_map_editor::starcraft_data::
                               kTilesetCount)) {
    return WriteError(
        request_id,
        kRenderOperation,
        "SC_CASC_PROTOCOL_INVALID_TILESET",
        "The requested StarCraft tileset is not supported.",
        "protocol",
        ERROR_INVALID_DATA,
        2);
  }
  if (request["outputFileName"].get<std::string>() !=
      starcraft_map_editor::starcraft_data::kTileAtlasFileName) {
    return WriteError(
        request_id,
        kRenderOperation,
        "SC_CASC_PROTOCOL_INVALID_OUTPUT",
        "The tile atlas output name is not allowed.",
        "protocol",
        ERROR_INVALID_NAME,
        2);
  }

  std::vector<std::uint32_t> raw_values;
  raw_values.reserve(request["rawValues"].size());
  for (const auto& value : request["rawValues"]) {
    if (!value.is_number_integer()) {
      return WriteError(
          request_id,
          kRenderOperation,
          "SC_CASC_PROTOCOL_INVALID_RAW_VALUES",
          "Tile raw values must be integers.",
          "protocol",
          ERROR_INVALID_DATA,
          2);
    }
    const auto integer = value.get<std::int64_t>();
    if (integer < 0 || integer > 0xFFFF) {
      return WriteError(
          request_id,
          kRenderOperation,
          "SC_CASC_PROTOCOL_INVALID_RAW_VALUES",
          "A tile raw value is outside the u16 range.",
          "protocol",
          ERROR_INVALID_DATA,
          2);
    }
    raw_values.push_back(static_cast<std::uint32_t>(integer));
  }
  if (!starcraft_map_editor::starcraft_data::ValidateRawValues(raw_values)) {
    return WriteError(
        request_id,
        kRenderOperation,
        "SC_CASC_PROTOCOL_INVALID_RAW_VALUES",
        "Tile raw values must be sorted, unique, and bounded.",
        "protocol",
        ERROR_INVALID_DATA,
        2);
  }

  const auto assets =
      starcraft_map_editor::starcraft_data::ReadTilesetAssets(
          installation_path,
          static_cast<std::uint32_t>(tileset_value));
  if (!assets.success) {
    return WriteError(
        request_id,
        kRenderOperation,
        assets.error_code,
        assets.message,
        assets.stage,
        assets.native_error,
        3);
  }

  const auto decoded =
      starcraft_map_editor::starcraft_data::DecodeTilesetTiles(
          assets.assets, raw_values);
  if (!decoded.success) {
    return WriteError(
        request_id,
        kRenderOperation,
        decoded.error_code,
        decoded.message,
        decoded.stage,
        decoded.native_error,
        3);
  }

  const auto atlas =
      starcraft_map_editor::starcraft_data::WriteTileAtlas(
          std::filesystem::current_path(),
          decoded.rendered_raw_values,
          decoded.rgba_bytes);
  if (!atlas.success) {
    return WriteError(
        request_id,
        kRenderOperation,
        atlas.error_code,
        atlas.message,
        atlas.stage,
        atlas.native_error,
        3);
  }

  auto response = BaseResponse(request_id, kRenderOperation);
  response["status"] = "success";
  response["installation"] = {
      {"path", assets.installation_path},
      {"storageProduct", assets.storage_product},
      {"storageBuildNumber", assets.storage_build_number},
  };
  response["tileset"] = tileset_value;
  response["assets"] = {
      {"readCount",
       starcraft_map_editor::starcraft_data::kRenderAssetCount},
      {"totalBytes", assets.total_asset_bytes},
  };
  response["atlas"] = {
      {"fileName",
       starcraft_map_editor::starcraft_data::kTileAtlasFileName},
      {"fileBytes", atlas.file_bytes},
      {"formatVersion",
       starcraft_map_editor::starcraft_data::kTileAtlasFormatVersion},
      {"tileSize", starcraft_map_editor::starcraft_data::kTileSize},
      {"columns", atlas.columns},
      {"rows", atlas.rows},
      {"tileCount", atlas.tile_count},
  };
  response["unsupportedRawValues"] = decoded.unsupported_raw_values;
  std::cout << response.dump() << '\n';
  return 0;
}

int ListPlacementCatalog(
    const json& request,
    const std::string& request_id,
    const std::filesystem::path& installation_path) {
  namespace sc = starcraft_map_editor::starcraft_data;
  if (!IsNonEmptyString(request, "kind") ||
      !request.contains("tileset") ||
      !request["tileset"].is_number_integer() ||
      !request.contains("offset") ||
      !request["offset"].is_number_integer() ||
      !request.contains("limit") ||
      !request["limit"].is_number_integer()) {
    return WriteError(
        request_id,
        kListCatalogOperation,
        "SC_CASC_PROTOCOL_INVALID_REQUEST",
        "The placement catalog request is missing a required field.",
        "protocol",
        ERROR_INVALID_DATA,
        2);
  }
  const auto kind = request["kind"].get<std::string>();
  if (kind != "tile" && kind != "unit" && kind != "pureSprite") {
    return WriteError(
        request_id,
        kListCatalogOperation,
        "SC_CASC_PROTOCOL_CATALOG_KIND_UNSUPPORTED",
        "The requested placement catalog kind is not supported.",
        "protocol",
        ERROR_NOT_SUPPORTED,
        2);
  }

  const auto tileset = request["tileset"].get<std::int64_t>();
  const auto offset = request["offset"].get<std::int64_t>();
  const auto limit = request["limit"].get<std::int64_t>();
  if (tileset < 0 || tileset >= static_cast<std::int64_t>(sc::kTilesetCount)) {
    return WriteError(
        request_id,
        kListCatalogOperation,
        "SC_CASC_PROTOCOL_INVALID_TILESET",
        "The requested StarCraft tileset is not supported.",
        "protocol",
        ERROR_INVALID_DATA,
        2);
  }
  if (offset < 0 || offset > 0xFFFF || limit < 1 ||
      limit > static_cast<std::int64_t>(sc::kMaximumCatalogPageSize)) {
    return WriteError(
        request_id,
        kListCatalogOperation,
        "SC_CASC_PROTOCOL_INVALID_CATALOG_PAGE",
        "The tile catalog page is outside the supported range.",
        "protocol",
        ERROR_INVALID_DATA,
        2);
  }

  if (kind != "tile") {
    const auto graphic_kind =
        kind == "unit" ? sc::ObjectGraphicKind::kUnit
                       : sc::ObjectGraphicKind::kSprite;
    const auto total_entries =
        kind == "unit" ? sc::kClassicUnitCount : sc::kClassicSpriteCount;
    const auto start = std::min<std::size_t>(
        static_cast<std::size_t>(offset), total_entries);
    const auto end = std::min<std::size_t>(
        total_entries, start + static_cast<std::size_t>(limit));
    std::vector<sc::ObjectRenderRequest> page_requests;
    page_requests.reserve(end - start);
    for (auto id = start; id < end; ++id) {
      sc::ObjectRenderRequest object;
      object.kind = graphic_kind;
      object.object_id = static_cast<std::uint16_t>(id);
      object.player_color = sc::kNeutralObjectPlayerColor;
      object.direction = sc::kObjectPreviewDirection;
      page_requests.push_back(object);
    }

    auto render_requests = page_requests;
    if (render_requests.empty()) {
      sc::ObjectRenderRequest probe;
      probe.kind = graphic_kind;
      probe.object_id = 0;
      probe.player_color = sc::kNeutralObjectPlayerColor;
      probe.direction = sc::kObjectPreviewDirection;
      render_requests.push_back(probe);
    }
    const auto rendered = sc::RenderObjectAssets(
        installation_path,
        static_cast<std::uint32_t>(tileset),
        render_requests);
    if (!rendered.success) {
      return WriteError(
          request_id,
          kListCatalogOperation,
          rendered.error_code,
          rendered.message,
          rendered.stage,
          rendered.native_error,
          3);
    }

    auto response = BaseResponse(request_id, kListCatalogOperation);
    response["status"] = "success";
    response["installation"] = {
        {"path", rendered.installation_path},
        {"storageProduct", rendered.storage_product},
        {"storageBuildNumber", rendered.storage_build_number},
    };
    response["kind"] = kind;
    response["tileset"] = tileset;
    response["assets"] = {
        {"readCount", rendered.read_asset_count},
        {"totalBytes", rendered.total_asset_bytes},
    };
    response["catalog"] = {
        {"offset", offset},
        {"limit", limit},
        {"totalEntries", total_entries},
    };
    response["entries"] = json::array();
    for (const auto& object : page_requests) {
      const auto rendered_entry = std::find_if(
          rendered.entries.begin(),
          rendered.entries.end(),
          [&object](const sc::ObjectAtlasEntry& entry) {
            return entry.kind == object.kind &&
                   entry.object_id == object.object_id;
          });
      if (rendered_entry != rendered.entries.end()) {
        response["entries"].push_back({
            {"id", object.object_id},
            {"previewIssueCode", nullptr},
        });
        continue;
      }
      const auto unsupported = std::find_if(
          rendered.unsupported_objects.begin(),
          rendered.unsupported_objects.end(),
          [&object](const sc::UnsupportedObjectRender& item) {
            return item.request.kind == object.kind &&
                   item.request.object_id == object.object_id;
          });
      if (unsupported == rendered.unsupported_objects.end()) {
        return WriteError(
            request_id,
            kListCatalogOperation,
            "SC_CASC_OBJECT_CATALOG_INVALID",
            "The object catalog preview coverage is incomplete.",
            "list-catalog",
            ERROR_INVALID_DATA,
            3);
      }
      response["entries"].push_back({
          {"id", object.object_id},
          {"previewIssueCode", unsupported->error_code},
      });
    }
    std::cout << response.dump() << '\n';
    return 0;
  }

  const auto assets = sc::ReadTilesetAssets(
      installation_path, static_cast<std::uint32_t>(tileset));
  if (!assets.success) {
    return WriteError(
        request_id,
        kListCatalogOperation,
        assets.error_code,
        assets.message,
        assets.stage,
        assets.native_error,
        3);
  }
  const auto catalog = sc::ListTilesetTiles(
      assets.assets,
      static_cast<std::uint32_t>(offset),
      static_cast<std::uint32_t>(limit));
  if (!catalog.success) {
    return WriteError(
        request_id,
        kListCatalogOperation,
        catalog.error_code,
        catalog.message,
        catalog.stage,
        catalog.native_error,
        3);
  }

  auto response = BaseResponse(request_id, kListCatalogOperation);
  response["status"] = "success";
  response["installation"] = {
      {"path", assets.installation_path},
      {"storageProduct", assets.storage_product},
      {"storageBuildNumber", assets.storage_build_number},
  };
  response["kind"] = "tile";
  response["tileset"] = tileset;
  response["assets"] = {
      {"readCount", sc::kRenderAssetCount},
      {"totalBytes", assets.total_asset_bytes},
  };
  response["catalog"] = {
      {"offset", offset},
      {"limit", limit},
      {"totalEntries", catalog.total_entries},
  };
  response["entries"] = json::array();
  for (const auto raw_value : catalog.raw_values) {
    response["entries"].push_back({{"id", raw_value}});
  }
  std::cout << response.dump() << '\n';
  return 0;
}

const char* ObjectKindName(
    const starcraft_map_editor::starcraft_data::ObjectGraphicKind kind) {
  using starcraft_map_editor::starcraft_data::ObjectGraphicKind;
  return kind == ObjectGraphicKind::kUnit ? "unit" : "sprite";
}

int RenderObjectAtlas(
    const json& request,
    const std::string& request_id,
    const std::filesystem::path& installation_path) {
  namespace sc = starcraft_map_editor::starcraft_data;
  if (!request.contains("tileset") ||
      !request["tileset"].is_number_integer() ||
      !request.contains("objects") || !request["objects"].is_array() ||
      !IsNonEmptyString(request, "outputFileName") ||
      !IsNonEmptyString(request, "framePolicy")) {
    return WriteError(
        request_id,
        kRenderObjectOperation,
        "SC_CASC_PROTOCOL_INVALID_REQUEST",
        "The object atlas request is missing a required field.",
        "protocol",
        ERROR_INVALID_DATA,
        2);
  }

  const auto tileset_value = request["tileset"].get<std::int64_t>();
  if (tileset_value < 0 ||
      tileset_value >= static_cast<std::int64_t>(sc::kTilesetCount)) {
    return WriteError(
        request_id,
        kRenderObjectOperation,
        "SC_CASC_PROTOCOL_INVALID_TILESET",
        "The requested StarCraft tileset is not supported.",
        "protocol",
        ERROR_INVALID_DATA,
        2);
  }
  if (request["outputFileName"].get<std::string>() !=
          sc::kObjectAtlasFileName ||
      request["framePolicy"].get<std::string>() != sc::kObjectFramePolicy) {
    return WriteError(
        request_id,
        kRenderObjectOperation,
        "SC_CASC_PROTOCOL_INVALID_OBJECT_POLICY",
        "The object atlas output or frame policy is not supported.",
        "protocol",
        ERROR_NOT_SUPPORTED,
        2);
  }

  std::vector<sc::ObjectRenderRequest> objects;
  objects.reserve(request["objects"].size());
  for (const auto& value : request["objects"]) {
    if (!value.is_object() || !IsNonEmptyString(value, "kind") ||
        !value.contains("id") || !value["id"].is_number_integer() ||
        !value.contains("playerColor") || !value.contains("direction") ||
        !value["direction"].is_number_integer()) {
      return WriteError(
          request_id,
          kRenderObjectOperation,
          "SC_CASC_PROTOCOL_INVALID_OBJECTS",
          "An object atlas key is malformed.",
          "protocol",
          ERROR_INVALID_DATA,
          2);
    }

    sc::ObjectRenderRequest object;
    const auto kind = value["kind"].get<std::string>();
    if (kind == "unit") {
      object.kind = sc::ObjectGraphicKind::kUnit;
    } else if (kind == "sprite") {
      object.kind = sc::ObjectGraphicKind::kSprite;
    } else {
      return WriteError(
          request_id,
          kRenderObjectOperation,
          "SC_CASC_PROTOCOL_INVALID_OBJECTS",
          "An object atlas kind is not supported.",
          "protocol",
          ERROR_INVALID_DATA,
          2);
    }

    const auto object_id = value["id"].get<std::int64_t>();
    const auto direction = value["direction"].get<std::int64_t>();
    if (object_id < 0 || object_id > 0xffff ||
        direction != sc::kObjectPreviewDirection) {
      return WriteError(
          request_id,
          kRenderObjectOperation,
          "SC_CASC_PROTOCOL_INVALID_OBJECTS",
          "An object atlas ID or direction is not supported.",
          "protocol",
          ERROR_INVALID_DATA,
          2);
    }
    object.object_id = static_cast<std::uint16_t>(object_id);
    object.direction = static_cast<std::uint8_t>(direction);

    if (value["playerColor"].is_null()) {
      object.player_color = sc::kNeutralObjectPlayerColor;
    } else if (value["playerColor"].is_number_integer()) {
      const auto player_color = value["playerColor"].get<std::int64_t>();
      if (player_color < sc::kMinimumObjectPlayerColor ||
          player_color > sc::kMaximumObjectPlayerColor) {
        return WriteError(
            request_id,
            kRenderObjectOperation,
            "SC_CASC_PROTOCOL_INVALID_OBJECTS",
            "An object player color is not supported.",
            "protocol",
            ERROR_INVALID_DATA,
            2);
      }
      object.player_color = static_cast<std::uint8_t>(player_color);
    } else {
      return WriteError(
          request_id,
          kRenderObjectOperation,
          "SC_CASC_PROTOCOL_INVALID_OBJECTS",
          "An object player color is malformed.",
          "protocol",
          ERROR_INVALID_DATA,
          2);
    }
    objects.push_back(object);
  }
  if (!sc::ValidateObjectRenderRequests(objects)) {
    return WriteError(
        request_id,
        kRenderObjectOperation,
        "SC_CASC_PROTOCOL_INVALID_OBJECTS",
        "Object atlas keys must be sorted, unique, and bounded.",
        "protocol",
        ERROR_INVALID_DATA,
        2);
  }

  auto rendered = sc::RenderObjectAssets(
      installation_path,
      static_cast<std::uint32_t>(tileset_value),
      objects);
  if (!rendered.success) {
    return WriteError(
        request_id,
        kRenderObjectOperation,
        rendered.error_code,
        rendered.message,
        rendered.stage,
        rendered.native_error,
        3);
  }

  const auto atlas = sc::WriteObjectAtlas(
      std::filesystem::current_path(), rendered.entries);
  if (!atlas.success) {
    return WriteError(
        request_id,
        kRenderObjectOperation,
        atlas.error_code,
        atlas.message,
        atlas.stage,
        atlas.native_error,
        3);
  }

  auto response = BaseResponse(request_id, kRenderObjectOperation);
  response["status"] = "success";
  response["installation"] = {
      {"path", rendered.installation_path},
      {"storageProduct", rendered.storage_product},
      {"storageBuildNumber", rendered.storage_build_number},
  };
  response["tileset"] = tileset_value;
  response["assets"] = {
      {"readCount", rendered.read_asset_count},
      {"totalBytes", rendered.total_asset_bytes},
  };
  response["atlas"] = {
      {"fileName", sc::kObjectAtlasFileName},
      {"fileBytes", atlas.file_bytes},
      {"formatVersion", sc::kObjectAtlasFormatVersion},
      {"entryCount", atlas.entry_count},
      {"tileset", tileset_value},
  };
  response["unsupportedObjects"] = json::array();
  for (const auto& unsupported : rendered.unsupported_objects) {
    json player_color = nullptr;
    if (unsupported.request.player_color != sc::kNeutralObjectPlayerColor) {
      player_color = unsupported.request.player_color;
    }
    response["unsupportedObjects"].push_back({
        {"kind", ObjectKindName(unsupported.request.kind)},
        {"id", unsupported.request.object_id},
        {"playerColor", player_color},
        {"direction", unsupported.request.direction},
        {"code", unsupported.error_code},
    });
  }
  std::cout << response.dump() << '\n';
  return 0;
}

}  // namespace

int main() {
  SetErrorMode(
      SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX |
      SEM_NOOPENFILEERRORBOX);

  std::string request_text;
  char request_character = '\0';
  while (std::cin.get(request_character)) {
    if (request_character == '\n') {
      break;
    }
    if (request_character == '\r') {
      continue;
    }
    if (request_text.size() >= kMaximumRequestBytes) {
      return WriteError(
          "",
          "",
          "SC_CASC_PROTOCOL_REQUEST_TOO_LARGE",
          "The helper request exceeds the maximum supported size.",
          "protocol",
          ERROR_INSUFFICIENT_BUFFER,
          2);
    }
    request_text.push_back(request_character);
  }

  try {
    const auto request = json::parse(request_text);
    if (!request.is_object() ||
        !request.contains("protocolVersion") ||
        !request["protocolVersion"].is_number_integer() ||
        !IsNonEmptyString(request, "requestId") ||
        !IsNonEmptyString(request, "operation") ||
        !IsNonEmptyString(request, "installationPath")) {
      return WriteError(
          "",
          "",
          "SC_CASC_PROTOCOL_INVALID_REQUEST",
          "The helper request is missing a required field.",
          "protocol",
          ERROR_INVALID_DATA,
          2);
    }

    const auto request_id = request["requestId"].get<std::string>();
    const auto operation = request["operation"].get<std::string>();
    if (request["protocolVersion"].get<std::int32_t>() !=
        kProtocolVersion) {
      return WriteError(
          request_id,
          operation,
          "SC_CASC_PROTOCOL_VERSION_UNSUPPORTED",
          "The requested helper protocol version is not supported.",
          "protocol",
          ERROR_REVISION_MISMATCH,
          2);
    }
    if (operation != kInspectOperation && operation != kRenderOperation &&
        operation != kRenderObjectOperation &&
        operation != kListCatalogOperation) {
      return WriteError(
          request_id,
          operation,
          "SC_CASC_PROTOCOL_OPERATION_UNSUPPORTED",
          "The requested StarCraft data operation is not supported.",
          "protocol",
          ERROR_NOT_SUPPORTED,
          2);
    }
    if (request_id.size() > 128) {
      return WriteError(
          request_id,
          operation,
          "SC_CASC_PROTOCOL_REQUEST_ID_TOO_LONG",
          "The request ID exceeds the maximum supported length.",
          "protocol",
          ERROR_INVALID_DATA,
          2);
    }

    const auto installation_path = std::filesystem::u8path(
        request["installationPath"].get<std::string>());
    if (!installation_path.is_absolute()) {
      return WriteError(
          request_id,
          operation,
          "SC_CASC_INSTALLATION_PATH_INVALID",
          "The StarCraft installation path must be absolute.",
          "validate",
          ERROR_INVALID_NAME,
          2);
    }

    if (operation == kInspectOperation) {
      return InspectInstallation(request_id, installation_path);
    }
    if (operation == kRenderOperation) {
      return RenderTileAtlas(request, request_id, installation_path);
    }
    if (operation == kListCatalogOperation) {
      return ListPlacementCatalog(request, request_id, installation_path);
    }
    return RenderObjectAtlas(request, request_id, installation_path);
  } catch (const json::exception&) {
    return WriteError(
        "",
        "",
        "SC_CASC_PROTOCOL_INVALID_JSON",
        "The helper request is not valid JSON.",
        "protocol",
        ERROR_INVALID_DATA,
        2);
  } catch (const std::filesystem::filesystem_error&) {
    return WriteError(
        "",
        "",
        "SC_CASC_PATH_CONVERSION_FAILED",
        "A helper path could not be converted safely.",
        "validate",
        ERROR_INVALID_NAME,
        2);
  } catch (const std::exception&) {
    return WriteError(
        "",
        "",
        "SC_CASC_HELPER_UNEXPECTED_ERROR",
        "The StarCraft data helper encountered an unexpected error.",
        "helper",
        ERROR_UNHANDLED_EXCEPTION,
        4);
  }
}
