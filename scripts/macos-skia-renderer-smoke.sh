#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/macos-skia-renderer-smoke.sh --skia-include PATH --skia-lib-dir PATH [options]

Temporarily configures the local skia_mbt native package plus MoUI's Skia
renderer smoke and macos_skia showcase entrypoints, runs the renderer pixel
smoke, builds examples/showcase/macos_skia, then restores all package files.

Options:
  --skia-include PATH    Skia checkout or include root containing Skia headers.
  --skia-lib-dir PATH    Directory containing libskia.a or libskia.dylib.
  --skia-lib NAME        Library name without lib prefix, default: skia.
  --extra-cc-flags STR   Extra C/C++ flags appended to skia_mbt stub flags.
  --extra-link-flags STR Extra linker flags appended to executable link flags.
  --smoke-log PATH       Write MoUI renderer smoke output to PATH. Relative
                         paths are resolved from the repository root.
  --skip-showcase-build  Only run the renderer pixel smoke.
  --dry-run-config       Print resolved paths and flags, then exit without
                         rewriting package files or building executables.
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
requested_smoke_log=""
skip_showcase_build=0
dry_run_config=0

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
    --smoke-log)
      requested_smoke_log="${2:-}"
      shift 2
      ;;
    --skip-showcase-build)
      skip_showcase_build=1
      shift
      ;;
    --dry-run-config)
      dry_run_config=1
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

if [[ -z "$skia_include" || -z "$skia_lib_dir" ]]; then
  usage >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skia_repo="$repo_root/.local_repos/skia_mbt"
native_pkg="$skia_repo/native/moon.pkg"
native_pkg_backup="$native_pkg.moui-smoke.bak"
renderer_pkg="$repo_root/moui/tests/skia_renderer_smoke/native/moon.pkg"
renderer_pkg_backup="$renderer_pkg.moui-smoke.bak"
showcase_pkg="$repo_root/examples/showcase/macos_skia/moon.pkg"
showcase_pkg_backup="$showcase_pkg.moui-smoke.bak"
smoke_log=""
smoke_log_is_temporary=0

include_path="$(cd "$skia_include" && pwd)"
lib_path="$(cd "$skia_lib_dir" && pwd)"

if [[ -n "$requested_smoke_log" ]]; then
  case "$requested_smoke_log" in
    /*) smoke_log="$requested_smoke_log" ;;
    *) smoke_log="$repo_root/$requested_smoke_log" ;;
  esac
fi

if [[ ! -f "$include_path/include/core/SkSurface.h" ]]; then
  echo "Skia include path does not look like a Skia checkout/root: $include_path" >&2
  exit 1
fi

if [[ ! -f "$lib_path/lib$skia_lib.a" && ! -f "$lib_path/lib$skia_lib.dylib" ]]; then
  echo "Skia library lib$skia_lib.a or lib$skia_lib.dylib was not found in $lib_path" >&2
  exit 1
fi

for backup in "$native_pkg_backup" "$renderer_pkg_backup" "$showcase_pkg_backup"; do
  if [[ -f "$backup" ]]; then
    echo "package backup already exists: $backup" >&2
    echo "Resolve the stale backup before running the MoUI Skia renderer smoke." >&2
    exit 1
  fi
done

cc_flags="-DSKIA_MBT_HAS_SKIA -std=c++17 -I$include_path"
if [[ -n "$extra_cc_flags" ]]; then
  cc_flags="$cc_flags $extra_cc_flags"
fi

skia_link_flags="-L$lib_path -l$skia_lib -lc++ -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework ImageIO -framework ApplicationServices"
if [[ -n "$extra_link_flags" ]]; then
  skia_link_flags="$skia_link_flags $extra_link_flags"
fi
showcase_link_flags="-framework AppKit -framework QuartzCore -framework UniformTypeIdentifiers -lz $skia_link_flags"

echo "MoUI macOS Skia renderer smoke environment:"
echo "  moon=$(moon version 2>/dev/null | head -n 1 || true)"
echo "  cxx=$(${CXX:-c++} --version 2>/dev/null | head -n 1 || true)"
echo "  skia_include=$include_path"
echo "  skia_lib_dir=$lib_path"
echo "  skia_lib=$skia_lib"
echo "  skia_stub_cc_flags=$cc_flags"
echo "  skia_link_flags=$skia_link_flags"
echo "  showcase_link_flags=$showcase_link_flags"
if [[ -n "$smoke_log" ]]; then
  echo "  smoke_log=$smoke_log"
fi
echo "  skip_showcase_build=$skip_showcase_build"

if [[ $dry_run_config -eq 1 ]]; then
  echo "Dry run complete; package files were not modified and no build was run."
  exit 0
fi

restore_packages() {
  if [[ $smoke_log_is_temporary -eq 1 && -n "${smoke_log:-}" && -f "$smoke_log" ]]; then
    rm -f "$smoke_log"
  fi
  if [[ -f "$native_pkg_backup" ]]; then
    cp "$native_pkg_backup" "$native_pkg"
    rm -f "$native_pkg_backup"
    echo "Restored skia_mbt/native/moon.pkg after MoUI Skia renderer smoke."
  fi
  if [[ -f "$renderer_pkg_backup" ]]; then
    cp "$renderer_pkg_backup" "$renderer_pkg"
    rm -f "$renderer_pkg_backup"
    echo "Restored moui/tests/skia_renderer_smoke/native/moon.pkg after MoUI Skia renderer smoke."
  fi
  if [[ -f "$showcase_pkg_backup" ]]; then
    cp "$showcase_pkg_backup" "$showcase_pkg"
    rm -f "$showcase_pkg_backup"
    echo "Restored examples/showcase/macos_skia/moon.pkg after MoUI Skia renderer smoke."
  fi
}
trap restore_packages EXIT

cp "$native_pkg" "$native_pkg_backup"
cp "$renderer_pkg" "$renderer_pkg_backup"
cp "$showcase_pkg" "$showcase_pkg_backup"

bash "$skia_repo/scripts/configure-macos-native-pkg.sh" \
  --skia-include "$include_path" \
  --skia-lib-dir "$lib_path" \
  --skia-lib "$skia_lib" \
  --extra-cc-flags "$extra_cc_flags" \
  --extra-link-flags "$extra_link_flags" \
  --output "$native_pkg" \
  --write >/dev/null
echo "Wrote temporary skia_mbt/native/moon.pkg with macOS Skia link flags."

cat > "$renderer_pkg" <<EOF
import {
  "wzzc-dev/moui/core",
  "wzzc-dev/moui/render",
  "wzzc-dev/moui/render/skia" @skia_renderer,
}

supported_targets = "native"

options(
  "is-main": true,
  link: {
    "native": {
      "cc-link-flags": "$skia_link_flags",
    },
  },
  targets: { "main.mbt": [ "native" ] },
)
EOF
echo "Wrote temporary MoUI renderer smoke package link flags."

cat > "$showcase_pkg" <<EOF
import {
  "wzzc-dev/moui/backend/macos" @macos_backend,
  "wzzc-dev/moui/render",
  "examples/showcase/app",
}

supported_targets = "native"

options(
  "is-main": true,
  link: {
    "native": {
      "cc-link-flags": "$showcase_link_flags",
    },
  },
  targets: { "main.mbt": [ "native" ] },
)
EOF
echo "Wrote temporary macos_skia showcase package link flags."

cd "$repo_root"
moon build moui/tests/skia_renderer_smoke/native --target native
renderer_exe="$repo_root/_build/native/debug/build/wzzc-dev/moui/tests/skia_renderer_smoke/native/native.exe"
if [[ ! -x "$renderer_exe" ]]; then
  echo "MoUI Skia renderer smoke executable was not produced at $renderer_exe" >&2
  exit 1
fi

export DYLD_LIBRARY_PATH="$lib_path${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
echo "Running MoUI Skia renderer smoke executable: $renderer_exe"
if [[ -z "$smoke_log" ]]; then
  smoke_log="$(mktemp "${TMPDIR:-/tmp}/moui-skia-renderer-smoke.XXXXXX.log")"
  smoke_log_is_temporary=1
else
  mkdir -p "$(dirname "$smoke_log")"
  : > "$smoke_log"
fi

set +e
set -o pipefail
"$renderer_exe" 2>&1 | tee "$smoke_log"
renderer_status=${PIPESTATUS[0]}
set +o pipefail
set -e
if [[ $renderer_status -ne 0 ]]; then
  exit "$renderer_status"
fi
if ! grep -Fq "MoUI Skia renderer smoke passed" "$smoke_log"; then
  echo "MoUI Skia renderer smoke did not print the expected success marker" >&2
  exit 1
fi
echo "Verified MoUI Skia renderer smoke success marker."

if [[ $skip_showcase_build -eq 0 ]]; then
  moon build examples/showcase/macos_skia --target native
  showcase_exe="$repo_root/_build/native/debug/build/examples/showcase/macos_skia/macos_skia.exe"
  if [[ -x "$showcase_exe" ]]; then
    echo "Built macos_skia showcase executable: $showcase_exe"
  else
    echo "Built examples/showcase/macos_skia; executable path is managed by moon build output."
  fi
fi

echo "MoUI macOS Skia renderer smoke passed."
