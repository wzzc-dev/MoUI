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
  --enable-skparagraph   Build SkParagraph (default: on). Requires
                          libskparagraph, libskshaper, and SkUnicode libraries
                          to be linkable from --skia-lib-dir.
  --require-skparagraph  Enable SkParagraph and fail immediately when required
                         headers or libraries are missing.
  --extra-cc-flags STR   Extra C/C++ flags appended to stub-cc-flags.
  --extra-link-flags STR Extra linker flags appended to cc-link-flags.
  --output PATH          Package file to write/check. Default: native/moon.pkg.
  --write                Write the generated package to --output.
  --check                Fail unless --output already equals the generated package.
  -h, --help             Show this help.

Environment defaults:
  MOUI_SKIA_SKIA_INCLUDE, MOUI_SKIA_SKIA_LIB_DIR, MOUI_SKIA_SKIA_LIB,
  MOUI_SKIA_LINK_MODE, MOUI_SKIA_ENABLE_SKPARAGRAPH,
  MOUI_SKIA_REQUIRE_SKPARAGRAPH, MOUI_SKIA_EXTRA_CC_FLAGS, and
  MOUI_SKIA_EXTRA_LINK_FLAGS are used when the matching command-line option is
  omitted.
EOF
}

normalize_bool() {
  local name="$1"
  local value="$2"
  case "$value" in
    1|true|TRUE|yes|YES|on|ON) printf '1\n' ;;
    ""|0|false|FALSE|no|NO|off|OFF) printf '0\n' ;;
    *)
      echo "unsupported boolean value for $name: $value" >&2
      exit 2
      ;;
  esac
}

reject_legacy_link_mode_env() {
  if [[ -n "${MOUI_SKIA_SKIA_LINK_MODE+x}" || -n "${MOUI_SKIA_MACOS_LINK_MODE+x}" ]]; then
    echo "MOUI_SKIA_SKIA_LINK_MODE and MOUI_SKIA_MACOS_LINK_MODE are no longer supported; use MOUI_SKIA_LINK_MODE=dynamic|static|auto." >&2
    exit 2
  fi
}

reject_legacy_link_mode_env

skia_include="${MOUI_SKIA_SKIA_INCLUDE:-}"
skia_lib_dir="${MOUI_SKIA_SKIA_LIB_DIR:-}"
skia_lib="${MOUI_SKIA_SKIA_LIB:-skia}"
link_mode="${MOUI_SKIA_LINK_MODE:-static}"
enable_skparagraph="${MOUI_SKIA_ENABLE_SKPARAGRAPH:-1}"
require_skparagraph="${MOUI_SKIA_REQUIRE_SKPARAGRAPH:-0}"
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
    --enable-skparagraph)
      enable_skparagraph=1
      shift
      ;;
    --require-skparagraph)
      require_skparagraph=1
      shift
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
enable_skparagraph="$(normalize_bool MOUI_SKIA_ENABLE_SKPARAGRAPH "$enable_skparagraph")"
require_skparagraph="$(normalize_bool MOUI_SKIA_REQUIRE_SKPARAGRAPH "$require_skparagraph")"
if [[ $require_skparagraph -eq 1 ]]; then
  enable_skparagraph=1
fi
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

paragraph_headers=(
  "$include_path/modules/skparagraph/include/Paragraph.h"
  "$include_path/modules/skparagraph/include/ParagraphBuilder.h"
  "$include_path/modules/skparagraph/include/ParagraphStyle.h"
  "$include_path/modules/skparagraph/include/TextStyle.h"
  "$include_path/modules/skparagraph/include/FontCollection.h"
)
paragraph_libs=(skparagraph skshaper skunicode_icu skunicode_core)
if [[ $require_skparagraph -eq 1 ]]; then
  for paragraph_header in "${paragraph_headers[@]}"; do
    if [[ ! -f "$paragraph_header" ]]; then
      echo "MOUI_SKIA_REQUIRE_SKPARAGRAPH requested, but header was missing: $paragraph_header" >&2
      exit 1
    fi
  done
  for paragraph_lib in "${paragraph_libs[@]}"; do
    if [[ ! -f "$lib_path/lib$paragraph_lib.a" && ! -f "$lib_path/lib$paragraph_lib.dylib" ]]; then
      echo "MOUI_SKIA_REQUIRE_SKPARAGRAPH requested, but lib$paragraph_lib.a or lib$paragraph_lib.dylib was not found in $lib_path" >&2
      exit 1
    fi
  done
fi
if [[ $enable_skparagraph -eq 1 && $require_skparagraph -eq 0 ]]; then
  # Release shared bundles ship no SkParagraph libraries; degrade instead of
  # emitting -lskparagraph flags that cannot link. Set
  # MOUI_SKIA_REQUIRE_SKPARAGRAPH=1 to fail instead.
  paragraph_artifacts_missing=0
  for paragraph_header in "${paragraph_headers[@]}"; do
    if [[ ! -f "$paragraph_header" ]]; then
      paragraph_artifacts_missing=1
    fi
  done
  for paragraph_lib in "${paragraph_libs[@]}"; do
    if [[ ! -f "$lib_path/lib$paragraph_lib.a" && ! -f "$lib_path/lib$paragraph_lib.dylib" ]]; then
      paragraph_artifacts_missing=1
    fi
  done
  if [[ $paragraph_artifacts_missing -eq 1 ]]; then
    echo "SkParagraph headers/libraries missing in $lib_path; disabling SkParagraph (set MOUI_SKIA_REQUIRE_SKPARAGRAPH=1 to fail instead)" >&2
    enable_skparagraph=0
  fi
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
if [[ $enable_skparagraph -eq 1 ]]; then
  cc_flags="$cc_flags -DMOUI_SKIA_HAS_SKPARAGRAPH -DMOUI_SKIA_HAS_SKSHAPER"
fi
if [[ -n "$extra_cc_flags" ]]; then
  cc_flags="$cc_flags $extra_cc_flags"
fi

link_flags="$skia_library_link_flag -lc++ -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework ImageIO -framework ApplicationServices -framework UniformTypeIdentifiers -lobjc"
if [[ -n "$skia_runtime_link_flags" ]]; then
  link_flags="$link_flags $skia_runtime_link_flags"
fi
if [[ $enable_skparagraph -eq 1 ]]; then
  link_flags="$link_flags -L$lib_path -lskparagraph -lskshaper -lskunicode_icu -lskunicode_core -lharfbuzz -licu"
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
    "skia_stub_paragraph.cpp",
    "skia_stub_shader_filter.cpp",
    "skia_stub_picture.cpp",
    "skia_stub_gpu_worker.cpp",
  ],
  link: {
    "native": {
      "stub-cc-flags": "$cc_flags",
      "cc-link-flags": "$link_flags",
    },
  },
  targets: {
    "handles_native.mbt": [ "native", "llvm" ],
    "skia_native.mbt": [ "native", "llvm" ],
    "availability_native.mbt": [ "native", "llvm" ],
    "surface_image_data_native.mbt": [ "native", "llvm" ],
    "canvas_native.mbt": [ "native", "llvm" ],
    "path_native.mbt": [ "native", "llvm" ],
    "text_font_native.mbt": [ "native", "llvm" ],
    "paragraph_native.mbt": [ "native", "llvm" ],
    "shader_filter_native.mbt": [ "native", "llvm" ],
    "picture_native.mbt": [ "native", "llvm" ],
    "native_gpu_worker_native.mbt": [ "native", "llvm" ],
    "shader_filter_ffi_wbtest.mbt": [ "native", "llvm" ],
    "handles_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "skia_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "availability_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "surface_image_data_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "canvas_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "path_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "text_font_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "paragraph_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "shader_filter_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "picture_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
    "native_gpu_worker_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
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
