#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/build-platform-showcase-ios-app.sh [options]

Build the experimental Platform Showcase iOS Simulator .app bundle.

Options:
  --sdk <sdk>               Apple SDK, iphonesimulator or iphoneos. Default iphonesimulator.
  --arch <arch>             Target arch, arm64 or x86_64. Default arm64.
  --deployment-target <ver> iOS deployment target. Default 15.0.
  --build-dir <dir>         Working directory. Default artifacts/ios/platform_showcase.
  --output <app>            App bundle path. Default artifacts/ios/platform_showcase/MoUIPlatformShowcase.app.
  --fallback-skia           Do not fetch/link real Skia; build packaging plumbing only.
  --prepare-only            Generate MoonBit C and resolve inputs, then stop.
  -h, --help                Show this help.

Real iOS rendering requires the default Skia path. --fallback-skia is only a
fast build-system smoke; the resulting app reports Skia unavailable and is not
first-frame runtime evidence. The default iOS Skia link mode is static.
USAGE
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sdk="iphonesimulator"
arch="arm64"
deployment_target="15.0"
build_dir="$repo_root/artifacts/ios/platform_showcase"
output_app=""
fallback_skia=0
prepare_only=0
skia_link_mode="${MOUI_SKIA_LINK_MODE:-static}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --sdk)
      sdk="${2:?missing SDK after --sdk}"
      shift 2
      ;;
    --arch)
      arch="${2:?missing architecture after --arch}"
      shift 2
      ;;
    --deployment-target)
      deployment_target="${2:?missing version after --deployment-target}"
      shift 2
      ;;
    --build-dir)
      build_dir="${2:?missing directory after --build-dir}"
      shift 2
      ;;
    --output)
      output_app="${2:?missing app path after --output}"
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

case "$build_dir" in
  /*) ;;
  *) build_dir="$repo_root/$build_dir" ;;
esac

if [ -n "$output_app" ]; then
  case "$output_app" in
    /*) ;;
    *) output_app="$repo_root/$output_app" ;;
  esac
fi

case "$sdk" in
  iphonesimulator)
    skia_platform="iosSim"
    min_version_flag="-mios-simulator-version-min=$deployment_target"
    ;;
  iphoneos)
    skia_platform="ios"
    min_version_flag="-miphoneos-version-min=$deployment_target"
    ;;
  *)
    echo "unsupported SDK: $sdk (expected iphonesimulator or iphoneos)" >&2
    exit 2
    ;;
esac

case "$arch" in
  arm64)
    skia_arch="arm64"
    ;;
  x86_64)
    if [ "$sdk" = "iphoneos" ]; then
      echo "x86_64 is only supported for iphonesimulator builds" >&2
      exit 2
    fi
    skia_arch="x64"
    ;;
  *)
    echo "unsupported architecture for locked iOS Skia artifacts: $arch" >&2
    exit 2
    ;;
esac

log() {
  printf '[moui-platform-showcase-ios] %s\n' "$*"
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

compile_c() {
  local src="$1"
  local obj="$2"
  shift 2
  log "Compiling $(basename "$src")"
  "$cc" "${common_flags[@]}" "${include_flags[@]}" "$@" -c "$src" -o "$obj"
  objects+=("$obj")
}

compile_cxx() {
  local src="$1"
  local obj="$2"
  shift 2
  log "Compiling $(basename "$src")"
  if [ -n "$skia_stub_flags" ]; then
    # The Skia provider emits shell-style flag words without spaces in paths.
    # shellcheck disable=SC2086
    "$cxx" "${common_flags[@]}" "${include_flags[@]}" $skia_stub_flags \
      -std=c++17 "$@" -c "$src" -o "$obj"
  else
    "$cxx" "${common_flags[@]}" "${include_flags[@]}" \
      -std=c++17 "$@" -c "$src" -o "$obj"
  fi
  objects+=("$obj")
}

compile_objcxx() {
  local src="$1"
  local obj="$2"
  shift 2
  log "Compiling $(basename "$src")"
  "$cxx" "${common_flags[@]}" "${include_flags[@]}" -std=c++17 -fobjc-arc \
    "$@" -c "$src" -o "$obj"
  objects+=("$obj")
}

require_cmd moon
require_cmd node
require_cmd xcrun

sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"
cc="$(xcrun --sdk "$sdk" --find clang)"
cxx="$(xcrun --sdk "$sdk" --find clang++)"

moon_home="${MOON_HOME:-$HOME/.moon}"
if [ ! -f "$moon_home/lib/runtime.c" ] || [ ! -f "$moon_home/include/moonbit.h" ]; then
  echo "MoonBit runtime headers not found under $moon_home. Set MOON_HOME if needed." >&2
  exit 1
fi

fs_native="$repo_root/.mooncakes/moonbitlang/x/fs/fs_native.c"
if [ ! -f "$fs_native" ]; then
  echo "MoonBit x/fs native stub was not found: $fs_native" >&2
  echo "Run moon update or moon check once to populate .mooncakes." >&2
  exit 1
fi

if [ -z "$output_app" ]; then
  output_app="$build_dir/MoUIPlatformShowcase.app"
fi

moon_target_dir="$build_dir/moonbit"
obj_dir="$build_dir/obj/$sdk-$arch"
mkdir -p "$build_dir" "$moon_target_dir" "$obj_dir"

log "Generating MoonBit native C for examples/platform_showcase/ios"
(
  cd "$repo_root"
  MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 \
  MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 \
    moon build examples/platform_showcase/ios --target native --target-dir "$moon_target_dir"
)

moonbit_c="$moon_target_dir/native/debug/build/examples/platform_showcase/ios/ios.c"
if [ ! -f "$moonbit_c" ]; then
  echo "MoonBit generated C was not found: $moonbit_c" >&2
  exit 1
fi

skia_stub_flags=""
skia_link_flags=""
if [ "$fallback_skia" -eq 0 ]; then
  log "Resolving iOS Skia provider flags for $sdk/$arch"
  if ! skia_json="$(
    cd "$repo_root/moui_skia"
    MOUI_SKIA_PLATFORM="$skia_platform" \
    MOUI_SKIA_ARCH="$skia_arch" \
    MOUI_SKIA_LINK_MODE="$skia_link_mode" \
      node build.js <<'EOF'
{}
EOF
  )"; then
    echo "failed to resolve iOS Skia. Use --fallback-skia for a packaging-only smoke." >&2
    exit 1
  fi
  skia_stub_flags="$(printf '%s' "$skia_json" | json_var MOUI_SKIA_STUB_CC_FLAGS)"
  skia_link_flags="$(printf '%s' "$skia_json" | json_var MOUI_SKIA_CC_LINK_FLAGS)"
else
  log "Using fallback Skia mode; app will not render real Skia frames"
fi

if [ "$prepare_only" -eq 1 ]; then
  log "Prepared iOS build inputs in $build_dir"
  exit 0
fi

rm -rf "$obj_dir"
mkdir -p "$obj_dir"

common_flags=(
  -arch "$arch"
  -isysroot "$sdk_path"
  "$min_version_flag"
)
include_flags=(
  -I "$repo_root/examples/platform_showcase/ios_app/include"
  -I "$moon_home/include"
  -I "$repo_root/moui_skia/native"
)
objects=()
compile_c "$moonbit_c" "$obj_dir/ios.o" -Dmain=moui_platform_showcase_ios_moonbit_generated_main
compile_c "$moon_home/lib/runtime.c" "$obj_dir/runtime.o" -Dgetentropy=moui_ios_getentropy
compile_c "$fs_native" "$obj_dir/fs_native.o"
compile_c "$repo_root/examples/platform_showcase/ios_app/moui_ios_compat.c" "$obj_dir/moui_ios_compat.o"
compile_objcxx "$repo_root/examples/platform_showcase/ios_app/main.mm" "$obj_dir/main.o"
compile_objcxx "$repo_root/moui/backend/ios/skia/ios_skia_presenter.mm" "$obj_dir/ios_skia_presenter.o"

skia_stub_sources=(
  "$repo_root/moui_skia/native/skia_stub.cpp"
  "$repo_root/moui_skia/native/skia_stub_common.cpp"
  "$repo_root/moui_skia/native/skia_stub_surface_image_data.cpp"
  "$repo_root/moui_skia/native/skia_stub_canvas.cpp"
  "$repo_root/moui_skia/native/skia_stub_path.cpp"
  "$repo_root/moui_skia/native/skia_stub_text_font.cpp"
  "$repo_root/moui_skia/native/skia_stub_paragraph.cpp"
  "$repo_root/moui_skia/native/skia_stub_shader_filter.cpp"
)
for src in "${skia_stub_sources[@]}"; do
  compile_cxx "$src" "$obj_dir/$(basename "${src%.cpp}").o"
done

app_bundle="$output_app"
executable_name="MoUIPlatformShowcase"
executable_path="$app_bundle/$executable_name"
rm -rf "$app_bundle"
mkdir -p "$app_bundle"

ios_link_flags=(
  -framework UIKit
  -framework Foundation
  -framework CoreFoundation
  -framework CoreGraphics
  -framework CoreText
  -framework ImageIO
  -framework QuartzCore
  -lz
  -lobjc
)

log "Linking $executable_name"
if [ -n "$skia_link_flags" ]; then
  # shellcheck disable=SC2086
  "$cxx" "${common_flags[@]}" -o "$executable_path" \
    "${objects[@]}" \
    $skia_link_flags \
    "${ios_link_flags[@]}"
else
  "$cxx" "${common_flags[@]}" -o "$executable_path" \
    "${objects[@]}" \
    "${ios_link_flags[@]}"
fi

cp "$repo_root/examples/platform_showcase/ios_app/Info.plist" "$app_bundle/Info.plist"
if [ -x /usr/libexec/PlistBuddy ]; then
  /usr/libexec/PlistBuddy -c "Set :MinimumOSVersion $deployment_target" \
    "$app_bundle/Info.plist" >/dev/null
fi
printf 'APPL????' > "$app_bundle/PkgInfo"

if [ "$sdk" = "iphonesimulator" ] && command -v codesign >/dev/null 2>&1; then
  if codesign --force --sign - "$app_bundle" >/dev/null 2>&1; then
    log "Ad-hoc signed simulator app bundle"
  else
    log "Ad-hoc codesign failed; leaving unsigned simulator app bundle"
  fi
fi

if [ "$sdk" = "iphoneos" ]; then
  log "Built an unsigned iphoneos bundle; real-device install still requires a provisioning/signing flow"
fi

log "Wrote $app_bundle"
