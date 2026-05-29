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
  --extra-cc-flags STR   Extra C/C++ flags appended to stub-cc-flags.
  --extra-link-flags STR Extra linker flags appended to cc-link-flags.
  --output PATH          Package file to write/check. Default: native/moon.pkg.
  --write                Write the generated package to --output.
  --check                Fail unless --output already equals the generated package.
  -h, --help             Show this help.

Environment defaults:
  SKIA_MBT_SKIA_INCLUDE, SKIA_MBT_SKIA_LIB_DIR, SKIA_MBT_SKIA_LIB,
  SKIA_MBT_EXTRA_CC_FLAGS, and SKIA_MBT_EXTRA_LINK_FLAGS are used when the
  matching command-line option is omitted.
EOF
}

skia_include="${SKIA_MBT_SKIA_INCLUDE:-}"
skia_lib_dir="${SKIA_MBT_SKIA_LIB_DIR:-}"
skia_lib="${SKIA_MBT_SKIA_LIB:-skia}"
extra_cc_flags="${SKIA_MBT_EXTRA_CC_FLAGS:-}"
extra_link_flags="${SKIA_MBT_EXTRA_LINK_FLAGS:-}"
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

if [[ ! -f "$lib_path/lib$skia_lib.a" && ! -f "$lib_path/lib$skia_lib.dylib" ]]; then
  echo "Skia library lib$skia_lib.a or lib$skia_lib.dylib was not found in $lib_path" >&2
  exit 1
fi

cc_flags="-DSKIA_MBT_HAS_SKIA -std=c++17 -I$include_path"
if [[ -n "$extra_cc_flags" ]]; then
  cc_flags="$cc_flags $extra_cc_flags"
fi

link_flags="-L$lib_path -l$skia_lib -lc++ -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework ImageIO -framework ApplicationServices"
if [[ -n "$extra_link_flags" ]]; then
  link_flags="$link_flags $extra_link_flags"
fi

generated_config="$(cat <<EOF
import {
  "wzzc-dev/skia_mbt" @skia,
}

options(
  "native-stub": [ "skia_stub.cpp" ],
  link: {
    "native": {
      "stub-cc-flags": "$cc_flags",
      "cc-link-flags": "$link_flags",
    },
  },
  targets: {
    "skia_native.mbt": [ "native", "llvm" ],
    "skia_unavailable.mbt": [ "wasm", "wasm-gc", "js" ],
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
