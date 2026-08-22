cmake_minimum_required(VERSION 3.25)

include(FetchContent)

option(
  STARCRAFT_DATA_ALLOW_CASCLIB_UPDATES
  "Allow FetchContent to update the pinned CascLib checkout"
  OFF
)
if(STARCRAFT_DATA_ALLOW_CASCLIB_UPDATES)
  set(FETCHCONTENT_UPDATES_DISCONNECTED_CASCLIB OFF)
else()
  set(FETCHCONTENT_UPDATES_DISCONNECTED_CASCLIB ON)
endif()

set(CASC_BUILD_SHARED_LIB OFF CACHE BOOL "Do not build CascLib DLL" FORCE)
set(CASC_BUILD_STATIC_LIB ON CACHE BOOL "Build static CascLib" FORCE)
set(CASC_BUILD_TESTS OFF CACHE BOOL "Do not build upstream CascLib tests" FORCE)
set(CASC_UNICODE ON CACHE BOOL "Use Unicode Windows storage paths" FORCE)
set(JSON_BuildTests OFF CACHE INTERNAL "Do not build upstream JSON tests")

FetchContent_Declare(
  casclib
  GIT_REPOSITORY https://github.com/ladislav-zezula/CascLib.git
  GIT_TAG 4971d363e665551ac4142f541e5f2d71f1cda653
  GIT_SHALLOW FALSE
)

FetchContent_Declare(
  nlohmann_json
  GIT_REPOSITORY https://github.com/nlohmann/json.git
  GIT_TAG 55f93686c01528224f448c19128836e7df245f72
  GIT_SHALLOW FALSE
)

set(CMAKE_POLICY_VERSION_MINIMUM 3.10)
cmake_policy(SET CMP0169 OLD)
FetchContent_GetProperties(casclib)
if(NOT casclib_POPULATED)
  FetchContent_Populate(casclib)
  add_subdirectory(
    "${casclib_SOURCE_DIR}"
    "${casclib_BINARY_DIR}"
    EXCLUDE_FROM_ALL
  )
endif()
FetchContent_MakeAvailable(nlohmann_json)

add_library(starcraft_data_core STATIC
  src/casc_asset_inspector.cpp
  src/casc_asset_inspector.h
  src/doodad_recipe_decoder.cpp
  src/doodad_recipe_decoder.h
  src/object_asset_reader.cpp
  src/object_asset_reader.h
  src/object_atlas_protocol.cpp
  src/object_atlas_protocol.h
  src/object_grp_decoder.cpp
  src/object_grp_decoder.h
  src/object_palette_decoder.cpp
  src/object_palette_decoder.h
  src/object_sprite_reference.cpp
  src/object_sprite_reference.h
  src/tile_atlas_protocol.cpp
  src/tile_atlas_protocol.h
  src/tileset_asset_reader.cpp
  src/tileset_asset_reader.h
  src/tileset_tile_decoder.cpp
  src/tileset_tile_decoder.h
)
target_compile_features(starcraft_data_core PUBLIC cxx_std_17)
target_compile_definitions(
  starcraft_data_core
  PRIVATE
    NOMINMAX
    WIN32_LEAN_AND_MEAN
)
target_compile_options(
  starcraft_data_core
  PRIVATE
    /W4
    /WX
    /EHsc
    /utf-8
)
target_link_libraries(starcraft_data_core PUBLIC casc_static)
target_include_directories(
  starcraft_data_core
  PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
)

add_executable(starcraft_data_helper src/main.cpp)
target_compile_features(starcraft_data_helper PRIVATE cxx_std_17)
target_compile_definitions(
  starcraft_data_helper
  PRIVATE
    NOMINMAX
    WIN32_LEAN_AND_MEAN
)
target_compile_options(
  starcraft_data_helper
  PRIVATE
    /W4
    /WX
    /EHsc
    /utf-8
)
target_link_libraries(
  starcraft_data_helper
  PRIVATE
    starcraft_data_core
    nlohmann_json::nlohmann_json
)

enable_testing()
add_executable(
  starcraft_data_helper_native_test
  test/casc_asset_inspector_test.cpp
)
target_compile_features(
  starcraft_data_helper_native_test
  PRIVATE
    cxx_std_17
)
target_compile_definitions(
  starcraft_data_helper_native_test
  PRIVATE
    NOMINMAX
    WIN32_LEAN_AND_MEAN
)
target_compile_options(
  starcraft_data_helper_native_test
  PRIVATE
    /W4
    /WX
    /EHsc
    /utf-8
)
target_link_libraries(
  starcraft_data_helper_native_test
  PRIVATE
    starcraft_data_core
)

add_test(
  NAME starcraft_data_helper_native
  COMMAND starcraft_data_helper_native_test
)

add_executable(
  starcraft_object_reference_native_test
  test/object_sprite_reference_test.cpp
)
target_compile_features(
  starcraft_object_reference_native_test
  PRIVATE
    cxx_std_17
)
target_compile_definitions(
  starcraft_object_reference_native_test
  PRIVATE
    NOMINMAX
    WIN32_LEAN_AND_MEAN
)
target_compile_options(
  starcraft_object_reference_native_test
  PRIVATE
    /W4
    /WX
    /EHsc
    /utf-8
)
target_link_libraries(
  starcraft_object_reference_native_test
  PRIVATE
    starcraft_data_core
)

add_test(
  NAME starcraft_object_reference_native
  COMMAND starcraft_object_reference_native_test
)

add_executable(
  starcraft_object_graphics_native_test
  test/object_graphics_test.cpp
)
target_compile_features(
  starcraft_object_graphics_native_test
  PRIVATE
    cxx_std_17
)
target_compile_definitions(
  starcraft_object_graphics_native_test
  PRIVATE
    NOMINMAX
    WIN32_LEAN_AND_MEAN
)
target_compile_options(
  starcraft_object_graphics_native_test
  PRIVATE
    /W4
    /WX
    /EHsc
    /utf-8
)
target_link_libraries(
  starcraft_object_graphics_native_test
  PRIVATE
    starcraft_data_core
)

add_test(
  NAME starcraft_object_graphics_native
  COMMAND starcraft_object_graphics_native_test
)

add_executable(
  starcraft_doodad_recipe_native_test
  test/doodad_recipe_decoder_test.cpp
)
target_compile_features(
  starcraft_doodad_recipe_native_test
  PRIVATE
    cxx_std_17
)
target_compile_definitions(
  starcraft_doodad_recipe_native_test
  PRIVATE
    NOMINMAX
    WIN32_LEAN_AND_MEAN
)
target_compile_options(
  starcraft_doodad_recipe_native_test
  PRIVATE
    /W4
    /WX
    /EHsc
    /utf-8
)
target_link_libraries(
  starcraft_doodad_recipe_native_test
  PRIVATE
    starcraft_data_core
)

add_test(
  NAME starcraft_doodad_recipe_native
  COMMAND starcraft_doodad_recipe_native_test
)

install(
  TARGETS starcraft_data_helper
  RUNTIME DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime
)
install(
  FILES "${CMAKE_CURRENT_SOURCE_DIR}/THIRD_PARTY_NOTICES.md"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}/licenses/StarCraftDataHelper"
  COMPONENT Runtime
)
install(
  FILES "${casclib_SOURCE_DIR}/LICENSE"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}/licenses/CascLib"
  COMPONENT Runtime
)
install(
  FILES
    "${casclib_SOURCE_DIR}/src/hashes/md5.h"
    "${casclib_SOURCE_DIR}/src/hashes/sha1.h"
    "${casclib_SOURCE_DIR}/src/overwatch/aes.h"
    "${casclib_SOURCE_DIR}/src/zlib/zlib.h"
  DESTINATION
    "${INSTALL_BUNDLE_DATA_DIR}/licenses/CascLib/bundled-notices"
  COMPONENT Runtime
)
