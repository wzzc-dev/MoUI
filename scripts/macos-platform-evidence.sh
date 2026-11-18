#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/macos-platform-evidence.sh [options]

Collects macOS platform runtime evidence by:
1. Resolving the release Skia provider
2. Building the Showcase macos_skia entrypoint; the moui_skia/build.mbtx
   prebuild compiles the Skia C++ stub and emits the final link config, so no
   package files are patched
3. Running the Showcase first-frame auto-exit smoke (MOUI_FIRST_FRAME_EXIT=1)
4. Running the native IME runtime smoke
5. Collecting evidence logs under artifacts/platform-evidence/macos/

Options:
  --log-dir PATH          Output directory for evidence logs.
                          Default: artifacts/platform-evidence/macos.
  --skia-provider release|source|existing
                          Skia acquisition mode. Default: release.
  --link-mode static|dynamic|auto
                          Skia link mode. Default: static.
  --run-showcase-smoke    Run the Showcase first-frame smoke (default: on).
  --run-ime-smoke         Run the Showcase native IME runtime smoke (default: on).
  --dry-run-config        Print resolved paths and exit without building.
  -h, --help              Show this help.

Environment defaults:
  MOUI_SKIA_SKIA_PROVIDER, MOUI_SKIA_LINK_MODE are used when the matching
  command-line option is omitted.
EOF
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log_dir="$REPO_ROOT/artifacts/platform-evidence/macos"
skia_provider="${MOUI_SKIA_SKIA_PROVIDER:-release}"
skia_link_mode="${MOUI_SKIA_LINK_MODE:-static}"
run_showcase=1
run_ime=1
dry_run_config=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --log-dir) log_dir="${2:-}"; shift 2 ;;
    --skia-provider) skia_provider="${2:-}"; shift 2 ;;
    --link-mode) skia_link_mode="${2:-}"; shift 2 ;;
    --run-showcase-smoke) run_showcase=1; shift ;;
    --no-showcase-smoke) run_showcase=0; shift ;;
    --run-ime-smoke) run_ime=1; shift ;;
    --no-ime-smoke) run_ime=0; shift ;;
    --dry-run-config) dry_run_config=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

skia_repo="$REPO_ROOT/moui_skia"
case "$log_dir" in
  /*|?:/*) resolved_log_dir="$log_dir" ;;
  *) resolved_log_dir="$REPO_ROOT/$log_dir" ;;
esac

showcase_log="$resolved_log_dir/showcase-macos-skia-first-frame.log"
ime_log="$resolved_log_dir/ime-showcase-runtime.log"
preflight_log="$resolved_log_dir/macos-platform-evidence-preflight.log"
summary_log="$resolved_log_dir/macos-platform-evidence-summary.log"

mkdir -p "$resolved_log_dir"

echo "macOS platform evidence run:
  log_dir=$resolved_log_dir
  skia_provider=$skia_provider
  skia_link_mode=$skia_link_mode
  run_showcase=$run_showcase
  run_ime=$run_ime
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
  --platform macos
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
export MOUI_SKIA_PLATFORM=macos
export MOUI_SKIA_SKIA_INCLUDE="$skia_include"
export MOUI_SKIA_SKIA_LIB_DIR="$skia_lib_dir"
export MOUI_SKIA_LINK_MODE="$skia_link_mode"
export MOUI_SKIA_STUB_MODE=build
export MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1
unset MOUI_SKIA_DISABLE_PREBUILD_SKIA
unset MOUI_SKIA_STUB_LIB
{
  echo "  MOUI_SKIA_PLATFORM=$MOUI_SKIA_PLATFORM"
  echo "  MOUI_SKIA_SKIA_INCLUDE=$MOUI_SKIA_SKIA_INCLUDE"
  echo "  MOUI_SKIA_SKIA_LIB_DIR=$MOUI_SKIA_SKIA_LIB_DIR"
  echo "  MOUI_SKIA_LINK_MODE=$MOUI_SKIA_LINK_MODE"
  echo "  MOUI_SKIA_STUB_MODE=$MOUI_SKIA_STUB_MODE"
} | tee -a "$preflight_log"

#
# Step 3: Build showcase
#
echo "=== Step 3: Build showcase macos_skia ===" | tee -a "$preflight_log"

cd "$REPO_ROOT"
MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 \
  moon build examples/showcase/macos_skia --target native 2>&1 | tee -a "$preflight_log"
echo "  Built examples/showcase/macos_skia" | tee -a "$preflight_log"

#
# Step 4: Run Showcase with first-frame auto-exit
#
showcase_status="skipped"
if [[ $run_showcase -eq 1 ]]; then
  echo "=== Step 4: Run Showcase first-frame smoke ===" | tee -a "$preflight_log"
  cd "$REPO_ROOT"
  MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 \
    MOUI_FIRST_FRAME_EXIT=1 \
    moon run examples/showcase/macos_skia --target native \
    > "$showcase_log" 2>&1 &
  showcase_pid=$!

  (
    sleep 60
    if kill -0 "$showcase_pid" 2>/dev/null; then
      echo "Showcase first-frame smoke timed out after 60s" >> "$showcase_log"
      kill "$showcase_pid" 2>/dev/null
    fi
  ) &
  watchdog_pid=$!
  wait "$showcase_pid"
  showcase_status=$?
  kill "$watchdog_pid" 2>/dev/null || true
  wait "$watchdog_pid" 2>/dev/null || true

  echo "  Showcase exit status: $showcase_status" | tee -a "$preflight_log"
  if grep -Fq "macOS renderer presented first frame; exiting by request; title=MoUI Showcase" "$showcase_log"; then
    echo "  Verified Showcase first-frame marker." | tee -a "$preflight_log"
  else
    echo "  WARNING: Showcase first-frame marker not found." | tee -a "$preflight_log"
  fi
fi

#
# Step 5: Optional Showcase native IME runtime smoke
#
ime_status="skipped"
if [[ $run_ime -eq 1 ]]; then
  echo "=== Step 5: Run Showcase native IME runtime smoke ===" | tee -a "$preflight_log"
  cd "$REPO_ROOT"
  MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 \
    MOUI_MACOS_NATIVE_IME_EVIDENCE=1 \
    moon run examples/showcase/macos_skia --target native \
    > "$ime_log" 2>&1 &
  ime_pid=$!

  (
    sleep 60
    if kill -0 "$ime_pid" 2>/dev/null; then
      echo "Showcase IME smoke timed out after 60s" >> "$ime_log"
      kill "$ime_pid" 2>/dev/null
    fi
  ) &
  ime_watchdog=$!
  wait "$ime_pid"
  ime_status=$?
  kill "$ime_watchdog" 2>/dev/null || true
  wait "$ime_watchdog" 2>/dev/null || true

  echo "  IME smoke exit status: $ime_status" | tee -a "$preflight_log"
  ime_markers=0
  if grep -q "NSTextInputClient" "$ime_log"; then ime_markers=$((ime_markers + 1)); fi
  if grep -q "appkit-setMarkedText" "$ime_log"; then ime_markers=$((ime_markers + 1)); fi
  if grep -q "appkit-firstRectForCharacterRange" "$ime_log"; then ime_markers=$((ime_markers + 1)); fi
  if grep -q "appkit-insertText" "$ime_log"; then ime_markers=$((ime_markers + 1)); fi
  echo "  Observed IME markers: $ime_markers/4" | tee -a "$preflight_log"
fi

#
# Step 6: Generate evidence summary
#
echo "=== Step 6: Generate evidence summary ===" | tee -a "$preflight_log"
{
  echo "macOS platform evidence summary:"
  echo "  skia_commit=$skia_commit"
  echo "  showcase_first_frame_status=$(grep -Fq "macOS renderer presented first frame; exiting by request; title=MoUI Showcase" "$showcase_log" 2>/dev/null && echo "passed" || echo "failed")"
  echo "  ime_runtime_markers=$(grep -q "NSTextInputClient" "$ime_log" 2>/dev/null && echo "present" || echo "missing")"
  echo "  preflight_log=$preflight_log"
  echo "  showcase_log=$showcase_log"
  echo "  ime_log=$ime_log"
  echo "  summary_log=$summary_log"
} | tee "$summary_log"

echo ""
echo "macOS platform evidence collected. Logs:"
echo "  Showcase:           $showcase_log"
echo "  IME runtime:        $ime_log"
echo "  Summary:            $summary_log"
echo "  Preflight:          $preflight_log"
