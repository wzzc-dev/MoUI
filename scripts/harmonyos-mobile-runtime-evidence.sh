#!/usr/bin/env bash
# Build and record HarmonyOS MoUI Showcase mobile-runtime smoke with --require-passed.
#
# Commercial HarmonyOS devices require a Huawei/DevEco signing material for this
# bundle. Provide one of:
#   MOUI_HARMONYOS_SIGNING_CONFIG_FILE=/path/to/signingConfigs.json
#   MOUI_HARMONYOS_SIGNING_CONFIG='[{"name":"default","type":"HarmonyOS","material":{...}}]'
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

app="${MOUI_MOBILE_APP:-showcase}"
device="${MOUI_HARMONYOS_DEVICE:-}"
renderer="${MOUI_SKIA_RENDERER:-auto}"
manifest="${MOUI_MOBILE_MANIFEST:-artifacts/mobile-runtime/harmonyos/${app}/mobile-runtime-smoke.json}"
probe_config="$repo_root/examples/$app/.mobile-runtime-test-probe-$$.json"

cleanup() {
  rm -f "$probe_config"
}
trap cleanup EXIT

export HARMONYOS_SDK_HOME="${HARMONYOS_SDK_HOME:-${OHOS_SDK_HOME:-}}"
export OHOS_SDK_HOME="${OHOS_SDK_HOME:-$HARMONYOS_SDK_HOME}"
export DEVECO_SDK_HOME="${DEVECO_SDK_HOME:-/Applications/DevEco-Studio.app/Contents/sdk}"
export HVIGORW="${HVIGORW:-/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw}"
export OHPM="${OHPM:-/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

require_cmd hdc
require_cmd node

if [ -z "${MOUI_HARMONYOS_SIGNING_CONFIG:-}" ] && [ -z "${MOUI_HARMONYOS_SIGNING_CONFIG_FILE:-}" ]; then
  echo "HarmonyOS commercial/device smoke requires signing material." >&2
  echo "Set MOUI_HARMONYOS_SIGNING_CONFIG_FILE or MOUI_HARMONYOS_SIGNING_CONFIG." >&2
  echo "Unsigned and OpenHarmony-community debug HAPs install as code 9568320/9568257 on commercial devices." >&2
  exit 2
fi

if [ -z "$device" ]; then
  device="$(hdc list targets 2>/dev/null | awk 'NF && $1 !~ /\[Empty\]/{print $1; exit}')"
fi
if [ -z "$device" ]; then
  echo "no HarmonyOS device/HVD ready; set MOUI_HARMONYOS_DEVICE=<hdc-target>" >&2
  exit 1
fi

if [ -z "$HARMONYOS_SDK_HOME" ]; then
  if [ -f "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/build/cmake/ohos.toolchain.cmake" ]; then
    HARMONYOS_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony"
    OHOS_SDK_HOME="$HARMONYOS_SDK_HOME"
  fi
fi

echo "HarmonyOS mobile runtime evidence app=$app device=$device renderer=$renderer"
node moui/mobile/test-probe/tests/create-mobile-shell-fixture.mjs \
  --kind plugin-config --app "$app" --repo-root "$repo_root" --output "$probe_config"
scripts/build-mobile-harmonyos-hap.sh \
  --app "$app" --app-config "$probe_config" --renderer "$renderer"
node scripts/record-mobile-runtime-smoke.mjs \
  --platform harmonyos \
  --app "$app" \
  --device "$device" \
  --manifest "$manifest" \
  --require-passed

echo "HarmonyOS mobile runtime evidence passed: $manifest"
