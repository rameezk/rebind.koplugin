#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if command -v luajit >/dev/null 2>&1; then
    exec luajit tests/run.lua
elif command -v lua5.1 >/dev/null 2>&1; then
    exec lua5.1 tests/run.lua
elif command -v lua >/dev/null 2>&1; then
    exec lua tests/run.lua
elif command -v nix >/dev/null 2>&1; then
    exec nix run nixpkgs#luajit -- tests/run.lua
else
    echo "No Lua interpreter found (need luajit or lua 5.1)." >&2
    exit 1
fi
