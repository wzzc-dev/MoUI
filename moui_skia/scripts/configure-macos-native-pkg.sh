#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/configure-macos-native-pkg.sh --skia-include PATH --skia-lib-dir PATH [options]

Generates the native/moon.pkg contents needed to link the native package against
an existing macOS Skia build. By default the generated package is printed to
stdout only. Use --write to replace native/moon.pkg, or --check to verify that
native/moon.pkg already matches the generated contents.

Options:
  --skia-include PATH    Skia checkout or include root containing Skia headers.
  --skia-lib-dir PATH    Directory containing libskia.a or libskia.dylib.
  --skia-lib NAME        Library name without lib prefix, default: skia.
  --link-mode MODE       static|dynamic|auto. Default: static.
                         auto prefers libskia.dylib for direct local runs and
                         falls back to libskia.a when no dylib is present.
  --extra-cc-flags STR   Extra C/C++ flags appended to stub-cc-flags.
  --extra-link-flags STR Extra linker flags appended to cc-link-flags.
  --output PATH          Package file to write/check. Default: native/moon.pkg.
  --write                Write the generated package to --output.
  --check                Fail unless --output already equals the generated package.
  -h, --help             Show this help.

Environment defaults:
  MOUI_SKIA_SKIA_INCLUDE, MOUI_SKIA_SKIA_LIB_DIR, MOUI_SKIA_SKIA_LIB,
  MOUI_SKIA_SKIA_LINK_MODE, MOUI_SKIA_MACOS_LINK_MODE, MOUI_SKIA_EXTRA_CC_FLAGS,
  and MOUI_SKIA_EXTRA_LINK_FLAGS are used when the matching command-line option
  is omitted. MOUI_SKIA_MACOS_LINK_MODE is a compatibility alias.
EOF
}

skia_include="${MOUI_SKIA_SKIA_INCLUDE:-}"
skia_lib_dir="${MOUI_SKIA_SKIA_LIB_DIR:-}"
skia_lib="${MOUI_SKIA_SKIA_LIB:-skia}"
link_mode="${MOUI_SKIA_SKIA_LINK_MODE:-${MOUI_SKIA_MACOS_LINK_MODE:-static}}"
extra_cc_flags="${MOUI_SKIA_EXTRA_CC_FLAGS:-}"
extra_link_flags="${MOUI_SKIA_EXTRA_LINK_FLAGS:-}"
output_path="native/moon.pkg"
write_config=0
check_config=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skia-include)
      skia_include="${2:-}"
      shift 2
      ;;
    --skia-lib-dir)
      skia_lib_dir="${2:-}"
      shift 2
      ;;
    --skia-lib)
      skia_lib="${2:-}"
      shift 2
      ;;
    --link-mode)
      link_mode="${2:-}"
      shift 2
      ;;
    --extra-cc-flags)
      extra_cc_flags="${2:-}"
      shift 2
      ;;
    --extra-link-flags)
      extra_link_flags="${2:-}"
      shift 2
      ;;
    --output)
      output_path="${2:-}"
      shift 2
      ;;
    --write)
      write_config=1
      shift
      ;;
    --check)
      check_config=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ $write_config -eq 1 && $check_config -eq 1 ]]; then
  echo "--write and --check cannot be used together" >&2
  exit 2
fi
case "$link_mode" in
  auto|dynamic|static) ;;
  *) echo "unsupported --link-mode: $link_mode" >&2; usage >&2; exit 2 ;;
esac
if [[ -z "$skia_include" || -z "$skia_lib_dir" ]]; then
  usage >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "$output_path" in
  /*) resolved_output_path="$output_path" ;;
  *) resolved_output_path="$repo_root/$output_path" ;;
esac

include_path="$(cd "$skia_include" && pwd)"
lib_path="$(cd "$skia_lib_dir" && pwd)"

if [[ ! -f "$include_path/include/core/SkSurface.h" ]]; then
  echo "Skia include path does not look like a Skia checkout/root: $include_path" >&2
  exit 1
fi

static_lib="$lib_path/lib$skia_lib.a"
dynamic_lib="$lib_path/lib$skia_lib.dylib"

if [[ ! -f "$static_lib" && ! -f "$dynamic_lib" ]]; then
  echo "Skia library lib$skia_lib.a or lib$skia_lib.dylib was not found in $lib_path" >&2
  exit 1
fi

resolved_link_mode="$link_mode"
if [[ "$resolved_link_mode" == "auto" ]]; then
  if [[ -f "$dynamic_lib" ]]; then
    resolved_link_mode="dynamic"
  else
    resolved_link_mode="static"
  fi
fi

case "$resolved_link_mode" in
  dynamic)
    if [[ ! -f "$dynamic_lib" ]]; then
      echo "Requested dynamic Skia link mode, but $dynamic_lib was not found" >&2
      exit 1
    fi
    skia_library_link_flag="$dynamic_lib"
    skia_runtime_link_flags="-Wl,-rpath,$lib_path"
    ;;
  static)
    if [[ ! -f "$static_lib" ]]; then
      echo "Requested static Skia link mode, but $static_lib was not found" >&2
      exit 1
    fi
    skia_library_link_flag="$static_lib"
    skia_runtime_link_flags=""
    ;;
esac

cc_flags="-DMOUI_SKIA_HAS_SKIA -std=c++17 -I$include_path"
if [[ -n "$extra_cc_flags" ]]; then
  cc_flags="$cc_flags $extra_cc_flags"
fi

link_flags="$skia_library_link_flag -lc++ -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework ImageIO -framework ApplicationServices"
if [[ -n "$skia_runtime_link_flags" ]]; then
  link_flags="$link_flags $skia_runtime_link_flags"
fi
if [[ -n "$extra_link_flags" ]]; then
  link_flags="$link_flags $extra_link_flags"
fi

generated_config="$(cat <<EOF
import {
  "wzzc-dev/moui_skia" @skia,
}

options(
  "native-stub": [
    "skia_stub.cpp",
    "skia_stub_common.cpp",
    "skia_stub_surface_image_data.cpp",
    "skia_stub_canvas.cpp",
    "skia_stub_path.cpp",
    "skia_stub_text_font.cpp",
    "skia_stub_shader_filter.cpp",
  ],
  link: {
    "native": {
      "stub-cc-flags": "$cc_flags",
      "cc-link-flags": "$link_flags",
    },
  },
  targets: {
    "handles_native.mbt": [ "native", "llvm" ],
    "availability_native.mbt": [ "native", "llvm" ],
    "surface_image_data_native.mbt": [ "native", "llvm" ],
    "canvas_native.mbt": [ "native", "llvm" ],
    "path_native.mbt": [ "native", "llvm" ],
    "text_font_native.mbt": [ "native", "llvm" ],
    "shader_filter_native.mbt": [ "native", "llvm" ],
    "handles_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "availability_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "surface_image_data_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "canvas_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "path_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "text_font_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "shader_filter_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
  },
)
EOF
)"

if [[ $check_config -eq 1 ]]; then
  if [[ ! -f "$resolved_output_path" ]]; then
    echo "native package file is missing: $resolved_output_path" >&2
    exit 1
  fi
  if ! diff -u "$resolved_output_path" <(printf '%s\n' "$generated_config"); then
    echo "native package file does not match generated macOS Skia link config: $resolved_output_path" >&2
    exit 1
  fi
  echo "Verified $resolved_output_path matches generated macOS Skia link config."
  exit 0
fi

if [[ $write_config -eq 1 ]]; then
  mkdir -p "$(dirname "$resolved_output_path")"
  printf '%s\n' "$generated_config" > "$resolved_output_path"
  echo "Wrote macOS Skia link config to $resolved_output_path"
  exit 0
fi

printf '%s\n' "$generated_config"
