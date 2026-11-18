#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/linux-platform-evidence.sh [options]

Collects Linux platform runtime evidence by:
1. Resolving the release Skia provider
2. Building the Showcase and first-frame smoke test; the moui_skia/build.mbtx
   prebuild compiles the Skia C++ stub and emits the final link config, so no
   package files are patched
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
# Step 1: Fetch the release Skia provider
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
# Step 2: Export the Skia provider environment
#
echo "=== Step 2: Export Skia provider environment ===" | tee -a "$preflight_log"
# moui_skia/build.mbtx reads the provider paths from the environment, compiles
# native/*.cpp itself (no mbt stub-cc-flags), and emits the final link config,
# so example packages need no hand-written Skia flags.
export MOUI_SKIA_PLATFORM=linux
export MOUI_SKIA_SKIA_INCLUDE="$skia_include"
export MOUI_SKIA_SKIA_LIB_DIR="$skia_lib_dir"
export MOUI_SKIA_LINK_MODE="$skia_link_mode"
export MOUI_SKIA_STUB_MODE=build
export MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1
if [[ $enable_skparagraph -eq 1 ]]; then
  export MOUI_SKIA_ENABLE_SKPARAGRAPH=1
fi
if [[ $require_skparagraph -eq 1 ]]; then
  export MOUI_SKIA_REQUIRE_SKPARAGRAPH=1
fi
unset MOUI_SKIA_DISABLE_PREBUILD_SKIA
unset MOUI_SKIA_STUB_LIB
{
  echo "  MOUI_SKIA_PLATFORM=$MOUI_SKIA_PLATFORM"
  echo "  MOUI_SKIA_SKIA_INCLUDE=$MOUI_SKIA_SKIA_INCLUDE"
  echo "  MOUI_SKIA_SKIA_LIB_DIR=$MOUI_SKIA_SKIA_LIB_DIR"
  echo "  MOUI_SKIA_LINK_MODE=$MOUI_SKIA_LINK_MODE"
  echo "  MOUI_SKIA_STUB_MODE=$MOUI_SKIA_STUB_MODE"
  echo "  MOUI_SKIA_ENABLE_SKPARAGRAPH=${MOUI_SKIA_ENABLE_SKPARAGRAPH:-0}"
  echo "  MOUI_SKIA_REQUIRE_SKPARAGRAPH=${MOUI_SKIA_REQUIRE_SKPARAGRAPH:-0}"
} | tee -a "$preflight_log"

#
# Step 3: Build showcase and first-frame smoke test
#
echo "=== Step 3: Build targets ===" | tee -a "$preflight_log"

cd "$REPO_ROOT"
moon build examples/showcase/linux_skia --target native 2>&1 | tee -a "$preflight_log"
echo "  Built examples/showcase/linux_skia" | tee -a "$preflight_log"

moon build moui_tests/tester/linux_skia_first_frame_smoke --target native 2>&1 | tee -a "$preflight_log"
echo "  Built moui_tests/tester/linux_skia_first_frame_smoke" | tee -a "$preflight_log"

#
# Step 4: Start Weston headless
#
echo "=== Step 4: Start headless Weston compositor ===" | tee -a "$preflight_log"

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
trap cleanup_weston EXIT

FIRST_FRAME_MARKER="Linux renderer presented first frame; exiting by request; title=MoUI Text Input Smoke"
FIRST_FRAME_TIMEOUT_SECONDS="${MOUI_LINUX_FIRST_FRAME_TIMEOUT_SECONDS:-60}"
gpu_first_frame_status="passed"

#
# Step 5: Run raster, GPU, and automatic-fallback first-frame smoke tests
#
echo "=== Step 5: Run renderer-mode first-frame smoke tests ===" | tee -a "$preflight_log"
cd "$REPO_ROOT"

gpu_surface_available() {
  # Skia GPU needs a Vulkan/OpenGL ES surface, which requires a DRM render
  # node on the host. Headless Weston on a GPU-less CI runner never provides
  # one, so the skia-gpu first-frame marker can never be produced there
  # regardless of MoUI state; GPU proof for those hosts is a runbook activity
  # (docs/gpu-promotion-runbook.md), not a headless-runner assertion.
  compgen -G "/dev/dri/renderD*" >/dev/null 2>&1
}

run_first_frame_mode() {
  local mode="$1"
  local output="$2"
  local rc=0
  local timed_out=0
  echo "  Running MOUI_SKIA_RENDERER=$mode" | tee -a "$preflight_log"
  if command -v timeout >/dev/null 2>&1; then
    MOUI_FIRST_FRAME_EXIT=1 \
      MOUI_SKIA_RENDERER="$mode" \
      MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 \
      timeout --signal=TERM --kill-after=10s "${FIRST_FRAME_TIMEOUT_SECONDS}s" \
        moon run moui_tests/tester/linux_skia_first_frame_smoke --target native \
          > "$output" 2>&1 || rc=$?
    if [[ $rc -eq 124 ]]; then
      timed_out=1
    fi
  else
    MOUI_FIRST_FRAME_EXIT=1 \
      MOUI_SKIA_RENDERER="$mode" \
      MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 \
      moon run moui_tests/tester/linux_skia_first_frame_smoke --target native \
        > "$output" 2>&1 || rc=$?
  fi
  if ! grep -Fq "$FIRST_FRAME_MARKER" "$output"; then
    if [[ $timed_out -eq 1 ]]; then
      echo "$mode first-frame smoke timed out after ${FIRST_FRAME_TIMEOUT_SECONDS}s" >&2
    else
      echo "Missing first-frame marker for MOUI_SKIA_RENDERER=$mode" >&2
    fi
    return 1
  fi
  echo "  Verified $mode first-frame marker." | tee -a "$preflight_log"
}

run_first_frame_mode "skia-raster" "$first_frame_raster_log"

if gpu_surface_available; then
  run_first_frame_mode "skia-gpu" "$first_frame_gpu_log"
else
  gpu_first_frame_status="skipped (no /dev/dri/renderD* GPU render node on this host)"
  echo "  No DRM render node on this host; headless Weston cannot provide a" | tee -a "$preflight_log"
  echo "  Vulkan/OpenGL ES surface, so the skia-gpu first-frame marker can never" | tee -a "$preflight_log"
  echo "  be produced here. Recording skia-gpu as skipped; the auto run below" | tee -a "$preflight_log"
  echo "  still proves GPU-first selection falls back to a raster present." | tee -a "$preflight_log"
fi

run_first_frame_mode "auto" "$first_frame_log"

#
# Step 6: Generate summary
#
echo "=== Step 6: Generate evidence summary ===" | tee -a "$preflight_log"
{
  echo "Linux platform evidence summary:"
  echo "  skia_commit=$skia_commit"
  echo "  raster_first_frame_status=passed"
  echo "  gpu_first_frame_status=$gpu_first_frame_status"
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
