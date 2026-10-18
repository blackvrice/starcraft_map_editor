cmake_minimum_required(VERSION 3.25)
project(trigger_script_syntax C)

# Developer-only syntax oracle; never linked into or shipped with the editor.
include(FetchContent)
FetchContent_Declare(lua_syntax
  URL https://www.lua.org/ftp/lua-5.4.9.tar.gz
  URL_HASH SHA256=2335b6c582a52654f94612bf10d2f4672805d05329aa6568b1d8cd9e5c6fb8e6)
FetchContent_MakeAvailable(lua_syntax)
file(GLOB lua_sources CONFIGURE_DEPENDS "${lua_syntax_SOURCE_DIR}/src/*.c")
list(REMOVE_ITEM lua_sources "${lua_syntax_SOURCE_DIR}/src/lua.c"
  "${lua_syntax_SOURCE_DIR}/src/luac.c")
add_library(lua_syntax_core STATIC ${lua_sources})
add_executable(luac "${lua_syntax_SOURCE_DIR}/src/luac.c")
target_link_libraries(luac PRIVATE lua_syntax_core)
if(UNIX)
  target_link_libraries(luac PRIVATE m ${CMAKE_DL_LIBS})
endif()
