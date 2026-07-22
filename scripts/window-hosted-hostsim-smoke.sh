#!/usr/bin/env bash
# Host-sim gate for window-hosted MoUI mobile path (no real emulator required).
# For device/VM evidence, use scripts/window-hosted-vm-smoke.sh when available.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export MOUI_SKIA_DISABLE_PREBUILD_SKIA="${MOUI_SKIA_DISABLE_PREBUILD_SKIA:-1}"

echo "== window android hosted smoke =="
moon test window/modules/window/android --target native

echo "== window ios hosted smoke =="
moon test window/modules/window/ios --target native

echo "== window harmonyos hosted smoke =="
moon test window/modules/window/harmonyos --target native

echo "== moui backend window-hosted tests =="
moon test moui/backend/android --target native
moon test moui/backend/ios --target native
moon test moui/backend/harmonyos --target native

echo "== counter window-hosted package check =="
moon check examples/counter/android_window_hosted --target native
moon check examples/counter/ios_window_hosted --target native
moon check examples/counter/harmonyos_window_hosted --target native

echo "window-hosted host-sim smoke: ok"
