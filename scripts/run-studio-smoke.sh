#!/usr/bin/env bash
# MoUI Studio platform smoke: builds and runs the first-frame smoke for
# linux_skia and windows_skia entries. Requires the respective platform.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLATFORM="${1:-linux}"
ENTRY="moui_studio/${PLATFORM}_skia"
echo "=== MoUI Studio ${PLATFORM} smoke ==="
cd "$REPO_ROOT"
MOUI_FIRST_FRAME_EXIT=1 moon run "$ENTRY" --target native
echo "=== smoke passed ==="
