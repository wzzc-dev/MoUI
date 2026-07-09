#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/build-harmonyos-demo-app.sh [options]

Build the experimental standalone HarmonyOS demo shell.

Options:
  --arch <arch>       HarmonyOS Skia arch, default arm64.
  --build-dir <dir>   Working directory, default artifacts/harmonyos/harmonyos_demo.
  --output <hap>      HAP archive path, default artifacts/harmonyos/harmonyos_demo/MoUIHarmonyOSDemo.hap.
  --sdk-home <dir>    HarmonyOS/OpenHarmony SDK root. Defaults to HARMONYOS_SDK_HOME or OHOS_SDK_HOME.
  --hvigorw <path>    Hvigor wrapper path for non-fallback builds. Defaults to HVIGORW or DevEco Studio.
  --ohpm <path>       ohpm executable path for non-fallback builds. Defaults to OHPM or DevEco Studio.
  --fallback-skia     Do not fetch/link real Skia; build packaging plumbing only.
  --prepare-only      Generate MoonBit C and configure CMake, then stop.
  -h, --help          Show this help.

The fallback path validates MoonBit C generation, native glue compilation, and
the staged HarmonyOS layout. It is packaging evidence only. Runtime support still
requires a real device/emulator smoke with first-frame, input, resize, lifecycle,
and real libskia.so loading evidence.
USAGE
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
arch="arm64"
build_dir="$repo_root/artifacts/harmonyos/harmonyos_demo"
output_hap=""
sdk_home="${HARMONYOS_SDK_HOME:-${OHOS_SDK_HOME:-}}"
hvigorw_path="${HVIGORW:-}"
ohpm_path="${OHPM:-}"
fallback_skia=0
prepare_only=0
skia_link_mode="${MOUI_SKIA_LINK_MODE:-dynamic}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --arch)
      arch="${2:?missing arch after --arch}"
      shift 2
      ;;
    --build-dir)
      build_dir="${2:?missing directory after --build-dir}"
      shift 2
      ;;
    --output)
      output_hap="${2:?missing HAP path after --output}"
      shift 2
      ;;
    --sdk-home)
      sdk_home="${2:?missing SDK path after --sdk-home}"
      shift 2
      ;;
    --hvigorw)
      hvigorw_path="${2:?missing path after --hvigorw}"
      shift 2
      ;;
    --ohpm)
      ohpm_path="${2:?missing path after --ohpm}"
      shift 2
      ;;
    --fallback-skia)
      fallback_skia=1
      shift
      ;;
    --prepare-only)
      prepare_only=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$arch" in
  arm64) ohos_arch="arm64-v8a" ;;
  *)
    echo "unsupported HarmonyOS Skia arch: $arch" >&2
    exit 2
    ;;
esac

case "$build_dir" in
  /*) ;;
  *) build_dir="$repo_root/$build_dir" ;;
esac

if [ -n "$output_hap" ]; then
  case "$output_hap" in
    /*) ;;
    *) output_hap="$repo_root/$output_hap" ;;
  esac
fi

if [ -z "$output_hap" ]; then
  output_hap="$build_dir/MoUIHarmonyOSDemo.hap"
fi

log() {
  printf '[moui-harmonyos] %s\n' "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "required command not found: $1" >&2
    exit 1
  fi
}

json_var() {
  node -e '
const fs = require("fs");
const key = process.argv[1];
const input = fs.readFileSync(0, "utf8");
const parsed = JSON.parse(input);
process.stdout.write((parsed.vars && parsed.vars[key]) || "");
' "$1"
}

first_link_dir() {
  local flags="$1"
  local flag
  for flag in $flags; do
    case "$flag" in
      -L?*)
        printf '%s\n' "${flag#-L}"
        return 0
        ;;
    esac
  done
  return 1
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

make_absolute_path() {
  local path="$1"
  case "$path" in
    /*) printf '%s\n' "$path" ;;
    *) printf '%s\n' "$repo_root/$path" ;;
  esac
}

require_cmd moon
require_cmd node
require_cmd cmake
require_cmd zip

moon_home="${MOON_HOME:-$HOME/.moon}"
if [ ! -f "$moon_home/lib/runtime.c" ] || [ ! -f "$moon_home/include/moonbit.h" ]; then
  echo "MoonBit runtime headers not found under $moon_home. Set MOON_HOME if needed." >&2
  exit 1
fi

moon_target_dir="$build_dir/moonbit"
cmake_variant="ohos"
if [ "$fallback_skia" -eq 1 ]; then
  cmake_variant="fallback"
fi
cmake_build_dir="$build_dir/cmake/$cmake_variant/$ohos_arch"
stage_dir="$build_dir/hap-stage"
mkdir -p "$build_dir" "$moon_target_dir"

log "Generating MoonBit native C for examples/harmonyos_demo/harmonyos_skia"
(
  cd "$repo_root"
  MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 \
  MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 \
    moon build examples/harmonyos_demo/harmonyos_skia --target native --target-dir "$moon_target_dir"
)

moonbit_c="$moon_target_dir/native/debug/build/examples/harmonyos_demo/harmonyos_skia/harmonyos_skia.c"
if [ ! -f "$moonbit_c" ]; then
  moonbit_c="$(find "$moon_target_dir/native/debug/build/examples/harmonyos_demo/harmonyos_skia" -name '*.c' -type f | head -n 1)"
fi
if [ -z "$moonbit_c" ] || [ ! -f "$moonbit_c" ]; then
  echo "MoonBit generated C was not found under $moon_target_dir" >&2
  exit 1
fi

skia_stub_flags=""
skia_link_flags=""
hap_shared_libs=()
fallback_cmake=ON
toolchain_file=""

if [ "$fallback_skia" -eq 0 ]; then
  if [ -z "$sdk_home" ]; then
    sdk_home="$(find_harmonyos_sdk_home || true)"
  fi
  if [ -z "$sdk_home" ]; then
    echo "HARMONYOS_SDK_HOME or OHOS_SDK_HOME must point at a HarmonyOS/OpenHarmony SDK for non-fallback builds." >&2
    echo "Use --fallback-skia for a packaging-only smoke." >&2
    exit 1
  fi
  toolchain_file="$(find_ohos_toolchain "$sdk_home" || true)"
  if [ -z "$toolchain_file" ]; then
    echo "HarmonyOS native CMake toolchain not found under $sdk_home." >&2
    exit 1
  fi
  log "Resolving HarmonyOS Skia provider flags for $arch"
  if ! skia_json="$(
    cd "$repo_root/moui_skia"
    MOUI_SKIA_PLATFORM=harmonyos \
    MOUI_SKIA_ARCH="$arch" \
    MOUI_SKIA_LINK_MODE="$skia_link_mode" \
      node build.js <<'EOF'
{}
EOF
  )"; then
    echo "failed to resolve HarmonyOS Skia. Use --fallback-skia for a packaging-only smoke." >&2
    exit 1
  fi
  skia_stub_flags="$(printf '%s' "$skia_json" | json_var MOUI_SKIA_STUB_CC_FLAGS)"
  skia_link_flags="$(printf '%s' "$skia_json" | json_var MOUI_SKIA_CC_LINK_FLAGS)"
  skia_lib_dir="$(first_link_dir "$skia_link_flags" || true)"
  if [ -n "$skia_lib_dir" ] && [ -f "$skia_lib_dir/libskia.so" ]; then
    hap_shared_libs+=("$skia_lib_dir/libskia.so")
  fi
  fallback_cmake=OFF
else
  log "Using fallback Skia mode; native library will not render real Skia frames"
fi

if [ "$fallback_skia" -eq 0 ]; then
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
  rm -rf "$hvigor_project_dir"
  mkdir -p "$hvigor_project_dir"
  cp -R "$repo_root/examples/harmonyos_demo/harmonyos_app/." "$hvigor_project_dir/"
  rm -rf \
    "$hvigor_project_dir/.hvigor" \
    "$hvigor_project_dir/build" \
    "$hvigor_project_dir/entry/build" \
    "$hvigor_project_dir/oh_modules" \
    "$hvigor_project_dir/entry/oh_modules" \
    "$hvigor_project_dir/oh-package-lock.json5" \
    "$hvigor_project_dir/entry/oh-package-lock.json5"

  mkdir -p "$hvigor_project_dir/entry/libs/$ohos_arch" "$hvigor_project_dir/hnp"
  set +u
  for shared_lib in "${hap_shared_libs[@]}"; do
    log "Staging native dependency $(basename "$shared_lib") for Hvigor"
    cp "$shared_lib" "$hvigor_project_dir/entry/libs/$ohos_arch/$(basename "$shared_lib")"
  done
  set -u

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
      MOUI_REPO_ROOT="$repo_root" \
      MOUI_MOON_HOME="$moon_home" \
      MOUI_HARMONYOS_DEMO_MOONBIT_C="$moonbit_c" \
      MOUI_HARMONYOS_FALLBACK=OFF \
      MOUI_SKIA_STUB_CC_FLAGS="$skia_stub_flags" \
      MOUI_SKIA_CC_LINK_FLAGS="$skia_link_flags" \
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

cmake_args=(
  -S "$repo_root/examples/harmonyos_demo/harmonyos_app/entry/src/main/cpp"
  -B "$cmake_build_dir"
  "-DMOUI_REPO_ROOT=$repo_root"
  "-DMOUI_MOON_HOME=$moon_home"
  "-DMOUI_HARMONYOS_DEMO_MOONBIT_C=$moonbit_c"
  "-DMOUI_HARMONYOS_FALLBACK=$fallback_cmake"
  "-DMOUI_SKIA_STUB_CC_FLAGS=$skia_stub_flags"
  "-DMOUI_SKIA_CC_LINK_FLAGS=$skia_link_flags"
)

if [ -n "$toolchain_file" ]; then
  cmake_args+=(
    "-DCMAKE_TOOLCHAIN_FILE=$toolchain_file"
    "-DOHOS_ARCH=$ohos_arch"
    "-DOHOS_STL=c++_shared"
  )
fi

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
native_lib="$(find "$cmake_build_dir" -name libmoui_harmonyos_demo.so -type f | head -n 1)"
if [ -z "$native_lib" ]; then
  echo "native library was not produced under $cmake_build_dir" >&2
  exit 1
fi

log "Staging HarmonyOS app layout"
rm -rf "$stage_dir"
mkdir -p "$stage_dir/entry/libs/$ohos_arch"
cp -R "$repo_root/examples/harmonyos_demo/harmonyos_app/AppScope" "$stage_dir/"
cp -R "$repo_root/examples/harmonyos_demo/harmonyos_app/build-profile.json5" "$stage_dir/"
cp -R "$repo_root/examples/harmonyos_demo/harmonyos_app/hvigor" "$stage_dir/"
cp -R "$repo_root/examples/harmonyos_demo/harmonyos_app/hvigorfile.ts" "$stage_dir/"
cp -R "$repo_root/examples/harmonyos_demo/harmonyos_app/oh-package.json5" "$stage_dir/"
cp -R "$repo_root/examples/harmonyos_demo/harmonyos_app/entry/build-profile.json5" "$stage_dir/entry/"
cp -R "$repo_root/examples/harmonyos_demo/harmonyos_app/entry/hvigorfile.ts" "$stage_dir/entry/"
cp -R "$repo_root/examples/harmonyos_demo/harmonyos_app/entry/obfuscation-rules.txt" "$stage_dir/entry/"
cp -R "$repo_root/examples/harmonyos_demo/harmonyos_app/entry/oh-package.json5" "$stage_dir/entry/"
cp -R "$repo_root/examples/harmonyos_demo/harmonyos_app/entry/src" "$stage_dir/entry/"
cp "$native_lib" "$stage_dir/entry/libs/$ohos_arch/libmoui_harmonyos_demo.so"
set +u
for shared_lib in "${hap_shared_libs[@]}"; do
  log "Packaging native dependency $(basename "$shared_lib")"
  cp "$shared_lib" "$stage_dir/entry/libs/$ohos_arch/$(basename "$shared_lib")"
done
set -u

mkdir -p "$(dirname "$output_hap")"
rm -f "$output_hap"
(
  cd "$stage_dir"
  zip -q -r "$output_hap" .
)

log "Wrote staged HAP archive $output_hap"
if [ "$fallback_skia" -eq 1 ]; then
  log "Fallback archive is packaging evidence only; it is not runtime support proof."
fi
