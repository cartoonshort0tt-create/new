#!/usr/bin/env bash
# Runs every test file with plain Lua 5.3 (each in its own process --
# mock_roblox.lua's workspace/ReplicatedStorage are process-wide
# singletons, so tests can't share a process). Requires lua5.3.
#
# This is a Lua-level simulation of the game's logic (see tests/README.md)
# -- not a substitute for an actual Roblox Studio playtest.

set -euo pipefail
cd "$(dirname "$0")/.."

LUA=${LUA:-lua5.3}
failures=0

for test_file in tests/test_*.lua; do
	echo "=== $test_file ==="
	if ! "$LUA" "$test_file"; then
		failures=$((failures + 1))
	fi
	echo
done

if [ "$failures" -gt 0 ]; then
	echo "$failures test file(s) failed."
	exit 1
fi

echo "All test files passed."
