#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/windows-platform-evidence.sh [options]

Collects Windows Skia platform evidence from the canonical Showcase route:
1. Resolves the requested real Skia provider.
2. Temporarily configures moui_skia/native/moon.pkg for MSVC.
3. Builds and runs examples/showcase/windows_skia with first-frame auto-exit.
4. Writes logs under artifacts/platform-evidence/windows/.

Options:
  --log-dir PATH          Evidence output directory.
                          Default: artifacts/platform-evidence/windows.
  --skia-provider release|existing
                          Skia acquisition mode. Default: release.
  --link-mode static|dynamic|auto
                          Skia link mode. Default: static.
  --dry-run-config        Print resolved options and exit without building.
  -h, --help              Show this help.

For --skia-provider existing, set MOUI_SKIA_SKIA_ROOT,
MOUI_SKIA_SKIA_INCLUDE, and MOUI_SKIA_SKIA_LIB_DIR.
EOF
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log_dir="$REPO_ROOT/artifacts/platform-evidence/windows"
skia_provider="${MOUI_SKIA_SKIA_PROVIDER:-release}"
skia_link_mode="${MOUI_SKIA_LINK_MODE:-static}"
dry_run_config=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --log-dir) log_dir="${2:-}"; shift 2 ;;
    --skia-provider) skia_provider="${2:-}"; shift 2 ;;
    --link-mode) skia_link_mode="${2:-}"; shift 2 ;;
    --dry-run-config) dry_run_config=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$skia_provider" in
  release|existing) ;;
  *) echo "invalid --skia-provider: $skia_provider" >&2; exit 2 ;;
esac

case "$skia_link_mode" in
  static|dynamic|auto) ;;
  *) echo "invalid --link-mode: $skia_link_mode" >&2; exit 2 ;;
esac

case "$log_dir" in
  /*) resolved_log_dir="$log_dir" ;;
  *)
    if [[ "$log_dir" =~ ^[A-Za-z]:[\\/].* ]] && command -v cygpath >/dev/null 2>&1; then
      resolved_log_dir="$(cygpath -u "$log_dir")"
    else
      resolved_log_dir="$REPO_ROOT/$log_dir"
    fi
    ;;
esac

skia_repo="$REPO_ROOT/moui_skia"
skia_pkg="$skia_repo/native/moon.pkg"
skia_pkg_backup="$skia_pkg.moui-evidence.bak"
showcase_pkg="$REPO_ROOT/examples/showcase/windows_skia/moon.pkg"
showcase_backup="$showcase_pkg.moui-evidence.bak"
showcase_log="$resolved_log_dir/showcase-windows-skia-first-frame.log"
preflight_log="$resolved_log_dir/windows-platform-evidence-preflight.log"
summary_log="$resolved_log_dir/windows-platform-evidence-summary.log"

mkdir -p "$resolved_log_dir"

{
  echo "Windows platform evidence run:"
  echo "  route=examples/showcase/windows_skia"
  echo "  log_dir=$resolved_log_dir"
  echo "  skia_provider=$skia_provider"
  echo "  skia_link_mode=$skia_link_mode"
} | tee "$preflight_log"

if [[ $dry_run_config -eq 1 ]]; then
  echo "Dry run; no operations performed." | tee -a "$preflight_log"
  exit 0
fi

restore_skia_pkg() {
  if [[ -f "$skia_pkg_backup" ]]; then
    cp "$skia_pkg_backup" "$skia_pkg"
    rm -f "$skia_pkg_backup"
    echo "Restored $skia_pkg"
  fi
  if [[ -f "$showcase_backup" ]]; then
    cp "$showcase_backup" "$showcase_pkg"
    rm -f "$showcase_backup"
    echo "Restored $showcase_pkg"
  fi
}

if [[ -f "$skia_pkg_backup" ]]; then
  echo "stale Skia package backup exists: $skia_pkg_backup" >&2
  exit 1
fi
if [[ -f "$showcase_backup" ]]; then
  echo "stale Showcase package backup exists: $showcase_backup" >&2
  exit 1
fi
cp "$skia_pkg" "$skia_pkg_backup"
cp "$showcase_pkg" "$showcase_backup"
trap restore_skia_pkg EXIT

if [[ "$skia_provider" == "release" ]]; then
  echo "=== Step 1: Resolve release Skia provider ===" | tee -a "$preflight_log"
  env_lines="$(powershell -NoProfile -ExecutionPolicy Bypass -File \
    "$skia_repo/scripts/fetch-release-skia.ps1" \
    -Platform windows -Arch auto -Config Release \
    -LinkMode "$skia_link_mode" -PrintEnv)"

  extract_env() {
    printf '%s\n' "$env_lines" | sed -n "s/^${1}=//p" | tail -n 1
  }

  skia_root="$(extract_env MOUI_SKIA_SKIA_ROOT)"
  skia_include="$(extract_env MOUI_SKIA_SKIA_INCLUDE)"
  skia_lib_dir="$(extract_env MOUI_SKIA_SKIA_LIB_DIR)"
  skia_commit="$(extract_env MOUI_SKIA_SKIA_COMMIT)"
else
  echo "=== Step 1: Resolve existing Skia provider ===" | tee -a "$preflight_log"
  skia_root="${MOUI_SKIA_SKIA_ROOT:-}"
  skia_include="${MOUI_SKIA_SKIA_INCLUDE:-}"
  skia_lib_dir="${MOUI_SKIA_SKIA_LIB_DIR:-}"
  skia_commit="${MOUI_SKIA_SKIA_COMMIT:-existing}"
fi

{
  echo "  skia_root=$skia_root"
  echo "  skia_include=$skia_include"
  echo "  skia_lib_dir=$skia_lib_dir"
  echo "  skia_commit=$skia_commit"
} | tee -a "$preflight_log"

if [[ -z "$skia_root" || -z "$skia_include" || -z "$skia_lib_dir" ]]; then
  echo "Skia provider did not resolve complete paths" >&2
  exit 1
fi

echo "=== Step 2: Configure moui_skia/native/moon.pkg ===" | tee -a "$preflight_log"
powershell -NoProfile -ExecutionPolicy Bypass -File \
  "$skia_repo/scripts/configure-windows-msvc-native-pkg.ps1" \
  -SkiaRoot "$skia_root" \
  -SkiaInclude "$skia_include" \
  -SkiaLibDir "$skia_lib_dir" \
  -SkiaLinkMode "$skia_link_mode" \
  -Write 2>&1 | tee -a "$preflight_log"

echo "=== Step 3: Configure Showcase package link flags ===" | tee -a "$preflight_log"
# The MSVC final link only sees link flags carried by build.js link_configs;
# with MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 that carrier is empty, so inject the
# generated Skia flags into the executable package directly (same pattern as
# scripts/linux-platform-evidence.sh).
win_stub_cc_flags="$(sed -n 's/.*"stub-cc-flags": "\(.*\)",/\1/p' "$skia_pkg" | tail -n 1)"
win_link_flags="$(sed -n 's/.*"cc-link-flags": "\(.*\)",/\1/p' "$skia_pkg" | tail -n 1)"
if [[ -z "$win_stub_cc_flags" || -z "$win_link_flags" ]]; then
  echo "Failed to extract Skia link flags from $skia_pkg" >&2
  exit 1
fi
echo "  Skia link flags: $win_link_flags" | tee -a "$preflight_log"

cat > "$showcase_pkg" <<PKGEOF
import {
  "wzzc-dev/moui/runtime",
  "wzzc-dev/moui/backend/windows" @windows_backend,
  "wzzc-dev/moui_skia_renderer" @render_skia,
  "examples/showcase",
}

supported_targets = "native"

pkgtype(kind: "executable")

options(
  link: {
    "native": {
      "stub-cc-flags": "$win_stub_cc_flags",
      "cc-link-flags": "$win_link_flags",
    },
  },
  targets: { "main.mbt": [ "native" ] },
)
PKGEOF
echo "  Wrote $showcase_pkg" | tee -a "$preflight_log"

echo "=== Step 4: Build Showcase Windows Skia ===" | tee -a "$preflight_log"
cd "$REPO_ROOT"
MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 \
  MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 \
  moon build examples/showcase/windows_skia --target native 2>&1 \
  | tee -a "$preflight_log"

echo "=== Step 5: Run Showcase first-frame smoke ===" | tee -a "$preflight_log"
MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 \
  MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 \
  MOUI_FIRST_FRAME_EXIT=1 \
  moon run examples/showcase/windows_skia --target native \
  > "$showcase_log" 2>&1 &
showcase_pid=$!

(
  sleep 60
  if kill -0 "$showcase_pid" 2>/dev/null; then
    echo "Showcase first-frame smoke timed out after 60s" >> "$showcase_log"
    kill "$showcase_pid" 2>/dev/null || true
  fi
) &
watchdog_pid=$!

if wait "$showcase_pid"; then
  showcase_exit=0
else
  showcase_exit=$?
fi
kill "$watchdog_pid" 2>/dev/null || true
wait "$watchdog_pid" 2>/dev/null || true

first_frame_marker="Windows renderer presented first frame; exiting by request; title=MoUI Showcase"
if [[ $showcase_exit -eq 0 ]] && grep -Fq "$first_frame_marker" "$showcase_log"; then
  showcase_status="passed"
else
  showcase_status="failed"
fi

{
  echo "Windows platform evidence summary:"
  echo "  route=examples/showcase/windows_skia"
  echo "  skia_commit=$skia_commit"
  echo "  showcase_exit_status=$showcase_exit"
  echo "  showcase_first_frame_status=$showcase_status"
  echo "  preflight_log=$preflight_log"
  echo "  showcase_log=$showcase_log"
  echo "  summary_log=$summary_log"
} | tee "$summary_log"

if [[ "$showcase_status" != "passed" ]]; then
  echo "Showcase Windows Skia first-frame evidence failed; see $showcase_log" >&2
  exit 1
fi

echo "Windows Showcase evidence passed. Summary: $summary_log"
