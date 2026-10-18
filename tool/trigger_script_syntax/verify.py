"""Developer-only syntax oracles. Parse generated fixtures; never execute them."""
import argparse
import ast
import ctypes
import json
import subprocess
import sys

parser = argparse.ArgumentParser()
parser.add_argument("--eps-dll", required=True)
parser.add_argument("--luac", required=True)
args = parser.parse_args()
request = json.load(sys.stdin)
ast.parse(request["python"], mode="exec")
library = ctypes.CDLL(args.eps_dll)
library.compileString.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
library.compileString.restype = ctypes.c_void_p
library.freeCompiledResult.argtypes = [ctypes.c_void_p]
library.getErrorCount.restype = ctypes.c_int
library.registerPlibConstants.argtypes = [ctypes.c_char_p]
library.registerPlibConstants(b"\0".join(n.encode("ascii") for n in request["apis"]) + b"\0")
result = library.compileString(b"editor_declarations.eps", request["epScript"].encode("utf-8"))
try:
    if not result or library.getErrorCount():
        raise SyntaxError("Upstream epScript syntax check failed")
    ast.parse(ctypes.string_at(result).decode("utf-8"), mode="exec")
finally:
    if result:
        library.freeCompiledResult(result)
lua = subprocess.run([args.luac, "-p", "-"], input=request["lua"].encode("utf-8"),
                     capture_output=True, timeout=5, check=False)
if lua.returncode:
    raise SyntaxError(lua.stderr.decode("utf-8", errors="replace"))
print(json.dumps({"python": "ast.parse", "epScript": "compileString + ast.parse",
                  "lua": "luac -p", "sourceExecution": 0}))
