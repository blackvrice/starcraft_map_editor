#include "archive_extractor.h"

#include <Windows.h>

#include <nlohmann/json.hpp>

#include <cstdint>
#include <filesystem>
#include <iostream>
#include <string>
#include <system_error>
#include <utility>

namespace {

using json = nlohmann::json;

constexpr std::int32_t kProtocolVersion = 1;
constexpr std::size_t kMaximumRequestBytes = 64 * 1024;
constexpr char kHelperVersion[] = "0.2.0";
constexpr char kStormLibRevision[] =
    "c91595a1a1b7b515567bd62a60af066914a29a6a";

json BaseResponse(
    const std::string& request_id,
    const std::string& operation) {
  return {
      {"protocolVersion", kProtocolVersion},
      {"requestId", request_id},
      {"operation", operation},
      {"helperVersion", kHelperVersion},
      {"stormLibRevision", kStormLibRevision},
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
  return value.contains(key) &&
         value[key].is_string() &&
         !value[key].get_ref<const std::string&>().empty();
}

bool IsOutputInsideWorkingDirectory(
    const std::filesystem::path& output_path) {
  std::error_code error;
  const auto working_directory = std::filesystem::canonical(
      std::filesystem::current_path(error),
      error);
  if (error) {
    return false;
  }

  const auto output_parent = std::filesystem::canonical(
      output_path.parent_path(),
      error);
  if (error) {
    return false;
  }

  return std::filesystem::equivalent(
      working_directory,
      output_parent,
      error) &&
      !error;
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
          "",
          "ARCHIVE_PROTOCOL_REQUEST_TOO_LARGE",
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
        !IsNonEmptyString(request, "sourcePath") ||
        !IsNonEmptyString(request, "scenarioOutputPath")) {
      return WriteError(
          "",
          "",
          "ARCHIVE_PROTOCOL_INVALID_REQUEST",
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
          "ARCHIVE_PROTOCOL_VERSION_UNSUPPORTED",
          "The requested helper protocol version is not supported.",
          "protocol",
          ERROR_REVISION_MISMATCH,
          2);
    }
    if (operation != "extractScenario") {
      return WriteError(
          request_id,
          operation,
          "ARCHIVE_PROTOCOL_OPERATION_UNSUPPORTED",
          "The requested archive operation is not supported.",
          "protocol",
          ERROR_NOT_SUPPORTED,
          2);
    }
    if (request_id.size() > 128) {
      return WriteError(
          request_id,
          operation,
          "ARCHIVE_PROTOCOL_REQUEST_ID_TOO_LONG",
          "The request ID exceeds the maximum supported length.",
          "protocol",
          ERROR_INVALID_DATA,
          2);
    }

    const auto source_path = std::filesystem::u8path(
        request["sourcePath"].get<std::string>());
    const auto output_path = std::filesystem::u8path(
        request["scenarioOutputPath"].get<std::string>());
    if (!source_path.is_absolute() ||
        !output_path.is_absolute() ||
        !IsOutputInsideWorkingDirectory(output_path)) {
      return WriteError(
          request_id,
          operation,
          "ARCHIVE_PATH_NOT_ALLOWED",
          "The request contains a path outside the allowed boundary.",
          "validate",
          ERROR_ACCESS_DENIED,
          2);
    }

    const auto result = starcraft_map_editor::archive::ExtractScenario(
        source_path,
        output_path);
    if (!result.success) {
      return WriteError(
          request_id,
          operation,
          result.error_code,
          result.message,
          result.stage,
          result.native_error,
          3);
    }

    auto response = BaseResponse(request_id, operation);
    response["status"] = "success";
    auto entries = json::array();
    for (const auto& entry : result.archive.entries) {
      entries.push_back({
          {"path", entry.path},
          {"uncompressedSizeBytes", entry.uncompressed_size_bytes},
          {"compressedSizeBytes", entry.compressed_size_bytes},
          {"flags", entry.flags},
          {"locale", entry.locale},
          {"nameIsSynthetic", entry.name_is_synthetic},
      });
    }
    response["archive"] = {
        {"sizeBytes", result.archive.archive_size_bytes},
        {"formatVersion", result.archive.format_version},
        {"totalEntryCount", result.archive.total_entry_count},
        {"listingComplete", result.archive.listing_complete},
        {"listingNativeError",
         result.archive.listing_complete
             ? json(nullptr)
             : json(result.archive.listing_native_error)},
        {"entries", std::move(entries)},
    };
    response["scenario"] = {
        {"archivePath",
         starcraft_map_editor::archive::kScenarioArchivePath},
        {"uncompressedSizeBytes",
         result.scenario.uncompressed_size_bytes},
        {"compressedSizeBytes",
         result.scenario.compressed_size_bytes},
    };
    std::cout << response.dump() << '\n';
    return 0;
  } catch (const json::exception&) {
    return WriteError(
        "",
        "",
        "ARCHIVE_PROTOCOL_INVALID_JSON",
        "The helper request is not valid JSON.",
        "protocol",
        ERROR_INVALID_DATA,
        2);
  } catch (const std::filesystem::filesystem_error&) {
    return WriteError(
        "",
        "",
        "ARCHIVE_PATH_CONVERSION_FAILED",
        "A request path could not be converted safely.",
        "validate",
        ERROR_INVALID_NAME,
        2);
  } catch (const std::exception&) {
    return WriteError(
        "",
        "",
        "ARCHIVE_HELPER_UNEXPECTED_ERROR",
        "The archive helper encountered an unexpected error.",
        "helper",
        ERROR_UNHANDLED_EXCEPTION,
        4);
  }
}
