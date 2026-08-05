#!/usr/bin/env bash
# Host-sim gate for window-hosted MoUI mobile path (no real emulator required).
# For device/VM evidence, use scripts/window-hosted-vm-smoke.sh when available.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export MOUI_SKIA_DISABLE_PREBUILD_SKIA="${MOUI_SKIA_DISABLE_PREBUILD_SKIA:-1}"

WINDOW_PACKAGE_ROOT="$ROOT/window/modules/window"
tmp_dir=""
cleanup() {
  if [ -n "$tmp_dir" ]; then
    rm -rf "$tmp_dir"
  fi
}
trap cleanup EXIT

if grep -qF '  "./window/modules/window",' "$ROOT/moon.work" && \
  grep -qF '  "./window/modules/windowing",' "$ROOT/moon.work"; then
  echo "== window hostsim source: local dev workspace =="
else
  window_version="${MOUI_WINDOW_VERSION:-$(node "$ROOT/scripts/window-dependency-info.mjs" --print-version)}"
  window_zip="${MOUI_WINDOW_PACKAGE_ZIP:-$HOME/.moon/registry/cache/wzzc-dev/window/${window_version}.zip}"
  if [ ! -f "$window_zip" ]; then
    printf 'wzzc-dev/window@%s package cache not found: %s\n' "$window_version" "$window_zip" >&2
    printf 'Run moon update from %s, then retry.\n' "$ROOT" >&2
    exit 1
  fi
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/moui-window-hostsim.XXXXXX")"
  WINDOW_PACKAGE_ROOT="$tmp_dir/window"
  unzip -q "$window_zip" -d "$WINDOW_PACKAGE_ROOT"
  echo "== window hostsim source: wzzc-dev/window@${window_version} registry package =="
fi

(
  cd "$WINDOW_PACKAGE_ROOT"

  echo "== window android hosted smoke =="
  moon test android --target native

  echo "== window ios hosted smoke =="
  moon test ios --target native

  echo "== window harmonyos hosted smoke =="
  moon test harmonyos --target native
)

echo "== moui backend window-hosted tests =="
moon test moui/backend/android --target native
moon test moui/backend/ios --target native
moon test moui/backend/harmonyos --target native

echo "== showcase window-hosted package check =="
moon check examples/showcase/android_window_hosted --target native
moon check examples/showcase/ios_window_hosted --target native
moon check examples/showcase/harmonyos_window_hosted --target native

echo "window-hosted host-sim smoke: ok"
