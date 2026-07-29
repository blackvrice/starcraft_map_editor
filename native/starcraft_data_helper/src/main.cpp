#include "casc_asset_inspector.h"

#include <Windows.h>

#include <nlohmann/json.hpp>

#include <cstdint>
#include <filesystem>
#include <iostream>
#include <string>

namespace {

using json = nlohmann::json;

constexpr std::int32_t kProtocolVersion = 1;
constexpr std::size_t kMaximumRequestBytes = 64 * 1024;
constexpr char kOperation[] = "inspectInstallation";
constexpr char kHelperVersion[] = "0.1.0";
constexpr char kCascLibRevision[] =
    "4971d363e665551ac4142f541e5f2d71f1cda653";

json BaseResponse(const std::string& request_id) {
  return {
      {"protocolVersion", kProtocolVersion},
      {"requestId", request_id},
      {"operation", kOperation},
      {"helperVersion", kHelperVersion},
      {"cascLibRevision", kCascLibRevision},
  };
}

int WriteError(
    const std::string& request_id,
    const std::string& code,
    const std::string& message,
    const std::string& stage,
    const std::uint32_t native_error,
    const int exit_code) {
  auto response = BaseResponse(request_id);
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
  return value.contains(key) &&
         value[key].is_string() &&
         !value[key].get_ref<const std::string&>().empty();
}

}  // namespace

int main() {
  SetErrorMode(
      SEM_FAILCRITICALERRORS |
      SEM_NOGPFAULTERRORBOX |
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
          "SC_CASC_PROTOCOL_VERSION_UNSUPPORTED",
          "The requested helper protocol version is not supported.",
          "protocol",
          ERROR_REVISION_MISMATCH,
          2);
    }
    if (operation != kOperation) {
      return WriteError(
          request_id,
          "SC_CASC_PROTOCOL_OPERATION_UNSUPPORTED",
          "The requested StarCraft data operation is not supported.",
          "protocol",
          ERROR_NOT_SUPPORTED,
          2);
    }
    if (request_id.size() > 128) {
      return WriteError(
          request_id,
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
          "SC_CASC_INSTALLATION_PATH_INVALID",
          "The StarCraft installation path must be absolute.",
          "validate",
          ERROR_INVALID_NAME,
          2);
    }

    const auto result =
        starcraft_map_editor::starcraft_data::InspectInstallation(
            installation_path);
    if (!result.success) {
      return WriteError(
          request_id,
          result.error_code,
          result.message,
          result.stage,
          result.native_error,
          3);
    }

    auto response = BaseResponse(request_id);
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
  } catch (const json::exception&) {
    return WriteError(
        "",
        "SC_CASC_PROTOCOL_INVALID_JSON",
        "The helper request is not valid JSON.",
        "protocol",
        ERROR_INVALID_DATA,
        2);
  } catch (const std::filesystem::filesystem_error&) {
    return WriteError(
        "",
        "SC_CASC_PATH_CONVERSION_FAILED",
        "The StarCraft installation path could not be converted safely.",
        "validate",
        ERROR_INVALID_NAME,
        2);
  } catch (const std::exception&) {
    return WriteError(
        "",
        "SC_CASC_HELPER_UNEXPECTED_ERROR",
        "The StarCraft data helper encountered an unexpected error.",
        "helper",
        ERROR_UNHANDLED_EXCEPTION,
        4);
  }
}
