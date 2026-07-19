#!/usr/bin/env bash
# Build and record Android MoUI Showcase shell-runtime smoke with --require-passed.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

app="${MOUI_EMBEDDING_APP:-showcase}"
device="${MOUI_ANDROID_SERIAL:-}"
renderer="${MOUI_SKIA_RENDERER:-auto}"
manifest="${MOUI_EMBEDDING_MANIFEST:-artifacts/shell-runtime/android/${app}/shell-runtime-smoke.json}"
avd="${MOUI_ANDROID_AVD:-moui_api34}"
probe_config="$repo_root/examples/$app/.shell-runtime-test-probe-$$.json"

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

if [ -f "scripts/setup-android-sdk.sh" ]; then
  # shellcheck disable=SC1091
  eval "$(scripts/setup-android-sdk.sh --print-env 2>/dev/null || true)"
fi

export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
export PATH="${JAVA_HOME:+$JAVA_HOME/bin:}$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"

require_cmd adb
require_cmd node

if [ -z "$device" ]; then
  device="$(adb devices | awk '/\tdevice$/{print $1; exit}')"
fi

if [ -z "$device" ] && command -v emulator >/dev/null 2>&1; then
  if emulator -list-avds 2>/dev/null | grep -qx "$avd"; then
    echo "starting Android AVD $avd"
    nohup emulator -avd "$avd" -gpu host -no-snapshot-save -no-audio -no-boot-anim \
      >/tmp/moui-android-emulator.log 2>&1 &
    adb wait-for-device
    for _ in $(seq 1 90); do
      boot="$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
      if [ "$boot" = "1" ]; then
        break
      fi
      sleep 2
    done
    device="$(adb devices | awk '/\tdevice$/{print $1; exit}')"
  fi
fi

if [ -z "$device" ]; then
  echo "no Android device/emulator ready; set MOUI_ANDROID_SERIAL or start an AVD" >&2
  exit 1
fi

echo "Android shell runtime evidence app=$app device=$device renderer=$renderer"
node moui_shell/test_probe/tests/create-shell-fixture.mjs \
  --kind plugin-config --app "$app" --repo-root "$repo_root" --output "$probe_config"
scripts/build-shell-android-apk.sh \
  --app "$app" --app-config "$probe_config" --renderer "$renderer"
node scripts/record-shell-runtime-smoke.mjs \
  --platform android \
  --app "$app" \
  --device "$device" \
  --manifest "$manifest" \
  --require-passed

echo "Android shell runtime evidence passed: $manifest"
