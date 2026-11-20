#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/windows-platform-evidence.sh [options]

Collects Windows Skia platform evidence from the canonical Showcase route:
0. Compiles and tests the moui_sun/softbuffer native stub, so a broken Win32
   presenter fails fast before the Skia build.
1. Resolves the requested real Skia provider.
2. Runs the 60-cell Sun-vs-Skia control matrix on this host and the parity
   gate. The matrix executable gets the release provider's icudtl.dat so Skia
   text shaping is the real reference. The gate is report-only by default;
   `--parity-blocking` turns threshold misses into a red run.
3. Builds and runs examples/showcase/windows_skia with first-frame auto-exit. The
   moui_skia/build.mbtx prebuild compiles the Skia C++ stub and emits the final
   link config, so no package file is patched and MOON_CC stays untouched.
4. Writes logs under artifacts/platform-evidence/windows/.

Run this from an MSVC developer environment (cl.exe and lib.exe on PATH, e.g.
inside `vcvarsall.bat x64`); the prebuild shells out to cl for the C++ stub.

Options:
  --log-dir PATH          Evidence output directory.
                          Default: artifacts/platform-evidence/windows.
  --skia-provider release|existing
                          Skia acquisition mode. Default: release.
  --link-mode static|dynamic|auto
                          Skia link mode. Default: static.
  --dry-run-config        Print resolved options and exit without building.
  --parity-blocking       Exit non-zero when the Sun-vs-Skia parity gate misses
                          its thresholds. Default: report-only (the status is
                          recorded in the summary and the run still exits 0)
                          until CI reproduces the local numbers.
  -h, --help              Show this help.

For --skia-provider existing, set MOUI_SKIA_SKIA_ROOT,
MOUI_SKIA_SKIA_INCLUDE, and MOUI_SKIA_SKIA_LIB_DIR.
EOF
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log_dir="$REPO_ROOT/artifacts/platform-evidence/windows"
skia_provider="${MOUI_SKIA_SKIA_PROVIDER:-release}"
skia_link_mode="${MOUI_SKIA_LINK_MODE:-static}"
parity_blocking="${MOUI_WINDOWS_VISUAL_PARITY_BLOCKING:-0}"
dry_run_config=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --log-dir) log_dir="${2:-}"; shift 2 ;;
    --skia-provider) skia_provider="${2:-}"; shift 2 ;;
    --link-mode) skia_link_mode="${2:-}"; shift 2 ;;
    --parity-blocking) parity_blocking=1; shift ;;
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
showcase_log="$resolved_log_dir/showcase-windows-skia-first-frame.log"
preflight_log="$resolved_log_dir/windows-platform-evidence-preflight.log"
summary_log="$resolved_log_dir/windows-platform-evidence-summary.log"

mkdir -p "$resolved_log_dir"

# The shell works in POSIX paths, but node and moon are native executables that
# only understand Windows paths (and node's path.resolve would read "/c/..."
# as "C:\c\..."). cygpath exists in Git Bash; other shells pass paths through.
to_native() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  else
    printf '%s\n' "$1"
  fi
}

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

echo "=== Step 0: Run moui_sun/softbuffer native smoke ===" | tee -a "$preflight_log"
softbuffer_log="$resolved_log_dir/softbuffer-native-smoke.log"
cd "$REPO_ROOT"
if moon test moui_sun/softbuffer --target native > "$softbuffer_log" 2>&1; then
  echo "  softbuffer native smoke passed" | tee -a "$preflight_log"
else
  tail -n 20 "$softbuffer_log" >&2
  echo "moui_sun/softbuffer native smoke failed; see $softbuffer_log" >&2
  exit 1
fi

# The prebuild owns the Skia link config; nothing in the tree is rewritten, so
# there is no package backup or restore step to manage here.

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

echo "=== Step 2: Export Skia provider environment ===" | tee -a "$preflight_log"
# moui_skia/build.mbtx reads the provider paths from the environment and compiles
# native/*.cpp with cl's own /std:c++20, so mbt never injects its /std:c11 stub
# flags and the D8016 clash cannot occur. The final link gets the Skia flags from
# the prebuild's link_configs, so no package file is patched.
export MOUI_SKIA_PLATFORM=windows
export MOUI_SKIA_SKIA_ROOT="$skia_root"
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

echo "=== Step 3: Run Windows Sun-vs-Skia visual parity ===" | tee -a "$preflight_log"
cd "$REPO_ROOT"
parity_dir="$resolved_log_dir/visual-parity"
parity_log="$parity_dir/gate.log"
mkdir -p "$parity_dir"

# Build once so icudtl.dat can be staged next to the executable before either
# matrix runs; SkLoadICU only searches the module directory.
moon -C moui_tests build visual_matrix --target native 2>&1 \
  | tee -a "$preflight_log"
matrix_exe="$(find "$REPO_ROOT/_build/native/debug/build" -name visual_matrix.exe -print -quit 2>/dev/null || true)"
if [[ -z "$matrix_exe" ]]; then
  echo "visual_matrix executable not found after build" >&2
  exit 1
fi
matrix_dir="$(dirname "$matrix_exe")"
icu_src="$skia_lib_dir/icudtl.dat"
if [[ -f "$icu_src" ]]; then
  cp "$icu_src" "$matrix_dir/icudtl.dat"
  echo "  icudtl.dat staged next to visual_matrix" | tee -a "$preflight_log"
else
  echo "  WARNING: $icu_src missing; Skia text shaping falls back to DirectWrite" \
    | tee -a "$preflight_log"
fi

node scripts/visual-control-matrix.mjs --renderer sun \
  --out "$(to_native "$parity_dir/sun")" 2>&1 | tee -a "$preflight_log"
node scripts/visual-control-matrix.mjs --renderer skia \
  --out "$(to_native "$parity_dir/skia")" 2>&1 | tee -a "$preflight_log"
if node scripts/visual-parity-gate.mjs \
  --sun "$(to_native "$parity_dir/sun")" \
  --skia "$(to_native "$parity_dir/skia")" \
  2>&1 | tee "$parity_log"; then
  parity_status="passed"
else
  parity_status="failed"
fi

if [[ "$parity_blocking" == "1" ]]; then
  parity_enforcement="blocking"
else
  parity_enforcement="report-only"
fi

echo "=== Step 4: Build Showcase Windows Skia ===" | tee -a "$preflight_log"
cd "$REPO_ROOT"
moon build examples/showcase/windows_skia --target native 2>&1 \
  | tee -a "$preflight_log"

echo "=== Step 4.5: Stage Skia ICU data next to the executable ===" | tee -a "$preflight_log"
# Skia's SkLoadICU only searches the exe/module directories (the ICU_DATA
# environment variable is ignored), so the release Skia package's icudtl.dat
# must be staged next to the executable before the run.
exe_dir="$REPO_ROOT/_build/native/debug/build/examples/showcase/windows_skia"
icu_src="$skia_lib_dir/icudtl.dat"
mkdir -p "$exe_dir"
rm -f "$exe_dir/icudtl.dat"
if ln "$icu_src" "$exe_dir/icudtl.dat" 2>/dev/null || cp "$icu_src" "$exe_dir/icudtl.dat" 2>/dev/null; then
  echo "  icudtl.dat staged from $icu_src" | tee -a "$preflight_log"
else
  echo "  WARNING: could not stage $icu_src; SkParagraph text layout will degrade" | tee -a "$preflight_log"
fi

echo "=== Step 5: Run Showcase first-frame smoke ===" | tee -a "$preflight_log"
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
  echo "  softbuffer_smoke_status=passed"
  echo "  skia_commit=$skia_commit"
  echo "  visual_parity_status=$parity_status"
  echo "  visual_parity_enforcement=$parity_enforcement"
  echo "  visual_parity_log=$parity_log"
  echo "  showcase_exit_status=$showcase_exit"
  echo "  showcase_first_frame_status=$showcase_status"
  echo "  preflight_log=$preflight_log"
  echo "  showcase_log=$showcase_log"
  echo "  summary_log=$summary_log"
} | tee "$summary_log"

if [[ "$parity_status" != "passed" ]]; then
  if [[ "$parity_blocking" == "1" ]]; then
    echo "Windows Sun-vs-Skia visual parity failed; see $parity_log" >&2
    exit 1
  fi
  echo "Windows Sun-vs-Skia visual parity failed (report-only); see $parity_log" >&2
fi

if [[ "$showcase_status" != "passed" ]]; then
  echo "Showcase Windows Skia first-frame evidence failed; see $showcase_log" >&2
  exit 1
fi

echo "Windows Showcase evidence passed. Summary: $summary_log"
