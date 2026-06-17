#!/usr/bin/env bash
#
# Launch the agent_counter in a REAL on-screen macOS window, with an MCP
# server running CONCURRENTLY over stdio — so an agent can drive the counter
# while you watch the count change on screen in real time.
#
# This is the live "user sees the agent's actions" path. Physical screenshot
# capture is blocked by macOS TCC screen-recording permission in automated
# environments; this concurrent window+server is the human-eyeball path.
#
# Usage:
#   ./scripts/run-agent-counter-windowed.sh
#
# The window opens and the MCP server reads JSON-RPC lines from stdin. From
# another terminal, pipe an agent click and watch the window's count change:
#   echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"dispatch_event","arguments":{"event":{"kind":"Pointer","position":{"x":100,"y":106},"phase":"Down"}}}}' \
#     | _build/native/debug/build/examples/agent_counter/macos_skia/macos_skia.exe
# (send phase "Up" as well to fire the button's on_click; the window updates live.)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$REPO_ROOT/_build/native/debug/build/examples/agent_counter/macos_skia/macos_skia.exe"

if [ ! -x "$BIN" ]; then
  echo "Building windowed agent_counter (macos_skia)..." >&2
  (cd "$REPO_ROOT" && moon build examples/agent_counter/macos_skia --target native)
fi

echo "Launching windowed MoUI Agent Counter (window + concurrent MCP server): $BIN" >&2
echo "The window opens; drive it over stdio MCP — the count updates on screen live." >&2
exec "$BIN"
