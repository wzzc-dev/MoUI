#!/usr/bin/env bash
# Detached macOS Metal GPU performance run for ADR-length windows.
# Use this for 600s+ so agent tool timeouts cannot kill the measurement.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

duration_ms="${1:-600000}"
warm_up="${2:-60}"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
out_dir="${3:-artifacts/gpu-promotion/macos/perf-gpu-${duration_ms}ms-${stamp}}"
promotion_lifecycle="${4:-0}"
mkdir -p "$out_dir"

# Skia/Metal flags are injected by moui_skia prebuild; no local moon.pkg rewrite.
args=(
  --duration-ms "$duration_ms"
  --warm-up-presents "$warm_up"
  --out-dir "$out_dir"
)
if [[ "$promotion_lifecycle" == "1" || "$promotion_lifecycle" == "true" ]]; then
  args+=(--promotion-lifecycle --surface-cycles 100 --fg-bg-cycles 100 --context-loss 1)
fi

nohup node scripts/run-macos-gpu-performance-smoke.mjs \
  "${args[@]}" \
  >"$out_dir/console.log" 2>&1 &
echo $! >"$out_dir/pid"

cat <<EOF
started pid=$(cat "$out_dir/pid")
out_dir=$out_dir
promotion_lifecycle=$promotion_lifecycle
tail -f $out_dir/macos-gpu-performance-smoke.log
# wait for:
#   MoUI macOS GPU performance smoke completed ...
# and optionally:
#   MoUI macOS GPU promotion lifecycle completed ...
EOF
