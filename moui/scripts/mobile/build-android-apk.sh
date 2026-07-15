#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: moui/scripts/mobile/build-android-apk.sh --app <id> [options]

Build a MoUI Android debug APK through the package-owned canonical shell.

Options:
  --app <id>              Mobile app id.
  --android-project <dir> Explicit Gradle project override for repository fixtures or ejected shells.
  --app-config <path>     App-owned mobile.json. Default examples/<app>/mobile.json or ./mobile.json.
  --contracts <path>      Native contract registry. Default <moui-root>/mobile/build-contracts.json.
  --workspace-root <dir>  App workspace root. Default current directory.
  --moui-root <dir>       MoUI package root. Default this script's package.
  --skia-root <dir>       moui_skia package root.
  --abi <abi>             Android ABI, default arm64-v8a.
  --api <level>           Android min SDK, default 23.
  --compile-sdk <n>       Android compile SDK, default 36 (Activity 1.13 floor).
  --target-sdk <n>        Android target SDK, default 35.
  --renderer <mode>       auto, skia-gpu, or skia-raster. Default auto.
  --build-dir <dir>       Shared generated inputs, default artifacts/android/<app>.
  --output <apk>          Copy the Gradle APK to this path.
  --fallback-skia         Build packaging plumbing without real Skia.
  --legacy-java-shell     Build the preserved Release N Java/JNI shell fixture.
  --prepare-only          Generate MoonBit/Skia/CMake inputs, then stop.
  -h, --help              Show this help.
USAGE
}

moui_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
workspace_root="${MOUI_MOBILE_WORKSPACE_ROOT:-$(pwd)}"
skia_root="${MOUI_SKIA_ROOT:-}"
app=""
android_project=""
app_config=""
contracts=""
abi="arm64-v8a"
api_level="23"
compile_sdk="36"
target_sdk="35"
renderer="auto"
build_dir=""
output_apk=""
fallback_skia=0
legacy_java_shell=0
prepare_only=0
stage_android_project=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --app) app="${2:?missing app after --app}"; shift 2 ;;
    --android-project) android_project="${2:?missing dir after --android-project}"; shift 2 ;;
    --app-config) app_config="${2:?missing path after --app-config}"; shift 2 ;;
    --contracts) contracts="${2:?missing path after --contracts}"; shift 2 ;;
    --workspace-root) workspace_root="${2:?missing dir after --workspace-root}"; shift 2 ;;
    --moui-root) moui_root="${2:?missing dir after --moui-root}"; shift 2 ;;
    --skia-root) skia_root="${2:?missing dir after --skia-root}"; shift 2 ;;
    --abi) abi="${2:?missing ABI after --abi}"; shift 2 ;;
    --api) api_level="${2:?missing API level after --api}"; shift 2 ;;
    --compile-sdk) compile_sdk="${2:?missing SDK level after --compile-sdk}"; shift 2 ;;
    --target-sdk) target_sdk="${2:?missing SDK level after --target-sdk}"; shift 2 ;;
    --renderer) renderer="${2:?missing mode after --renderer}"; shift 2 ;;
    --build-dir) build_dir="${2:?missing directory after --build-dir}"; shift 2 ;;
    --output) output_apk="${2:?missing APK path after --output}"; shift 2 ;;
    --fallback-skia) fallback_skia=1; shift ;;
    --legacy-java-shell) legacy_java_shell=1; shift ;;
    --prepare-only) prepare_only=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -z "$app" ]; then
  echo "--app is required" >&2
  usage >&2
  exit 2
fi

case "$workspace_root" in /*) ;; *) workspace_root="$(pwd)/$workspace_root" ;; esac
case "$moui_root" in /*) ;; *) moui_root="$workspace_root/$moui_root" ;; esac
if [ -z "$skia_root" ]; then
  for candidate in \
    "$workspace_root/moui_skia" \
    "$(dirname "$moui_root")/moui_skia" \
    "$workspace_root/.mooncakes/wzzc-dev/moui_skia"; do
    if [ -d "$candidate" ]; then
      skia_root="$candidate"
      break
    fi
  done
elif [ "${skia_root#/}" = "$skia_root" ]; then
  skia_root="$workspace_root/$skia_root"
fi
if [ -z "$build_dir" ]; then
  build_dir="$workspace_root/artifacts/android/$app"
elif [ "${build_dir#/}" = "$build_dir" ]; then
  build_dir="$workspace_root/$build_dir"
fi
if [ -z "$android_project" ]; then
  if [ "$legacy_java_shell" -eq 1 ]; then
    echo "--legacy-java-shell requires an explicit --android-project fixture" >&2
    exit 2
  fi
  android_project="$build_dir/android-project"
  stage_android_project=1
elif [ "${android_project#/}" = "$android_project" ]; then
  android_project="$workspace_root/$android_project"
fi
if [ -z "$output_apk" ]; then
  output_apk="$workspace_root/artifacts/android/$app/app-debug.apk"
elif [ "${output_apk#/}" = "$output_apk" ]; then
  output_apk="$workspace_root/$output_apk"
fi

prepare_args=(
  "--platform" "android"
  "--app" "$app"
  "--workspace-root" "$workspace_root"
  "--moui-root" "$moui_root"
  "--abi" "$abi"
  "--renderer" "$renderer"
  "--build-dir" "$build_dir"
)
if [ "$legacy_java_shell" -eq 1 ]; then
  prepare_args+=("--android-shell" "legacy")
else
  prepare_args+=("--android-shell" "managed")
fi
[ -z "$skia_root" ] || prepare_args+=("--skia-root" "$skia_root")
[ -z "$app_config" ] || prepare_args+=("--app-config" "$app_config")
[ -z "$contracts" ] || prepare_args+=("--contracts" "$contracts")
if [ "$fallback_skia" -eq 1 ]; then
  prepare_args+=("--fallback-skia")
fi

node "$moui_root/scripts/mobile/prepare-native-build.mjs" "${prepare_args[@]}"

if [ "$prepare_only" -eq 1 ]; then
  echo "[moui-mobile-android] Prepared Android build inputs in $build_dir"
  exit 0
fi

if [ "$stage_android_project" -eq 1 ]; then
  template_root="$moui_root/mobile/android/template"
  stage_marker="$android_project/.moui-managed-android-stage"
  if [ ! -f "$template_root/settings.gradle" ] || [ ! -f "$template_root/app/build.gradle" ]; then
    echo "MoUI Android template is incomplete: $template_root" >&2
    exit 1
  fi
  if [ -e "$android_project" ] && [ ! -f "$stage_marker" ]; then
    echo "Refusing to replace an unowned Android project: $android_project" >&2
    exit 1
  fi
  rm -rf "$android_project"
  mkdir -p "$android_project"
  touch "$stage_marker"
  cp -R "$template_root/." "$android_project/"
  echo "[moui-mobile-android] Staged canonical Android shell in $android_project"
fi

if [ -n "${JAVA_HOME:-}" ]; then
  java_bin="$JAVA_HOME/bin/java"
  javac_bin="$JAVA_HOME/bin/javac"
  jlink_bin="$JAVA_HOME/bin/jlink"
else
  java_bin="$(command -v java || true)"
  javac_bin="$(command -v javac || true)"
  jlink_bin="$(command -v jlink || true)"
fi
if [ ! -x "$java_bin" ] || [ ! -x "$javac_bin" ] || [ ! -x "$jlink_bin" ]; then
  echo "Android APK builds require a full JDK with java, javac, and jlink on PATH or under JAVA_HOME." >&2
  echo "Set JAVA_HOME to a complete Java 17+ JDK; Java 21 is recommended for Android Gradle Plugin 9.x." >&2
  exit 1
fi

if [ -x "$workspace_root/gradlew" ]; then
  gradle_cmd=("$workspace_root/gradlew")
elif command -v gradle >/dev/null 2>&1; then
  gradle_cmd=(gradle)
else
  echo "Gradle was not found. Add a Gradle wrapper to $workspace_root or install gradle." >&2
  exit 1
fi

gradle_args=(
  -p "$android_project"
  :app:assembleDebug
  "-PmouiApp=$app"
  "-PmouiAbi=$abi"
  "-PmouiMinSdk=$api_level"
  "-PmouiCompileSdk=$compile_sdk"
  "-PmouiTargetSdk=$target_sdk"
  "-PmouiRenderer=$renderer"
  "-PmouiBuildDir=$build_dir"
  "-PmouiWorkspaceRoot=$workspace_root"
  "-PmouiRoot=$moui_root"
)
[ -z "$skia_root" ] || gradle_args+=("-PmouiSkiaRoot=$skia_root")
[ -z "$app_config" ] || gradle_args+=("-PmouiAppConfig=$app_config")
[ -z "$contracts" ] || gradle_args+=("-PmouiContracts=$contracts")
if [ "$fallback_skia" -eq 1 ]; then
  gradle_args+=("-PmouiFallbackSkia=true")
fi
if [ "$legacy_java_shell" -eq 1 ]; then
  gradle_args+=("-PmouiAndroidShell=legacy")
fi

"${gradle_cmd[@]}" "${gradle_args[@]}"

apk_path="$android_project/app/build/outputs/apk/debug/app-debug.apk"
if [ ! -f "$apk_path" ]; then
  echo "Gradle APK was not found: $apk_path" >&2
  exit 1
fi
mkdir -p "$(dirname "$output_apk")"
cp "$apk_path" "$output_apk"
echo "[moui-mobile-android] Wrote $output_apk"
