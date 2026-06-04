#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/macos-build-skia.sh [options]

Options:
  --work-dir PATH       Directory for depot_tools, Skia checkout, and build output.
                        Default: .skia-cache/macos.
  --skia-rev REV        Skia git revision, branch, or tag to checkout.
                        Default: first non-comment line of skia-revision.txt.
  --extra-gn-args STR   Extra GN args appended to the smoke-test defaults.
  --no-sync-deps        Skip python3 tools/git-sync-deps.
  --no-fetch            Reuse an existing Skia checkout instead of cloning/fetching.
  --dry-run-config      Print resolved paths and GN args, then exit without
                        fetching, syncing, generating, or building Skia.
  -h, --help            Show this help.

The script builds a small static CPU Skia library suitable for the native smoke
test. It prints SKIA_INCLUDE and SKIA_LIB_DIR exports at the end.

Environment defaults:
  MOUI_SKIA_SKIA_REV and MOUI_SKIA_EXTRA_GN_ARGS are used when the matching
  command-line option is omitted.
EOF
}

work_dir=".skia-cache/macos"
skia_rev="${MOUI_SKIA_SKIA_REV:-main}"
skia_rev_explicit=0
if [[ -n "${MOUI_SKIA_SKIA_REV:-}" ]]; then
  skia_rev_explicit=1
fi
extra_gn_args="${MOUI_SKIA_EXTRA_GN_ARGS:-}"
sync_deps=1
fetch_repo=1
dry_run_config=0

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --work-dir)
      work_dir="${2:-}"
      shift 2
      ;;
    --skia-rev)
      skia_rev="${2:-}"
      skia_rev_explicit=1
      shift 2
      ;;
    --extra-gn-args)
      extra_gn_args="${2:-}"
      shift 2
      ;;
    --no-sync-deps)
      sync_deps=0
      shift
      ;;
    --no-fetch)
      fetch_repo=0
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

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $skia_rev_explicit -eq 0 && -f "$repo_root/skia-revision.txt" ]]; then
  pinned_skia_rev="$(grep -v '^[[:space:]]*#' "$repo_root/skia-revision.txt" | grep -v '^[[:space:]]*$' | head -n 1 || true)"
  if [[ -n "$pinned_skia_rev" ]]; then
    skia_rev="$pinned_skia_rev"
  fi
fi
case "$work_dir" in
  /*) ;;
  *) work_dir="$repo_root/$work_dir" ;;
esac

depot_tools_dir="$work_dir/depot_tools"
skia_dir="$work_dir/skia"
out_dir="$skia_dir/out/moonbit-smoke"

gn_args='is_official_build=true is_debug=false skia_use_gl=false skia_use_metal=false skia_use_vulkan=false skia_use_dawn=false skia_enable_gpu=false skia_enable_pdf=false skia_enable_svg=false skia_enable_skshaper=false skia_enable_skparagraph=false skia_enable_tools=false skia_use_system_expat=false skia_use_system_freetype2=false skia_use_system_harfbuzz=false skia_use_system_icu=false skia_use_system_libjpeg_turbo=false skia_use_system_libpng=false skia_use_system_libwebp=false skia_use_system_zlib=false extra_cflags=["-DSK_DISABLE_LEGACY_PNG_WRITEBUFFER"]'
if [[ -n "$extra_gn_args" ]]; then
  gn_args="$gn_args $extra_gn_args"
fi

if [[ $dry_run_config -eq 1 ]]; then
  cat <<EOF
macOS Skia source build dry run:
  work_dir=$work_dir
  depot_tools_dir=$depot_tools_dir
  skia_checkout=$skia_dir
  out_dir=$out_dir
  skia_rev=$skia_rev
  sync_deps=$sync_deps
  fetch_repo=$fetch_repo
  gn_args=$gn_args
Dry run complete; Skia was not fetched, synced, generated, or built.
EOF
  exit 0
fi

require_command git
require_command python3
require_command ninja

echo "macOS Skia source build environment:"
echo "  git=$(git --version)"
echo "  python3=$(python3 --version)"
echo "  ninja=$(ninja --version)"

mkdir -p "$work_dir"

if [[ ! -d "$depot_tools_dir/.git" ]]; then
  git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git "$depot_tools_dir"
fi
export PATH="$depot_tools_dir:$PATH"

if [[ $fetch_repo -eq 1 ]]; then
  if [[ ! -d "$skia_dir/.git" ]]; then
    git clone https://skia.googlesource.com/skia.git "$skia_dir"
  fi
  git -C "$skia_dir" fetch origin "$skia_rev" --depth 1 || git -C "$skia_dir" fetch origin "$skia_rev"
  git -C "$skia_dir" checkout FETCH_HEAD
elif [[ ! -d "$skia_dir/.git" ]]; then
  echo "--no-fetch was supplied, but no Skia checkout exists at $skia_dir" >&2
  exit 1
fi

if [[ $sync_deps -eq 1 ]]; then
  (cd "$skia_dir" && python3 tools/git-sync-deps)
fi

echo "  skia_checkout=$skia_dir"
echo "  skia_commit=$(git -C "$skia_dir" rev-parse HEAD)"

require_command gn
echo "  gn=$(gn --version)"
echo "  gn_args=$gn_args"
gn gen "$out_dir" --args="$gn_args"
ninja -C "$out_dir" skia

if [[ ! -f "$out_dir/libskia.a" && ! -f "$out_dir/libskia.dylib" ]]; then
  echo "Skia build completed, but no libskia.a or libskia.dylib was found in $out_dir" >&2
  exit 1
fi

cat <<EOF
Skia build complete.
export SKIA_INCLUDE="$skia_dir"
export SKIA_LIB_DIR="$out_dir"

Run smoke test:
  bash scripts/macos-skia-smoke.sh --skia-include "$skia_dir" --skia-lib-dir "$out_dir"
EOF
