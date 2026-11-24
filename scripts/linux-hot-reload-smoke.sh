#!/usr/bin/env bash
set -euo pipefail

# Linux native dev hot-reload smoke (manual / path-triggered).
#
# Builds the generated bridge host and counter plugin, then drives `moui dev
# --hot` under Xvfb: edit the app, wait for a new generation to be loaded into
# the same host process, force a compile error and confirm the old generation
# stays live, then fix it and confirm recovery. The script restores the counter
# source through a trap even when a leg fails.
#
# Usage:
#   scripts/linux-hot-reload-smoke.sh --run
#
# Environment:
#   MOUI_HOT_SMOKE_TIMEOUT  seconds to wait per leg (default 240)
#   DISPLAY                 existing X display; unset uses xvfb-run
#
# Evidence: artifacts/linux-hot-reload/smoke.log

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "${1:-}" != "--run" ]]; then
  echo "usage: scripts/linux-hot-reload-smoke.sh --run" >&2
  exit 2
fi

fail() { printf 'linux-hot-reload smoke failed: %s\n' "$1" >&2; exit 1; }

if [[ "$(uname -s)" != "Linux" ]]; then
  fail "this smoke is Linux-only"
fi

if [[ -z "${DISPLAY:-}" ]]; then
  command -v xvfb-run >/dev/null 2>&1 \
    || fail "no DISPLAY and xvfb-run is not installed"
  exec xvfb-run -a -s "-screen 0 1280x800x24" "$0" --run
fi

for tool in node moon cc pgrep sed; do
  command -v "$tool" >/dev/null 2>&1 || fail "missing tool: $tool"
done

app="examples/counter/app/app.mbt"
[[ -f "$app" ]] || fail "counter app source missing: $app"
grep -Fq 'text("MoUI Counter")' "$app" \
  || fail "counter source no longer has the expected title literal"
grep -Fq 'count: model.count + 1' "$app" \
  || fail "counter source no longer has the expected increment arm"

evidence_dir="artifacts/linux-hot-reload"
mkdir -p "$evidence_dir"
log="$evidence_dir/smoke.log"
: > "$log"

backup="$(mktemp)"
cp "$app" "$backup"
runner_pid=""
host_pid=""

cleanup() {
  if [[ -n "$runner_pid" ]] && kill -0 "$runner_pid" 2>/dev/null; then
    kill -TERM "$runner_pid" 2>/dev/null || true
    for _ in $(seq 1 20); do
      kill -0 "$runner_pid" 2>/dev/null || break
      sleep 0.25
    done
    kill -KILL "$runner_pid" 2>/dev/null || true
  fi
  if [[ -n "$host_pid" ]] && kill -0 "$host_pid" 2>/dev/null; then
    kill -TERM "$host_pid" 2>/dev/null || true
  fi
  cp "$backup" "$app"
  rm -f "$backup"
}
trap cleanup EXIT

wait_for_log() {
  local pattern="$1" label="$2" timeout="${3:-${MOUI_HOT_SMOKE_TIMEOUT:-240}}"
  local deadline=$(( $(date +%s) + timeout ))
  while (( $(date +%s) < deadline )); do
    grep -Fq "$pattern" "$log" && return 0
    kill -0 "$runner_pid" 2>/dev/null || fail "dev runner exited while waiting for $label"
    sleep 0.5
  done
  fail "timed out waiting for $label (pattern: $pattern)"
}

wait_for_status() {
  local phase="$1" generation="$2" label="$3" timeout="${4:-${MOUI_HOT_SMOKE_TIMEOUT:-240}}"
  local deadline=$(( $(date +%s) + timeout ))
  while (( $(date +%s) < deadline )); do
    if grep -Fq "\"phase\": \"$phase\"" ".moui/dev-status.json" 2>/dev/null &&
      grep -Fq "\"generation\": $generation" ".moui/dev-status.json" 2>/dev/null; then
      return 0
    fi
    kill -0 "$runner_pid" 2>/dev/null || fail "dev runner exited while waiting for $label"
    sleep 0.5
  done
  fail "timed out waiting for $label"
}

reload_close_count() {
  local count
  count="$(grep -c "reload-old dlclose=1" "$log" 2>/dev/null || true)"
  printf '%s' "${count:-0}"
}

find_host_pid() {
  local pid
  pid="$(pgrep -P "$runner_pid" -n 2>/dev/null || true)"
  [[ -n "$pid" ]] || fail "could not find the dev host child process"
  printf '%s' "$pid"
}

MOUI_SKIA_RENDERER="${MOUI_SKIA_RENDERER:-skia-raster}" \
MOUI_HOT_DEBUG=1 \
node scripts/moui-dev.mjs --package examples/counter --hot --interval-ms 250 \
  >> "$log" 2>&1 &
runner_pid=$!

wait_for_log "hot plugin ready (generation 1" "first plugin generation"
wait_for_log "moui windowing backend:" "host window"
host_pid="$(find_host_pid)"
kill -0 "$host_pid" 2>/dev/null || fail "hot host is not running"
echo "generation 1 loaded; host pid=$host_pid"

# 1. A source edit swaps the plugin inside the same host process.
sed -i 's/text("MoUI Counter")/text("MoUI Counter smoke")/' "$app"
wait_for_status "running" 2 "generation 2 reload"
wait_for_log "reload-old dlclose=1 rc=0 images=1" "Linux image unmap"
[[ "$(find_host_pid)" == "$host_pid" ]] || fail "host pid changed across a reload"
echo "generation 2 loaded; host pid retained"

# 2. A compile error keeps the previous generation live and the host running.
closed_before="$(reload_close_count)"
sed -i 's/count: model.count + 1/count: model.count + hot_smoke_missing_symbol/' "$app"
wait_for_status "error" 2 "build error"
sleep 1
kill -0 "$host_pid" 2>/dev/null || fail "host exited on a build error"
closed_after="$(reload_close_count)"
[[ "$closed_after" == "$closed_before" ]] \
  || fail "host swapped a generation after a failed build"
echo "build error kept generation 2 live"

# 3. Fixing the source recovers with another in-place swap.
sed -i 's/count: model.count + hot_smoke_missing_symbol/count: model.count + 1/' "$app"
wait_for_status "running" 3 "generation 3 recovery"
[[ "$(reload_close_count)" -gt "$closed_after" ]] \
  || fail "generation 3 did not close the previous image"
[[ "$(find_host_pid)" == "$host_pid" ]] || fail "host pid changed during recovery"
echo "generation 3 recovered; host pid retained"

echo "linux-hot-reload smoke passed"
