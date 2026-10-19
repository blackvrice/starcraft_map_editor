#include <windows.h>
#include <fcntl.h>
#include <io.h>
#include <cstdio>
#include <cstring>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
#include <nlohmann/json.hpp>

namespace {
template <typename T>
T Symbol(HMODULE lib, const char* name) {
  const auto address = GetProcAddress(lib, name);
  T value = nullptr;
  static_assert(sizeof(value) == sizeof(address));
  std::memcpy(&value, &address, sizeof(value));
  return value;
}
constexpr size_t kMaxInput = 6 * 1024 * 1024;
constexpr size_t kMaxSource = 4 * 1024 * 1024;
constexpr size_t kMaxOutput = 4 * 1024 * 1024;

std::wstring LibraryPath() {
  std::vector<wchar_t> path(32768);
  const DWORD count = GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
  if (!count || count >= path.size()) throw std::runtime_error("EUD_TRANSLATE_PATH");
  std::wstring base(path.data(), count);
  return base.substr(0, base.find_last_of(L"\\/")) +
      L"\\tools\\euddraft\\0.10.2.5-editor.1\\libepScriptLib.dll";
}

// A conservative public-name inventory. Unknown external APIs fail compilation
// instead of being invented or importing/executing a user's module.
constexpr char kGlobals[] =
    "Add\0Subtract\0SetTo\0AtLeast\0AtMost\0Exactly\0Ore\0Gas\0OreAndGas\0"
    "P1\0P2\0P3\0P4\0P5\0P6\0P7\0P8\0P9\0P10\0P11\0P12\0"
    "CurrentPlayer\0AllPlayers\0Force1\0Force2\0Force3\0Force4\0All\0"
    "Enable\0Disable\0Toggle\0Set\0Clear\0Random\0Ally\0Enemy\0AlliedVictory\0"
    "Move\0Patrol\0Attack\0Total\0Units\0Buildings\0UnitsAndBuildings\0Kills\0Razings\0KillsAndRazings\0Custom\0"
    "EUDVariable\0EUDLightVariable\0EUDLightBool\0EUDArray\0EUDVArray\0EUDCreateVariables\0"
    "EUDLoopUnit\0EUDLoopPlayerUnit\0EUDPlayerLoop\0EUDLoopPlayer\0"
    "SetMemory\0SetMemoryX\0Memory\0MemoryX\0MemoryEPD\0MemoryXEPD\0"
    "SetMemoryEPD\0SetMemoryXEPD\0EPD\0DoActions\0RawTrigger\0Trigger\0"
    "dwread_epd\0dwwrite_epd\0dwadd_epd\0dwsubtract_epd\0f_dwread_epd\0f_dwwrite_epd\0"
    "f_dwread\0f_dwwrite\0f_bread\0f_bwrite\0f_wread\0f_wwrite\0"
    "f_getcurpl\0f_setcurpl\0f_addcurpl\0f_getuserplayerid\0"
    "StringBuffer\0Db\0Forward\0EncodeUnit\0EncodeLocation\0EncodePlayer\0"
    "TrgUnit\0Weapon\0Flingy\0Upgrade\0Tech\0TrgPlayer\0Sprite\0Image\0"
    "UnitProperty\0CreateUnit\0CreateUnitWithProperties\0SetDeaths\0SetDeathsX\0"
    "Always\0Never\0Command\0Bring\0Accumulate\0Deaths\0DeathsX\0Switch\0"
    "ElapsedTime\0CountdownTimer\0Score\0Kills\0Opponents\0"
    "DisplayText\0PlayWAV\0CenterView\0PingMinimap\0SetResources\0SetScore\0SetSwitch\0"
    "SetCountdownTimer\0SetInvincibility\0SetDoodadState\0SetAllianceStatus\0SetMissionObjectives\0"
    "KillUnit\0KillUnitAt\0RemoveUnit\0RemoveUnitAt\0MoveUnit\0MoveLocation\0GiveUnits\0Order\0"
    "ModifyUnitHitPoints\0ModifyUnitEnergy\0ModifyUnitShields\0ModifyUnitResourceAmount\0ModifyUnitHangarCount\0"
    "SetNextScenario\0RunAIScript\0RunAIScriptAt\0Victory\0Defeat\0Draw\0PreserveTrigger\0Comment\0"
    "MuteUnitSpeech\0UnMuteUnitSpeech\0PauseGame\0UnpauseGame\0PauseTimer\0UnpauseTimer\0"
    "EUDIf\0EUDElse\0EUDElseIf\0EUDEndIf\0EUDWhile\0EUDEndWhile\0"
    "EUDFunc\0EUDReturn\0EUDContinue\0EUDBreak\0EUDExecuteOnce\0EUDEndExecuteOnce\0";
constexpr char kPythonKeywords[] =
    "False\0None\0True\0and\0as\0assert\0async\0await\0break\0class\0continue\0"
    "def\0del\0elif\0else\0except\0finally\0for\0from\0global\0if\0import\0in\0"
    "is\0lambda\0nonlocal\0not\0or\0pass\0raise\0return\0try\0while\0with\0yield\0";
constexpr char kPythonBuiltins[] =
    "abs\0all\0any\0ascii\0bin\0bool\0bytearray\0bytes\0callable\0chr\0"
    "dict\0dir\0divmod\0enumerate\0filter\0float\0format\0frozenset\0getattr\0"
    "globals\0hasattr\0hash\0hex\0id\0int\0isinstance\0issubclass\0iter\0len\0"
    "list\0locals\0map\0max\0memoryview\0min\0next\0object\0oct\0ord\0pow\0"
    "print\0range\0repr\0reversed\0round\0set\0setattr\0slice\0sorted\0str\0sum\0tuple\0type\0vars\0zip\0";
}

int main() {
  _setmode(_fileno(stdin), _O_BINARY);
  _setmode(_fileno(stdout), _O_BINARY);
  try {
    std::string input;
    char c;
    while (std::cin.get(c)) {
      if (input.size() >= kMaxInput) throw std::runtime_error("EUD_TRANSLATE_SIZE");
      input.push_back(c);
    }
    const auto request = nlohmann::json::parse(input);
    const auto source = request.at("source").get<std::string>();
    if (source.size() > kMaxSource || source.find('\0') != std::string::npos) {
      throw std::runtime_error("EUD_TRANSLATE_SIZE");
    }
    // Only the adjacent managed bundle can be loaded, never a request path or
    // a PATH-resolved library. Dart verifies its pinned manifest before spawn.
    const HMODULE lib = LoadLibraryExW(LibraryPath().c_str(), nullptr,
        LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (!lib) throw std::runtime_error("EUD_TRANSLATE_LIBRARY");
    const auto compile = Symbol<char* (__cdecl*)(const char*, const char*)>(lib, "compileString");
    const auto release = Symbol<void (__cdecl*)(void*)>(lib, "freeCompiledResult");
    const auto errors = Symbol<int (__cdecl*)()>(lib, "getErrorCount");
    const auto globals = Symbol<void (__cdecl*)(const char*)>(lib, "registerPlibConstants");
    const auto keywords = Symbol<void (__cdecl*)(const char*)>(lib, "registerPyKeywords");
    const auto builtins = Symbol<void (__cdecl*)(const char*)>(lib, "registerPyBuiltins");
    if (!compile || !release || !errors || !globals || !keywords || !builtins) throw std::runtime_error("EUD_TRANSLATE_ABI");
    globals(kGlobals);
    keywords(kPythonKeywords);
    builtins(kPythonBuiltins);
    // epScript writes diagnostics to stdout. Keep the JSON channel separate.
    fflush(stdout);
    const int saved = _dup(_fileno(stdout));
    if (saved < 0 || _dup2(_fileno(stderr), _fileno(stdout)) != 0) {
      throw std::runtime_error("EUD_TRANSLATE_CHANNEL");
    }
    char* result = compile("editor_source.eps", source.c_str());
    const int error_count = errors();
    fflush(stdout);
    _dup2(saved, _fileno(stdout));
    _close(saved);
    nlohmann::json response = {{"protocol", 1}, {"toolVersion", "euddraft-0.10.2.5/epScript"},
                              {"sourceExecution", 0}, {"errors", error_count}};
    if (result) {
      const size_t length = strnlen_s(result, kMaxOutput + 1);
      if (length > kMaxOutput) {
        release(result);
        throw std::runtime_error("EUD_TRANSLATE_SIZE");
      }
      if (!error_count) response["source"] = std::string(result, length);
      release(result);
    }
    FreeLibrary(lib);
    std::cout << response.dump() << std::endl;
    return error_count || !response.contains("source") ? 1 : 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << std::endl;
    return 2;
  }
}
