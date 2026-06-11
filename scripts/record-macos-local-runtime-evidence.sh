#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

manifest="artifacts/conformance/platform-runtime-evidence.json"
artifact_dir="artifacts/platform-evidence/macos"
host="macOS Darwin local host"
consumer_command="moon run examples/showcase/macos_skia --target native"
run_window_smoke=1
run_ime_smoke=1

usage() {
  cat <<'EOF'
Usage: scripts/record-macos-local-runtime-evidence.sh [options]

Collect and fold local matching-host macOS platform runtime evidence. This
script runs real AppKit/Skia entrypoints, so use it only on a macOS host where
GUI smoke runs are allowed. It does not fabricate logs and does not change
Windows, Linux, or global Skia claims.

Options:
  --manifest PATH        Platform runtime evidence manifest.
                         Default: artifacts/conformance/platform-runtime-evidence.json
  --artifact-dir PATH    macOS artifact directory.
                         Default: artifacts/platform-evidence/macos
  --host TEXT            Matching-host label for provenance.
                         Default: macOS Darwin local host
  --skip-window-smoke    Reuse an existing window-macos-runtime-smoke.log.
  --skip-ime-smoke       Reuse an existing ime-showcase-runtime.log.
  -h, --help             Show this help.

The window smoke is collected from the resolved wzzc-dev/window@0.5.1-0.1.4
registry package through scripts/run-window-package-smoke.sh; no editable
window checkout is required.

Prerequisite: macos.skiaEvidence must already be passed, normally via
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke with
--record-platform-evidence.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --manifest)
      manifest="${2:-}"
      shift 2
      ;;
    --artifact-dir)
      artifact_dir="${2:-}"
      shift 2
      ;;
    --host)
      host="${2:-}"
      shift 2
      ;;
    --skip-window-smoke)
      run_window_smoke=0
      shift
      ;;
    --skip-ime-smoke)
      run_ime_smoke=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$artifact_dir" in
  artifacts/platform-evidence/macos|artifacts/platform-evidence/macos/*)
    ;;
  *)
    printf 'artifact directory must stay under artifacts/platform-evidence/macos: %s\n' "$artifact_dir" >&2
    exit 2
    ;;
esac

artifact_abs="$ROOT_DIR/$artifact_dir"
window_log="$artifact_dir/window-macos-runtime-smoke.log"
window_log_abs="$ROOT_DIR/$window_log"
ime_log="$artifact_dir/ime-showcase-runtime.log"
ime_log_abs="$ROOT_DIR/$ime_log"
showcase_log="$artifact_dir/showcase-macos-skia-first-frame.log"

mkdir -p "$artifact_abs"

if [ "$run_window_smoke" -eq 1 ]; then
  WINDOW_MOUI_MACOS_SMOKE_LOG_PATH="$window_log_abs" \
    bash scripts/run-window-package-smoke.sh macos --run
fi

grep -Fq "MOUIMacSmoke: ready" "$window_log_abs"
grep -Fq "primary=true current=true" "$window_log_abs"
grep -Fq "MoUI macOS runtime smoke passed" "$window_log_abs"

if [ "$run_ime_smoke" -eq 1 ]; then
  MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 \
    MOUI_MACOS_NATIVE_IME_EVIDENCE=1 \
    moon run examples/showcase/macos_skia --target native \
    > "$ime_log_abs" 2>&1
fi

node scripts/record-native-ime-evidence.mjs \
  "$manifest" \
  macos \
  --host "$host" \
  --consumer-command "$consumer_command" \
  --candidate-anchor-log "$ime_log" \
  --surrounding-text-log "$ime_log" \
  --composition-visual-log "$ime_log" \
  --commit-delete-log "$ime_log" \
  --cursor-update-log "$ime_log" \
  --scroll-anchor-log "$ime_log" \
  --scale-dpr-anchor-log "$ime_log" \
  --resize-anchor-log "$ime_log" \
  --note "macOS local matching-host Showcase IME runtime artifact was folded before platform promotion."

node scripts/record-macos-platform-runtime-evidence.mjs \
  "$manifest" \
  --host "$host" \
  --consumer-command "$consumer_command" \
  --runtime-log "$ime_log" \
  --window-smoke-log "$window_log" \
  --app-runtime-log "$showcase_log" \
  --provenance-kind matching-host-artifact \
  --provenance-artifact "$window_log" \
  --provenance-artifact "$ime_log" \
  --provenance-artifact "$showcase_log" \
  --provenance-note "macOS platform runtime evidence came from local matching-host AppKit/Skia artifacts." \
  --note "macOS local matching-host platform evidence folded window smoke, Showcase IME, and Showcase Skia first-frame artifacts."

node scripts/validate-platform-evidence-manifest.mjs "$manifest" --platform macos

printf 'macOS local runtime evidence recorded and validated: %s\n' "$manifest"
