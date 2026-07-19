#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
artifact_root="${MOUI_EMBEDDING_SHELL_CI_ROOT:-$repo_root/artifacts/shell-ci}"
fixture_root="$artifact_root/harmonyos/hvigor-plugin"
fallback_root="$fixture_root/fallback-input"
project_root="$fixture_root/hvigor-project"
output_hap="$fixture_root/MoUIShowcase.hap"

sdk_home="${HARMONYOS_SDK_HOME:-${OHOS_SDK_HOME:-}}"
deveco_sdk_home="${DEVECO_SDK_HOME:-}"
hvigorw="${HVIGORW:-}"
ohpm="${OHPM:-}"

if [ -z "$sdk_home" ] && [ -d /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony ]; then
  sdk_home=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony
fi
if [ -z "$deveco_sdk_home" ] && [ -d /Applications/DevEco-Studio.app/Contents/sdk ]; then
  deveco_sdk_home=/Applications/DevEco-Studio.app/Contents/sdk
fi
if [ -z "$hvigorw" ] && [ -x /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw ]; then
  hvigorw=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
fi
if [ -z "$ohpm" ] && [ -x /Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm ]; then
  ohpm=/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm
fi

if [ -z "$sdk_home" ] || [ ! -d "$sdk_home" ]; then
  echo "HARMONYOS_SDK_HOME or OHOS_SDK_HOME is required for Hvigor fixture compilation" >&2
  exit 1
fi
if [ -z "$deveco_sdk_home" ] || [ ! -d "$deveco_sdk_home" ]; then
  echo "DEVECO_SDK_HOME is required for Hvigor fixture compilation" >&2
  exit 1
fi
if [ -z "$hvigorw" ] || [ ! -x "$hvigorw" ]; then
  echo "HVIGORW must point at an executable Hvigor wrapper" >&2
  exit 1
fi
if [ -z "$ohpm" ] || [ ! -x "$ohpm" ]; then
  echo "OHPM must point at an executable ohpm command" >&2
  exit 1
fi

MOUI_EMBEDDING_SHELL_CI_ROOT="$fallback_root" \
  "$repo_root/moui_shell/test_probe/tests/build-plugin-fixture.sh" \
  harmonyos --fallback-skia

source_project="$fallback_root/harmonyos/plugin/managed-shell"
native_config="$fallback_root/harmonyos/plugin/native/moui-shell-harmonyos.cmake"
if [ ! -d "$source_project" ] || [ ! -s "$native_config" ]; then
  echo "fallback preparation did not produce a managed HarmonyOS shell and native config" >&2
  exit 1
fi

# The host fallback omits HarmonyOS system libraries because it uses local C
# shims. A cross-compiled Hvigor fallback still resolves the real logging and
# display symbols while keeping Skia on stubs.
printf '%s\n' \
  'set(MOUI_SKIA_CC_LINK_FLAGS "-lhilog_ndk.z -lnative_display_manager")' \
  >> "$native_config"

rm -rf "$project_root"
mkdir -p "$project_root"
cp -R "$source_project/." "$project_root/"
rm -rf \
  "$project_root/.hvigor" \
  "$project_root/build" \
  "$project_root/entry/.cxx" \
  "$project_root/entry/build" \
  "$project_root/oh_modules" \
  "$project_root/entry/oh_modules" \
  "$project_root/oh-package-lock.json5" \
  "$project_root/entry/oh-package-lock.json5"
mkdir -p "$project_root/hnp" "$project_root/entry/libs/arm64-v8a"

(
  cd "$project_root"
  env \
    DEVECO_SDK_HOME="$deveco_sdk_home" \
    HARMONYOS_SDK_HOME="$sdk_home" \
    OHOS_SDK_HOME="$sdk_home" \
    OHOS_BASE_SDK_HOME="$sdk_home" \
    "$ohpm" install --all --no-link
)

(
  cd "$project_root"
  env \
    DEVECO_SDK_HOME="$deveco_sdk_home" \
    HARMONYOS_SDK_HOME="$sdk_home" \
    OHOS_SDK_HOME="$sdk_home" \
    OHOS_BASE_SDK_HOME="$sdk_home" \
    MOUI_PACKAGE_ROOT="$repo_root/moui" \
    MOUI_SHELL_PACKAGE_ROOT="$repo_root/moui_shell" \
    MOUI_SKIA_ROOT="$repo_root/moui_skia" \
    MOUI_MOON_HOME="${MOON_HOME:-$HOME/.moon}" \
    MOUI_EMBEDDING_NATIVE_CONFIG="$native_config" \
    MOUI_HARMONYOS_FALLBACK=ON \
    "$hvigorw" --no-daemon assembleHap
)

built_hap="$(find "$project_root/entry/build" -name '*.hap' -type f -print | sort | head -n 1)"
if [ -z "$built_hap" ] || [ ! -f "$built_hap" ]; then
  echo "Hvigor did not produce a HAP" >&2
  exit 1
fi
mkdir -p "$(dirname "$output_hap")"
cp "$built_hap" "$output_hap"
echo "[moui-shell-test-probe] Wrote Hvigor compiler fixture $output_hap"
