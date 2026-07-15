#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: moui/scripts/mobile/build-harmonyos-hap.sh --app <id> --harmonyos-project <dir> [options]

Build a MoUI HarmonyOS HAP through an app Stage Ability/XComponent project.

Options:
  --app <id>                    Mobile app id.
  --harmonyos-project <dir>     HarmonyOS project directory. Default ./harmonyos_app.
  --app-config <path>           App-owned mobile.json. Default examples/<app>/mobile.json or ./mobile.json.
  --contracts <path>            Native contract registry. Default <moui-root>/mobile/build-contracts.json.
  --workspace-root <dir>        App workspace root. Default current directory.
  --moui-root <dir>             MoUI package root. Default this script's package.
  --skia-root <dir>             moui_skia package root.
  --arch <arch>                 HarmonyOS Skia arch, default arm64.
  --renderer <mode>             auto, skia-gpu, or skia-raster. Default auto.
  --build-dir <dir>             Working directory, default artifacts/harmonyos/<app>.
  --output <hap>                HAP archive output path.
  --sdk-home <dir>              HarmonyOS/OpenHarmony SDK root. Defaults to HARMONYOS_SDK_HOME or OHOS_SDK_HOME.
  --hvigorw <path>              Hvigor wrapper path for non-fallback builds. Defaults to HVIGORW or DevEco Studio.
  --ohpm <path>                 ohpm executable path for non-fallback builds. Defaults to OHPM or DevEco Studio.
  --fallback-skia               Do not fetch/link real Skia; packaging smoke only.
  --prepare-only                Generate MoonBit/Skia/CMake inputs, then stop after project preparation.
  -h, --help                    Show this help.

The fallback path validates MoonBit C generation, native glue compilation, and
the staged HarmonyOS layout. It is packaging evidence only. Runtime support still
requires a real device/emulator smoke with first-frame, input, resize,
lifecycle, and real libskia.so loading evidence.
USAGE
}

moui_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
workspace_root="${MOUI_MOBILE_WORKSPACE_ROOT:-$(pwd)}"
skia_root="${MOUI_SKIA_ROOT:-}"
app=""
harmonyos_project=""
app_config=""
contracts=""
arch="arm64"
renderer="auto"
build_dir=""
output_hap=""
sdk_home="${HARMONYOS_SDK_HOME:-${OHOS_SDK_HOME:-}}"
hvigorw_path="${HVIGORW:-}"
ohpm_path="${OHPM:-}"
fallback_skia=0
prepare_only=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --app) app="${2:?missing app after --app}"; shift 2 ;;
    --harmonyos-project) harmonyos_project="${2:?missing dir after --harmonyos-project}"; shift 2 ;;
    --app-config) app_config="${2:?missing path after --app-config}"; shift 2 ;;
    --contracts) contracts="${2:?missing path after --contracts}"; shift 2 ;;
    --workspace-root) workspace_root="${2:?missing dir after --workspace-root}"; shift 2 ;;
    --moui-root) moui_root="${2:?missing dir after --moui-root}"; shift 2 ;;
    --skia-root) skia_root="${2:?missing dir after --skia-root}"; shift 2 ;;
    --arch) arch="${2:?missing arch after --arch}"; shift 2 ;;
    --renderer) renderer="${2:?missing mode after --renderer}"; shift 2 ;;
    --build-dir) build_dir="${2:?missing directory after --build-dir}"; shift 2 ;;
    --output) output_hap="${2:?missing HAP path after --output}"; shift 2 ;;
    --sdk-home) sdk_home="${2:?missing SDK path after --sdk-home}"; shift 2 ;;
    --hvigorw) hvigorw_path="${2:?missing path after --hvigorw}"; shift 2 ;;
    --ohpm) ohpm_path="${2:?missing path after --ohpm}"; shift 2 ;;
    --fallback-skia) fallback_skia=1; shift ;;
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

log() {
  printf '[moui-mobile-harmonyos] %s\n' "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "required command not found: $1" >&2
    exit 1
  fi
}

make_absolute_path() {
  local path="$1"
  case "$path" in
    /*) printf '%s\n' "$path" ;;
    *) printf '%s\n' "$workspace_root/$path" ;;
  esac
}

latest_child_dir() {
  local path="$1"
  [ -d "$path" ] || return 1
  find "$path" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | sort | tail -n 1
}

find_ohos_toolchain() {
  local root="$1"
  local candidate
  for candidate in \
    "$root/native/build/cmake/ohos.toolchain.cmake" \
    "$root/default/openharmony/native/build/cmake/ohos.toolchain.cmake" \
    "$root/default/hms/native/build/cmake/ohos.toolchain.cmake" \
    "$root/openharmony/native/build/cmake/ohos.toolchain.cmake"; do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  find "$root" -path '*/native/build/cmake/ohos.toolchain.cmake' -type f -print 2>/dev/null | head -n 1
}

find_harmonyos_sdk_home() {
  local candidate
  for candidate in \
    "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony" \
    "/Applications/DevEco-Studio.app/Contents/sdk/default/hms" \
    "$HOME/Library/OpenHarmony/Sdk/20"; do
    if [ -n "$(find_ohos_toolchain "$candidate" 2>/dev/null || true)" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

find_deveco_hvigorw() {
  local candidate
  for candidate in \
    "/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw" \
    "/Applications/DevEco Studio.app/Contents/tools/hvigor/bin/hvigorw"; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  find /Applications -path '*/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw' -type f -perm -111 -print 2>/dev/null | head -n 1
}

find_deveco_ohpm() {
  local candidate
  for candidate in \
    "/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm" \
    "/Applications/DevEco Studio.app/Contents/tools/ohpm/bin/ohpm"; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  find /Applications -path '*/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm' -type f -perm -111 -print 2>/dev/null | head -n 1
}

find_deveco_sdk_home() {
  local sdk="$1"
  local parent grandparent candidate
  parent="$(dirname "$sdk")"
  grandparent="$(dirname "$parent")"
  for candidate in "$sdk" "$parent" "$grandparent" "/Applications/DevEco-Studio.app/Contents/sdk"; do
    if [ -d "$candidate/default/openharmony" ] || [ -d "$candidate/default/hms" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

json_get() {
  node -e '
const fs = require("fs");
const key = process.argv[1];
const value = key.split(".").reduce((acc, part) => acc && acc[part], JSON.parse(fs.readFileSync(process.argv[2], "utf8")));
if (Array.isArray(value)) process.stdout.write(value.join("\n"));
else if (typeof value === "boolean") process.stdout.write(value ? "1" : "0");
else if (value !== undefined && value !== null) process.stdout.write(String(value));
' "$1" "$build_dir/mobile-build.json"
}

stage_harmonyos_project() {
  local source_project="$1"
  local target_project="$2"
  rm -rf "$target_project"
  mkdir -p "$target_project/entry"
  cp -R "$source_project/AppScope" "$target_project/"
  cp -R "$source_project/build-profile.json5" "$target_project/"
  cp -R "$source_project/hvigor" "$target_project/"
  cp -R "$source_project/hvigorfile.ts" "$target_project/"
  cp -R "$source_project/oh-package.json5" "$target_project/"
  cp -R "$source_project/entry/build-profile.json5" "$target_project/entry/"
  cp -R "$source_project/entry/hvigorfile.ts" "$target_project/entry/"
  cp -R "$source_project/entry/obfuscation-rules.txt" "$target_project/entry/"
  cp -R "$source_project/entry/oh-package.json5" "$target_project/entry/"
  cp -R "$source_project/entry/src" "$target_project/entry/"
}

# Inject DevEco debug/release signingConfigs into the staged build-profile when
# MOUI_HARMONYOS_SIGNING_CONFIG is set to a JSON object/array string, or
# MOUI_HARMONYOS_SIGNING_CONFIG_FILE points at a JSON/JSON5 fragment.
# Commercial HarmonyOS devices reject unsigned and OpenHarmony-community debug
# HAPs; matching-device smoke needs a Huawei/DevEco material for this bundle.
inject_harmonyos_signing_config() {
  local project_dir="$1"
  local profile="$project_dir/build-profile.json5"
  local fragment="${MOUI_HARMONYOS_SIGNING_CONFIG:-}"
  local fragment_file="${MOUI_HARMONYOS_SIGNING_CONFIG_FILE:-}"
  if [ -n "$fragment_file" ]; then
    if [ ! -f "$fragment_file" ]; then
      echo "MOUI_HARMONYOS_SIGNING_CONFIG_FILE not found: $fragment_file" >&2
      return 1
    fi
    fragment="$(cat "$fragment_file")"
  fi
  if [ -z "$fragment" ]; then
    return 0
  fi
  log "Injecting HarmonyOS signingConfigs into staged build-profile"
  node - "$profile" "$fragment" <<'NODE'
const fs = require("fs");
const profilePath = process.argv[2];
const fragmentRaw = process.argv[3];
const text = fs.readFileSync(profilePath, "utf8");
// Minimal JSON5-ish strip: remove // comments and trailing commas for parse.
const stripped = text
  .replace(/\/\*[\s\S]*?\*\//g, "")
  .replace(/(^|[^:])\/\/.*$/gm, "$1")
  .replace(/,\s*([}\]])/g, "$1");
const profile = JSON.parse(stripped);
let fragment;
try {
  fragment = JSON.parse(fragmentRaw);
} catch (error) {
  // Allow a raw signingConfigs array or single material object.
  const strippedFragment = fragmentRaw
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/(^|[^:])\/\/.*$/gm, "$1")
    .replace(/,\s*([}\]])/g, "$1");
  fragment = JSON.parse(strippedFragment);
}
let configs;
if (Array.isArray(fragment)) {
  configs = fragment;
} else if (fragment && Array.isArray(fragment.signingConfigs)) {
  configs = fragment.signingConfigs;
} else if (fragment && fragment.material) {
  configs = [{ name: fragment.name || "default", type: fragment.type || "HarmonyOS", material: fragment.material }];
} else if (fragment && fragment.storeFile) {
  configs = [{
    name: "default",
    type: "HarmonyOS",
    material: fragment,
  }];
} else {
  throw new Error("MOUI_HARMONYOS_SIGNING_CONFIG must be a signingConfigs array, material object, or {signingConfigs:[...]}");
}
if (!profile.app) profile.app = {};
profile.app.signingConfigs = configs;
if (Array.isArray(profile.app.products)) {
  for (const product of profile.app.products) {
    if (!product.signingConfig) product.signingConfig = configs[0]?.name || "default";
  }
}
// Write compact JSON that JSON5 parsers still accept.
fs.writeFileSync(profilePath, `${JSON.stringify(profile, null, 2)}\n`);
NODE
}

require_cmd moon
require_cmd node
require_cmd cmake
require_cmd zip

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
if [ -z "$harmonyos_project" ]; then
  harmonyos_project="$workspace_root/harmonyos_app"
elif [ "${harmonyos_project#/}" = "$harmonyos_project" ]; then
  harmonyos_project="$workspace_root/$harmonyos_project"
fi
if [ -z "$build_dir" ]; then
  build_dir="$workspace_root/artifacts/harmonyos/$app"
elif [ "${build_dir#/}" = "$build_dir" ]; then
  build_dir="$workspace_root/$build_dir"
fi

if [ ! -d "$harmonyos_project/entry/src/main/cpp" ]; then
  echo "HarmonyOS project was not found or is missing entry/src/main/cpp: $harmonyos_project" >&2
  exit 1
fi

prepare_args=(
  "--platform" "harmonyos"
  "--app" "$app"
  "--workspace-root" "$workspace_root"
  "--moui-root" "$moui_root"
  "--arch" "$arch"
  "--renderer" "$renderer"
  "--build-dir" "$build_dir"
)
[ -z "$skia_root" ] || prepare_args+=("--skia-root" "$skia_root")
[ -z "$app_config" ] || prepare_args+=("--app-config" "$app_config")
[ -z "$contracts" ] || prepare_args+=("--contracts" "$contracts")
if [ "$fallback_skia" -eq 1 ]; then
  prepare_args+=("--fallback-skia")
fi

node "$moui_root/scripts/mobile/prepare-native-build.mjs" "${prepare_args[@]}"

ohos_arch="$(json_get ohosArch)"
native_library="$(json_get nativeLibrary)"
product_name="$(json_get productName)"
cmake_config="$(json_get cmakeConfig)"
moon_home="${MOON_HOME:-$HOME/.moon}"

if [ -z "$output_hap" ]; then
  output_hap="$build_dir/$product_name.hap"
elif [ "${output_hap#/}" = "$output_hap" ]; then
  output_hap="$workspace_root/$output_hap"
fi

if [ "$fallback_skia" -eq 0 ]; then
  if [ -z "$sdk_home" ]; then
    sdk_home="$(find_harmonyos_sdk_home || true)"
  fi
  if [ -z "$sdk_home" ]; then
    echo "HARMONYOS_SDK_HOME or OHOS_SDK_HOME must point at a HarmonyOS/OpenHarmony SDK for non-fallback builds." >&2
    echo "Use --fallback-skia for a packaging-only smoke." >&2
    exit 1
  fi
  if [ -z "$(find_ohos_toolchain "$sdk_home" || true)" ]; then
    echo "HarmonyOS native CMake toolchain not found under $sdk_home." >&2
    exit 1
  fi
  if [ -z "$hvigorw_path" ]; then
    hvigorw_path="$(find_deveco_hvigorw || true)"
  else
    hvigorw_path="$(make_absolute_path "$hvigorw_path")"
  fi
  if [ -z "$hvigorw_path" ] || [ ! -x "$hvigorw_path" ]; then
    echo "Hvigor wrapper not found. Pass --hvigorw or set HVIGORW for non-fallback builds." >&2
    exit 1
  fi
  if [ -z "$ohpm_path" ]; then
    ohpm_path="$(find_deveco_ohpm || true)"
  else
    ohpm_path="$(make_absolute_path "$ohpm_path")"
  fi
  if [ -z "$ohpm_path" ] || [ ! -x "$ohpm_path" ]; then
    echo "ohpm executable not found. Pass --ohpm or set OHPM for non-fallback builds." >&2
    exit 1
  fi
  deveco_sdk_home="$(find_deveco_sdk_home "$sdk_home" || true)"
  if [ -z "$deveco_sdk_home" ]; then
    echo "DevEco SDK root not found for $sdk_home. Set DEVECO_SDK_HOME or pass --sdk-home under DevEco Studio's sdk tree." >&2
    exit 1
  fi

  hvigor_project_dir="$build_dir/hvigor-project"
  log "Preparing temporary Hvigor project at $hvigor_project_dir"
  stage_harmonyos_project "$harmonyos_project" "$hvigor_project_dir"
  inject_harmonyos_signing_config "$hvigor_project_dir"
  rm -rf \
    "$hvigor_project_dir/.hvigor" \
    "$hvigor_project_dir/build" \
    "$hvigor_project_dir/entry/build" \
    "$hvigor_project_dir/oh_modules" \
    "$hvigor_project_dir/entry/oh_modules" \
    "$hvigor_project_dir/oh-package-lock.json5" \
    "$hvigor_project_dir/entry/oh-package-lock.json5"
  mkdir -p "$hvigor_project_dir/entry/libs/$ohos_arch" "$hvigor_project_dir/hnp"

  while IFS= read -r shared_lib || [ -n "$shared_lib" ]; do
    [ -n "$shared_lib" ] || continue
    log "Staging native dependency $(basename "$shared_lib") for Hvigor"
    cp "$shared_lib" "$hvigor_project_dir/entry/libs/$ohos_arch/$(basename "$shared_lib")"
  done < <(json_get sharedLibs)

  if [ "$prepare_only" -eq 1 ]; then
    log "Prepared Hvigor project in $hvigor_project_dir"
    exit 0
  fi

  log "Installing HarmonyOS project dependencies with ohpm"
  (
    cd "$hvigor_project_dir"
    env \
      DEVECO_SDK_HOME="$deveco_sdk_home" \
      HARMONYOS_SDK_HOME="$sdk_home" \
      OHOS_SDK_HOME="$sdk_home" \
      OHOS_BASE_SDK_HOME="$sdk_home" \
      "$ohpm_path" install --all --no-link
  )

  log "Building installable HarmonyOS HAP with Hvigor"
  (
    cd "$hvigor_project_dir"
    env \
      DEVECO_SDK_HOME="$deveco_sdk_home" \
      HARMONYOS_SDK_HOME="$sdk_home" \
      OHOS_SDK_HOME="$sdk_home" \
      OHOS_BASE_SDK_HOME="$sdk_home" \
      MOUI_PACKAGE_ROOT="$moui_root" \
      MOUI_SKIA_ROOT="$skia_root" \
      MOUI_MOON_HOME="$moon_home" \
      MOUI_MOBILE_NATIVE_CONFIG="$cmake_config" \
      MOUI_HARMONYOS_FALLBACK=OFF \
      "$hvigorw_path" --no-daemon assembleHap
  )

  built_hap="$(find "$hvigor_project_dir/entry/build" -name '*-signed.hap' -type f | sort | head -n 1)"
  if [ -z "$built_hap" ]; then
    built_hap="$(find "$hvigor_project_dir/entry/build" -name '*.hap' -type f | sort | head -n 1)"
  fi
  if [ -z "$built_hap" ] || [ ! -f "$built_hap" ]; then
    echo "Hvigor did not produce a HAP under $hvigor_project_dir/entry/build" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$output_hap")"
  cp "$built_hap" "$output_hap"
  log "Wrote Hvigor HAP archive $output_hap"
  log "This is build/install evidence only until a device or emulator smoke proves first frame, input, resize, lifecycle, and libskia.so loading."
  exit 0
fi

cmake_build_dir="$build_dir/cmake/fallback/$ohos_arch"
stage_dir="$build_dir/hap-stage"
cmake_args=(
  -S "$harmonyos_project/entry/src/main/cpp"
  -B "$cmake_build_dir"
  "-DMOUI_ROOT=$moui_root"
  "-DMOUI_MOBILE_NATIVE_CONFIG=$cmake_config"
  "-DMOUI_HARMONYOS_FALLBACK=ON"
)
if command -v ninja >/dev/null 2>&1; then
  cmake_args=(-G Ninja "${cmake_args[@]}")
fi

log "Configuring HarmonyOS native library with CMake"
cmake "${cmake_args[@]}"

if [ "$prepare_only" -eq 1 ]; then
  log "Prepared HarmonyOS build inputs in $build_dir"
  exit 0
fi

log "Building HarmonyOS native library"
cmake --build "$cmake_build_dir"
native_lib="$(find "$cmake_build_dir" -name "lib${native_library}.so" -type f | head -n 1)"
if [ -z "$native_lib" ]; then
  echo "native library was not produced under $cmake_build_dir" >&2
  exit 1
fi

log "Staging HarmonyOS app layout"
stage_harmonyos_project "$harmonyos_project" "$stage_dir"
mkdir -p "$stage_dir/entry/libs/$ohos_arch"
cp "$native_lib" "$stage_dir/entry/libs/$ohos_arch/lib${native_library}.so"
while IFS= read -r shared_lib || [ -n "$shared_lib" ]; do
  [ -n "$shared_lib" ] || continue
  log "Packaging native dependency $(basename "$shared_lib")"
  cp "$shared_lib" "$stage_dir/entry/libs/$ohos_arch/$(basename "$shared_lib")"
done < <(json_get sharedLibs)

mkdir -p "$(dirname "$output_hap")"
rm -f "$output_hap"
(
  cd "$stage_dir"
  zip -q -r "$output_hap" .
)

log "Wrote staged HAP archive $output_hap"
log "Fallback archive is packaging evidence only; it is not runtime support proof."
