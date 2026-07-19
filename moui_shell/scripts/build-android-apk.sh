#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: moui_shell/scripts/build-android-apk.sh --app <id> [options]

Options:
  --app <id>              Shell app id.
  --android-project <dir> Versioned ejected Gradle project.
  --app-config <path>     App-owned shell.json.
  --workspace-root <dir>  Application workspace root.
  --project-root <dir>    Ejected app project root; defaults to the shell parent.
  --moui-root <dir>       Matching wzzc-dev/moui package root.
  --skia-root <dir>       Matching moui_skia package root.
  --abi <abi>             Android ABI, default arm64-v8a.
  --compile-sdk <n>       Android compile SDK, default 36.
  --target-sdk <n>        Android target SDK, default 35.
  --renderer <mode>       auto, skia-gpu, or skia-raster.
  --build-dir <dir>       Generated inputs, default artifacts/android/<app>.
  --output <apk>          Output APK path.
  --fallback-skia         Packaging-only fallback renderer build.
  --ejected-shell         Build a versioned ejected project.
  --prepare-only          Generate inputs and stop.
USAGE
}

shell_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workspace_root="${MOUI_SHELL_WORKSPACE_ROOT:-$(pwd)}"
moui_root=""
skia_root="${MOUI_SKIA_ROOT:-}"
project_root="${MOUI_EMBEDDING_PROJECT_ROOT:-}"
app=""; android_project=""; app_config=""; abi="arm64-v8a"; compile_sdk="36"; target_sdk="35"
renderer="auto"; build_dir=""; output_apk=""; fallback_skia=0; ejected_shell=0; prepare_only=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --app) app="${2:?missing app}"; shift 2 ;;
    --android-project) android_project="${2:?missing directory}"; shift 2 ;;
    --app-config) app_config="${2:?missing path}"; shift 2 ;;
    --workspace-root) workspace_root="${2:?missing directory}"; shift 2 ;;
    --project-root) project_root="${2:?missing directory}"; shift 2 ;;
    --moui-root) moui_root="${2:?missing directory}"; shift 2 ;;
    --skia-root) skia_root="${2:?missing directory}"; shift 2 ;;
    --abi) abi="${2:?missing ABI}"; shift 2 ;;
    --compile-sdk) compile_sdk="${2:?missing SDK}"; shift 2 ;;
    --target-sdk) target_sdk="${2:?missing SDK}"; shift 2 ;;
    --renderer) renderer="${2:?missing renderer}"; shift 2 ;;
    --build-dir) build_dir="${2:?missing directory}"; shift 2 ;;
    --output) output_apk="${2:?missing output}"; shift 2 ;;
    --fallback-skia) fallback_skia=1; shift ;;
    --ejected-shell) ejected_shell=1; shift ;;
    --prepare-only) prepare_only=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done
[ -n "$app" ] || { echo "--app is required" >&2; exit 2; }
case "$workspace_root" in /*) ;; *) workspace_root="$(pwd)/$workspace_root" ;; esac
case "$moui_root" in "") moui_root="$workspace_root/moui" ;; /*) ;; *) moui_root="$workspace_root/$moui_root" ;; esac
if [ -z "$skia_root" ]; then skia_root="$workspace_root/moui_skia"; elif [ "${skia_root#/}" = "$skia_root" ]; then skia_root="$workspace_root/$skia_root"; fi
if [ -z "$build_dir" ]; then build_dir="$workspace_root/artifacts/android/$app"; elif [ "${build_dir#/}" = "$build_dir" ]; then build_dir="$workspace_root/$build_dir"; fi
if [ -z "$output_apk" ]; then output_apk="$workspace_root/artifacts/android/$app/app-debug.apk"; elif [ "${output_apk#/}" = "$output_apk" ]; then output_apk="$workspace_root/$output_apk"; fi
if [ -z "$app_config" ]; then app_config="$workspace_root/examples/$app/shell.json"; elif [ "${app_config#/}" = "$app_config" ]; then app_config="$workspace_root/$app_config"; fi

runner_mode="managed"
if [ "$ejected_shell" -eq 1 ]; then
  runner_mode="ejected"
  [ -n "$android_project" ] || { echo "--ejected-shell requires --android-project" >&2; exit 2; }
  case "$android_project" in /*) ;; *) android_project="$workspace_root/$android_project" ;; esac
  shell_lock="$android_project/.moui-shell.json"
  if [ -z "$project_root" ]; then project_root="$(dirname "$android_project")"; elif [ "${project_root#/}" = "$project_root" ]; then project_root="$workspace_root/$project_root"; fi
  node "$shell_root/scripts/validate-ejected-lock.mjs" \
    --lock "$shell_lock" --platform android --moui-root "$moui_root" \
    --shell-root "$shell_root" --project-root "$project_root" --app-config "$app_config"
else
  android_project="$build_dir/android-project"
  template_root="$shell_root/android/runner/template"
  stage_marker="$android_project/.moui-managed-shell"
  if [ -e "$android_project" ] && [ ! -f "$stage_marker" ]; then echo "Refusing to replace an unowned Android project: $android_project" >&2; exit 1; fi
  rm -rf "$android_project"
  mkdir -p "$android_project"
  cp -R "$template_root/." "$android_project/"
  : > "$stage_marker"
fi

prepare_args=(--platform android --app "$app" --workspace-root "$workspace_root" --moui-root "$moui_root" --skia-root "$skia_root" --app-config "$app_config" --abi "$abi" --android-shell "$runner_mode" --renderer "$renderer" --build-dir "$build_dir")
[ "$fallback_skia" -eq 0 ] || prepare_args+=(--fallback-skia)
node "$shell_root/scripts/prepare-native-build.mjs" "${prepare_args[@]}"
[ "$prepare_only" -eq 0 ] || { echo "[moui-shell-android] prepared $build_dir"; exit 0; }

if [ -x "$workspace_root/gradlew" ]; then gradle_cmd=("$workspace_root/gradlew"); elif command -v gradle >/dev/null 2>&1; then gradle_cmd=(gradle); else echo "Gradle was not found" >&2; exit 1; fi
gradle_args=(-p "$android_project" :app:assembleDebug "-PmouiApp=$app" "-PmouiAbi=$abi" "-PmouiCompileSdk=$compile_sdk" "-PmouiTargetSdk=$target_sdk" "-PmouiRenderer=$renderer" "-PmouiBuildDir=$build_dir" "-PmouiWorkspaceRoot=$workspace_root" "-PmouiRoot=$moui_root" "-PmouiShellRoot=$shell_root" "-PmouiAppConfig=$app_config" "-PmouiAndroidShell=$runner_mode")
[ "$fallback_skia" -eq 0 ] || gradle_args+=("-PmouiFallbackSkia=true")
"${gradle_cmd[@]}" "${gradle_args[@]}"
apk_path="$android_project/app/build/outputs/apk/debug/app-debug.apk"
[ -f "$apk_path" ] || { echo "Gradle APK was not found: $apk_path" >&2; exit 1; }
mkdir -p "$(dirname "$output_apk")"
cp "$apk_path" "$output_apk"
echo "[moui-shell-android] wrote $output_apk"
