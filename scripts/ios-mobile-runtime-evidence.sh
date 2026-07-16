#!/usr/bin/env bash
# Build and record iOS MoUI Showcase mobile-runtime smoke with --require-passed.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

app="${MOUI_MOBILE_APP:-showcase}"
device="${MOUI_IOS_DEVICE:-}"
renderer="${MOUI_SKIA_RENDERER:-auto}"
manifest="${MOUI_MOBILE_MANIFEST:-artifacts/mobile-runtime/ios/${app}/mobile-runtime-smoke.json}"
probe_config="$repo_root/examples/$app/.mobile-runtime-test-probe-$$.json"

cleanup() {
  rm -f "$probe_config"
}
trap cleanup EXIT

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

require_cmd xcrun
require_cmd node
require_cmd idb

if [ -z "$device" ]; then
  device="$(xcrun simctl list devices booted | awk -F '[()]' '/iPhone/{print $2; exit}')"
fi
if [ -z "$device" ]; then
  # Prefer a modern iPhone simulator UDID when nothing is booted.
  device="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/{print $2; exit}')"
  if [ -n "$device" ]; then
    echo "booting iOS simulator $device"
    xcrun simctl boot "$device" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "$device" -b >/dev/null
  fi
fi
if [ -z "$device" ]; then
  echo "no iOS simulator available; set MOUI_IOS_DEVICE=<udid>" >&2
  exit 1
fi

echo "iOS mobile runtime evidence app=$app device=$device renderer=$renderer"
node moui/mobile/test-probe/tests/create-mobile-shell-fixture.mjs \
  --kind plugin-config --app "$app" --repo-root "$repo_root" --output "$probe_config"
scripts/build-mobile-ios-app.sh \
  --app "$app" --app-config "$probe_config" --renderer "$renderer"
node scripts/record-mobile-runtime-smoke.mjs \
  --platform ios \
  --app "$app" \
  --device "$device" \
  --manifest "$manifest" \
  --require-passed

echo "iOS mobile runtime evidence passed: $manifest"
