#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/linux-platform-evidence.sh [options]

Collects Linux platform runtime evidence by:
1. Configuring the repository for real Skia linking (release provider)
2. Building the Showcase and first-frame smoke test with release Skia
3. Starting a headless Weston Wayland compositor
4. Running raster, GPU, and automatic-fallback first-frame smokes
5. Collecting evidence logs under artifacts/platform-evidence/linux/

Options:
  --log-dir PATH          Output directory for evidence logs.
                          Default: artifacts/platform-evidence/linux.
  --skia-provider release|source|existing
                          Skia acquisition mode. Default: release.
  --link-mode static|dynamic|auto
                          Skia link mode. Default: static.
  --enable-skparagraph    Enable SkParagraph linking. Default: on for Skia.
  --require-skparagraph   Require SkParagraph and fail if missing.
  --dry-run-config        Print resolved paths and exit without building.
  -h, --help              Show this help.

Environment defaults:
  MOUI_SKIA_SKIA_PROVIDER, MOUI_SKIA_LINK_MODE are used when the matching
  command-line option is omitted.
EOF
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log_dir="$REPO_ROOT/artifacts/platform-evidence/linux"
skia_provider="${MOUI_SKIA_SKIA_PROVIDER:-release}"
skia_link_mode="${MOUI_SKIA_LINK_MODE:-static}"
enable_skparagraph=1
require_skparagraph=0
dry_run_config=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --log-dir) log_dir="${2:-}"; shift 2 ;;
    --skia-provider) skia_provider="${2:-}"; shift 2 ;;
    --link-mode) skia_link_mode="${2:-}"; shift 2 ;;
    --enable-skparagraph) enable_skparagraph=1; shift ;;
    --require-skparagraph) require_skparagraph=1; shift ;;
    --dry-run-config) dry_run_config=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

skia_repo="$REPO_ROOT/moui_skia"
case "$log_dir" in
  /*) resolved_log_dir="$log_dir" ;;
  *) resolved_log_dir="$REPO_ROOT/$log_dir" ;;
esac

first_frame_log="$resolved_log_dir/linux-skia-first-frame.log"
first_frame_raster_log="$resolved_log_dir/linux-skia-raster-first-frame.log"
first_frame_gpu_log="$resolved_log_dir/linux-skia-gpu-first-frame.log"
preflight_log="$resolved_log_dir/linux-platform-evidence-preflight.log"
summary_log="$resolved_log_dir/linux-platform-evidence-summary.log"
weston_log="$resolved_log_dir/weston-headless.log"

echo "Linux platform evidence run:
  log_dir=$resolved_log_dir
  skia_provider=$skia_provider
  skia_link_mode=$skia_link_mode
  enable_skparagraph=$enable_skparagraph
  require_skparagraph=$require_skparagraph
" | tee "$preflight_log"

if [[ $dry_run_config -eq 1 ]]; then
  echo "Dry run; no operations performed." | tee -a "$preflight_log"
  exit 0
fi

mkdir -p "$resolved_log_dir"

#
# Step 1: Fetch release Skia and configure native/moon.pkg
#
echo "=== Step 1: Fetch release Skia provider ===" | tee -a "$preflight_log"
fetch_args=(
  --platform linux
  --arch auto
  --config Release
  --link-mode "$skia_link_mode"
  --print-env
)
fetch_output="$(bash "$skia_repo/scripts/fetch-release-skia.sh" "${fetch_args[@]}")"

extract_env() {
  printf '%s\n' "$fetch_output" | sed -n "s/^${1}=//p" | tail -n 1
}

skia_include="$(extract_env MOUI_SKIA_SKIA_INCLUDE)"
skia_lib_dir="$(extract_env MOUI_SKIA_SKIA_LIB_DIR)"
skia_lib="$(extract_env MOUI_SKIA_SKIA_LIB)"
skia_commit="$(extract_env MOUI_SKIA_SKIA_COMMIT)"

echo "  skia_include=$skia_include
  skia_lib_dir=$skia_lib_dir
  skia_lib=$skia_lib
  skia_commit=$skia_commit" | tee -a "$preflight_log"

if [[ -z "$skia_include" || -z "$skia_lib_dir" || -z "$skia_lib" ]]; then
  echo "Skia provider did not resolve complete paths" >&2
  exit 1
fi

#
# Step 2: Configure native/moon.pkg via configure-linux-native-pkg.sh
#
echo "=== Step 2: Configure moui_skia/native/moon.pkg ===" | tee -a "$preflight_log"
configure_args=(
  --skia-include "$skia_include"
  --skia-lib-dir "$skia_lib_dir"
  --skia-lib "$skia_lib"
  --link-mode "$skia_link_mode"
)
if [[ $enable_skparagraph -eq 1 ]]; then
  configure_args+=(--enable-skparagraph)
fi
if [[ $require_skparagraph -eq 1 ]]; then
  configure_args+=(--require-skparagraph)
fi

bash "$skia_repo/scripts/configure-linux-native-pkg.sh" \
  "${configure_args[@]}" \
  --write >/dev/null

echo "  Configured moui_skia/native/moon.pkg" | tee -a "$preflight_log"

# Compute Skia link flags for example packages by reading generated output
generated_output="$(bash "$skia_repo/scripts/configure-linux-native-pkg.sh" \
  "${configure_args[@]}")"

linux_link_flags="$(printf '%s\n' "$generated_output" | sed -n 's/.*"cc-link-flags": "\(.*\)",/\1/p')"
linux_stub_cc_flags="$(printf '%s\n' "$generated_output" | sed -n 's/.*"stub-cc-flags": "\(.*\)",/\1/p')"

echo "  Skia link flags: $linux_link_flags
  Stub CC flags: $linux_stub_cc_flags" | tee -a "$preflight_log"

#
# Step 3: Configure package moon.pkg files for example targets
#
echo "=== Step 3: Configure example package moon.pkg files ===" | tee -a "$preflight_log"

showcase_pkg="$REPO_ROOT/examples/showcase/linux_skia/moon.pkg"
showcase_backup="$showcase_pkg.moui-evidence.bak"
cp "$showcase_pkg" "$showcase_backup"

cat > "$showcase_pkg" <<PKGEOF
import {
  "moonbitlang/core/env",
  "wzzc-dev/moui" @moui,
  "wzzc-dev/moui/runtime",
  "wzzc-dev/moui/backend",
  "wzzc-dev/moui/backend/linux" @linux_backend,
  "wzzc-dev/moui/render/skia" @render_skia,
  "examples/showcase/app" @showcase_app,
}

supported_targets = "native"

options(
  "is-main": true,
  link: {
    "native": {
      "stub-cc-flags": "$linux_stub_cc_flags",
      "cc-link-flags": "$linux_link_flags",
    },
  },
  targets: { "main.mbt": [ "native" ] },
)
PKGEOF
echo "  Wrote $showcase_pkg" | tee -a "$preflight_log"

# Also configure the first-frame smoke test moon.pkg
first_frame_pkg="$REPO_ROOT/moui_tester/linux_skia_first_frame_smoke/moon.pkg"
first_frame_backup="$first_frame_pkg.moui-evidence.bak"
cp "$first_frame_pkg" "$first_frame_backup"

cat > "$first_frame_pkg" <<PKGEOF
import {
  "wzzc-dev/moui" @moui,
  "wzzc-dev/moui/backend/linux",
  "wzzc-dev/moui/render/skia" @render_skia,
  "wzzc-dev/moui_tester/fixtures/text_input_app" @fixture,
}

supported_targets = "native"

options(
  "is-main": true,
  link: {
    "native": {
      "stub-cc-flags": "$linux_stub_cc_flags",
      "cc-link-flags": "$linux_link_flags",
    },
  },
  targets: { "main.mbt": [ "native" ] },
)
PKGEOF
echo "  Wrote $first_frame_pkg" | tee -a "$preflight_log"

restore_packages() {
  if [[ -f "$showcase_backup" ]]; then
    cp "$showcase_backup" "$showcase_pkg"
    rm -f "$showcase_backup"
    echo "Restored $showcase_pkg"
  fi
  if [[ -f "$first_frame_backup" ]]; then
    cp "$first_frame_backup" "$first_frame_pkg"
    rm -f "$first_frame_backup"
    echo "Restored $first_frame_pkg"
  fi
  cd "$REPO_ROOT"
  git checkout -- moui_skia/native/moon.pkg 2>/dev/null || true
}
trap restore_packages EXIT

#
# Step 4: Build showcase and first-frame smoke test
#
echo "=== Step 4: Build targets ===" | tee -a "$preflight_log"

cd "$REPO_ROOT"
MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 \
  MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 \
  moon build examples/showcase/linux_skia --target native 2>&1 | tee -a "$preflight_log"
echo "  Built examples/showcase/linux_skia" | tee -a "$preflight_log"

MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 \
  MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 \
  moon build moui_tester/linux_skia_first_frame_smoke --target native 2>&1 | tee -a "$preflight_log"
echo "  Built moui_tester/linux_skia_first_frame_smoke" | tee -a "$preflight_log"

#
# Step 5: Start Weston headless
#
echo "=== Step 5: Start headless Weston compositor ===" | tee -a "$preflight_log"

weston_socket="moui-linux-evidence"
if command -v weston >/dev/null 2>&1; then
  weston --backend=headless-backend.so --socket="$weston_socket" \
    --idle-time=0 \
    > "$weston_log" 2>&1 &
  weston_pid=$!
  echo "  Started Weston (PID $weston_pid) on socket $weston_socket" | tee -a "$preflight_log"

  for i in $(seq 1 30); do
    socket_path="$XDG_RUNTIME_DIR/$weston_socket"
    if [[ -S "$socket_path" ]]; then
      echo "  Weston ready after ${i}s" | tee -a "$preflight_log"
      break
    fi
    sleep 1
  done

  export WAYLAND_DISPLAY="$weston_socket"
else
  echo "  Weston not found; running without a Wayland compositor" | tee -a "$preflight_log"
  echo "  NOTE: Evidence will be partial without a real Wayland compositor" | tee -a "$preflight_log"
  weston_pid=""
fi

cleanup_weston() {
  if [[ -n "${weston_pid:-}" ]]; then
    kill "$weston_pid" 2>/dev/null || true
    wait "$weston_pid" 2>/dev/null || true
  fi
}
trap 'cleanup_weston; restore_packages' EXIT

#
# Step 6: Run raster, GPU, and automatic-fallback first-frame smoke tests
#
echo "=== Step 6: Run renderer-mode first-frame smoke tests ===" | tee -a "$preflight_log"
cd "$REPO_ROOT"
run_first_frame_mode() {
  local mode="$1"
  local output="$2"
  echo "  Running MOUI_SKIA_RENDERER=$mode" | tee -a "$preflight_log"
  MOUI_FIRST_FRAME_EXIT=1 \
    MOUI_SKIA_RENDERER="$mode" \
    MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 \
    MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 \
    moon run moui_tester/linux_skia_first_frame_smoke --target native \
      > "$output" 2>&1
  if ! grep -Fq "Linux renderer presented first frame; exiting by request; title=MoUI Text Input Smoke" "$output"; then
    echo "Missing first-frame marker for MOUI_SKIA_RENDERER=$mode" >&2
    return 1
  fi
  echo "  Verified $mode first-frame marker." | tee -a "$preflight_log"
}

run_first_frame_mode "skia-raster" "$first_frame_raster_log"
run_first_frame_mode "skia-gpu" "$first_frame_gpu_log"
run_first_frame_mode "auto" "$first_frame_log"

#
# Step 7: Generate summary
#
echo "=== Step 7: Generate evidence summary ===" | tee -a "$preflight_log"
{
  echo "Linux platform evidence summary:"
  echo "  skia_commit=$skia_commit"
  echo "  raster_first_frame_status=passed"
  echo "  gpu_first_frame_status=passed"
  echo "  auto_first_frame_status=passed"
  echo "  preflight_log=$preflight_log"
  echo "  raster_first_frame_log=$first_frame_raster_log"
  echo "  gpu_first_frame_log=$first_frame_gpu_log"
  echo "  first_frame_log=$first_frame_log"
  echo "  weston_log=$weston_log"
  echo "  summary_log=$summary_log"
} | tee "$summary_log"

echo ""
echo "Linux platform evidence collected. Logs:"
echo "  Raster:        $first_frame_raster_log"
echo "  GPU:           $first_frame_gpu_log"
echo "  Auto fallback: $first_frame_log"
echo "  Weston:        $weston_log"
echo "  Summary:       $summary_log"
echo "  Preflight:     $preflight_log"
