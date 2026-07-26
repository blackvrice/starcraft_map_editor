cmake_minimum_required(VERSION 3.25)

include(FetchContent)

set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build static third-party libraries" FORCE)
set(STORM_SKIP_INSTALL ON CACHE BOOL "Do not install StormLib targets" FORCE)
set(STORM_USE_BUNDLED_LIBRARIES ON CACHE BOOL "Use pinned bundled codecs" FORCE)
set(STORM_BUILD_TESTS OFF CACHE BOOL "Do not build upstream StormLib tests" FORCE)
set(STORM_UNICODE ON CACHE BOOL "Build StormLib with Unicode paths" FORCE)
set(JSON_BuildTests OFF CACHE INTERNAL "Do not build upstream JSON tests")

FetchContent_Declare(
  stormlib
  GIT_REPOSITORY https://github.com/ladislav-zezula/StormLib.git
  GIT_TAG c91595a1a1b7b515567bd62a60af066914a29a6a
  GIT_SHALLOW FALSE
)

FetchContent_Declare(
  nlohmann_json
  GIT_REPOSITORY https://github.com/nlohmann/json.git
  GIT_TAG 55f93686c01528224f448c19128836e7df245f72
  GIT_SHALLOW FALSE
)

FetchContent_MakeAvailable(stormlib nlohmann_json)

add_library(map_archive_core STATIC
  src/archive_extractor.cpp
  src/archive_extractor.h
)
target_compile_features(map_archive_core PUBLIC cxx_std_17)
target_compile_definitions(map_archive_core PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
target_compile_options(map_archive_core PRIVATE /W4 /WX /EHsc /utf-8)
target_link_libraries(map_archive_core PUBLIC StormLib::storm)
target_include_directories(map_archive_core PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/src")

add_executable(map_archive_helper src/main.cpp)
target_compile_features(map_archive_helper PRIVATE cxx_std_17)
target_compile_definitions(map_archive_helper PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
target_compile_options(map_archive_helper PRIVATE /W4 /WX /EHsc /utf-8)
target_link_libraries(map_archive_helper
  PRIVATE
    map_archive_core
    nlohmann_json::nlohmann_json
)

enable_testing()
add_executable(map_archive_helper_native_test
  test/archive_extractor_test.cpp
)
target_compile_features(map_archive_helper_native_test PRIVATE cxx_std_17)
target_compile_definitions(
  map_archive_helper_native_test
  PRIVATE
    NOMINMAX
    WIN32_LEAN_AND_MEAN
)
target_compile_options(
  map_archive_helper_native_test
  PRIVATE
    /W4
    /WX
    /EHsc
    /utf-8
)
target_link_libraries(map_archive_helper_native_test PRIVATE map_archive_core)

add_test(
  NAME map_archive_helper_native
  COMMAND map_archive_helper_native_test
)

install(
  TARGETS map_archive_helper
  RUNTIME DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime
)
install(
  FILES "${CMAKE_CURRENT_SOURCE_DIR}/THIRD_PARTY_NOTICES.md"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}/licenses"
  COMPONENT Runtime
)
install(
  FILES "${CMAKE_SOURCE_DIR}/../LICENSE"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}/licenses/StarCraftMapEditor"
  COMPONENT Runtime
)
install(
  FILES "${stormlib_SOURCE_DIR}/LICENSE"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}/licenses/StormLib"
  COMPONENT Runtime
)
install(
  FILES "${nlohmann_json_SOURCE_DIR}/LICENSE.MIT"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}/licenses/nlohmann-json"
  COMPONENT Runtime
)
