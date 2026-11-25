#!/usr/bin/env bash
set -euo pipefail

# macOS native dev hot-reload smoke (manual / path-triggered).
#
# Mirrors the Linux smoke against the rich probe app: generation 1 paints the
# full probe vocabulary, timer frames advance, a synthetic click sets Count: 1,
# an app edit swaps generation 2 in the same host pid with Count: 1 intact, an
# imported-package edit swaps generation 3, a compile error keeps generation 3
# live, and recovery produces generation 4 with state still intact. The macOS
# runner keeps the 32-swap re-exec budget; a four-swap smoke stays well inside
# it.
#
# Usage:
#   scripts/macos-hot-reload-smoke.sh --run
#
# Environment:
#   MOUI_HOT_SMOKE_TIMEOUT  seconds to wait per leg (default 300)
#
# Evidence: artifacts/macos-hot-reload/smoke.log

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "${1:-}" != "--run" ]]; then
  echo "usage: scripts/macos-hot-reload-smoke.sh --run" >&2
  exit 2
fi

fail() { printf 'macos-hot-reload smoke failed: %s\n' "$1" >&2; exit 1; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "this smoke is macOS-only"
fi

for tool in node moon cc pgrep sed awk; do
  command -v "$tool" >/dev/null 2>&1 || fail "missing tool: $tool"
done

app="examples/hot_reload_probe/app/app.mbt"
widgets="examples/hot_reload_widgets/widgets/widgets.mbt"
[[ -f "$app" ]] || fail "probe app source missing: $app"
[[ -f "$widgets" ]] || fail "shared widget source missing: $widgets"
grep -Fq 'text("Hot Reload Probe")' "$app" \
  || fail "probe source no longer has the expected title literal"
grep -Fq '"shared alpha"' "$widgets" \
  || fail "shared widget source no longer has the expected label literal"

evidence_dir="artifacts/macos-hot-reload"
mkdir -p "$evidence_dir"
log="$evidence_dir/smoke.log"
: > "$log"

app_backup="$(mktemp)"
widgets_backup="$(mktemp)"
cp "$app" "$app_backup"
cp "$widgets" "$widgets_backup"
runner_pid=""
host_pid=""

rm -f .moui/dev-state.json .moui/dev-state-transient.json .moui/dev-status.json
inject_file="$evidence_dir/events.jsonl"
: > "$inject_file"

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
  cp "$app_backup" "$app"
  cp "$widgets_backup" "$widgets"
  rm -f "$app_backup" "$widgets_backup"
}
trap cleanup EXIT

# BSD/GNU sed both support -i.bak; remove the backup so a trap restore is the
# only way the source changes back.
edit_in_place() {
  local file="$1" expression="$2"
  sed -i.bak "$expression" "$file"
  rm -f "${file}.bak"
}

wait_for_log() {
  local pattern="$1" label="$2" timeout="${3:-${MOUI_HOT_SMOKE_TIMEOUT:-300}}"
  local deadline=$(( $(date +%s) + timeout ))
  while (( $(date +%s) < deadline )); do
    grep -Fq "$pattern" "$log" && return 0
    kill -0 "$runner_pid" 2>/dev/null || fail "dev runner exited while waiting for $label"
    sleep 0.5
  done
  fail "timed out waiting for $label (pattern: $pattern)"
}

# The host readiness marker is platform-specific: Linux X11 logs
# "moui windowing backend:", while macOS paints host frames. Accept either.
wait_for_any_log() {
  local label="$1" timeout="${2:-${MOUI_HOT_SMOKE_TIMEOUT:-300}}"
  shift 2
  local deadline=$(( $(date +%s) + timeout ))
  local pattern
  while (( $(date +%s) < deadline )); do
    for pattern in "$@"; do
      grep -Fq "$pattern" "$log" && return 0
    done
    kill -0 "$runner_pid" 2>/dev/null || fail "dev runner exited while waiting for $label"
    sleep 0.5
  done
  fail "timed out waiting for $label (patterns: $*)"
}

wait_for_status() {
  local phase="$1" generation="$2" label="$3" timeout="${4:-${MOUI_HOT_SMOKE_TIMEOUT:-300}}"
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

log_line_count() {
  wc -l < "$log" | tr -d ' '
}

wait_for_frame_after() {
  local start_line="$1" label="$2" timeout="$3"
  shift 3
  local deadline=$(( $(date +%s) + timeout ))
  local line
  while (( $(date +%s) < deadline )); do
    line="$(tail -n +"$start_line" "$log" | grep -F "unsupported=0" | grep -F "texts=[" | tail -n 1 || true)"
    if [[ -n "$line" ]]; then
      local matched=1
      local needle
      for needle in "$@"; do
        [[ "$line" == *"$needle"* ]] || matched=0
      done
      if [[ "$matched" == 1 ]]; then
        printf '%s\n' "$line"
        return 0
      fi
    fi
    kill -0 "$runner_pid" 2>/dev/null || fail "dev runner exited while waiting for $label"
    sleep 0.5
  done
  fail "timed out waiting for $label"
}

last_tick() {
  grep -o 'Ticks: [0-9][0-9]*' "$log" | tail -n 1 | awk '{print $2}'
}

reload_count() {
  local count
  count="$(grep -c "^moui-devhost: reloaded " "$log" 2>/dev/null || true)"
  printf '%s' "${count:-0}"
}

find_host_pid() {
  local pid
  pid="$(pgrep -P "$runner_pid" -n 2>/dev/null || true)"
  [[ -n "$pid" ]] || fail "could not find the dev host child process"
  printf '%s' "$pid"
}

assert_kinds() {
  local line="$1"
  local kinds="${line#*kinds=}"
  kinds="${kinds%% texts=*}"
  local kind
  for kind in draw_text draw_image draw_shadow push_clip pop_clip fill_rect \
    fill_rounded_rect fill_rounded_rect_brush stroke_rounded_rect_brush \
    push_rounded_clip pop_rounded_clip; do
    [[ ",$kinds," == *",$kind,"* ]] || fail "frame trace is missing command kind: $kind"
  done
}

MOUI_HOT_DEBUG=1 \
MOUI_HOT_FRAME_TRACE_INTERVAL="${MOUI_HOT_FRAME_TRACE_INTERVAL:-40}" \
MOUI_HOT_INJECT_FILE="$inject_file" \
node scripts/moui-dev.mjs --package examples/hot_reload_probe --hot --interval-ms 250 \
  >> "$log" 2>&1 &
runner_pid=$!

wait_for_log "hot plugin ready (generation 1" "first plugin generation"
wait_for_any_log "host frame" "${MOUI_HOT_SMOKE_TIMEOUT:-300}" \
  "moui-devhost: frame " "moui windowing backend:"
host_pid="$(find_host_pid)"
kill -0 "$host_pid" 2>/dev/null || fail "hot host is not running"
echo "generation 1 loaded; host pid=$host_pid"

# 1. Rich frame vocabulary and a live animation/timer clock.
wait_for_frame_after 1 "generation 1 rich frame" "${MOUI_HOT_SMOKE_TIMEOUT:-300}" \
  "Hot Reload Probe" "Count: 0" "Ticks: " "Shared: shared alpha" "clock " >/dev/null
rich_line="$(tail -n +1 "$log" | grep -F "unsupported=0" | grep -F "texts=[" | tail -n 1)"
assert_kinds "$rich_line"
if grep -Fq "unsupported=" "$log" && grep -E "unsupported=[1-9]" "$log" >/dev/null; then
  fail "a hot frame reported unsupported draw commands"
fi
tick_before="$(last_tick)"
deadline=$(( $(date +%s) + 30 ))
tick_after=""
while (( $(date +%s) < deadline )); do
  tick_after="$(last_tick)"
  [[ -n "$tick_before" && -n "$tick_after" && "$tick_after" -gt "$tick_before" ]] && break
  sleep 1
done
[[ "${tick_after:-0}" -gt "${tick_before:-0}" ]] || fail "app timer ticks did not advance"
echo "generation 1 frame vocabulary complete; ticks ${tick_before} -> ${tick_after}"

# 2. Inject a click; Count is opt-in persisted model state.
inject_line="$(log_line_count)"
printf '%s\n' \
  '{"kind":"pointer","phase":"Down","x":260,"y":180,"button":0,"id":1}' \
  '{"kind":"pointer","phase":"Up","x":260,"y":180,"button":0,"id":1}' >> "$inject_file"
wait_for_frame_after "$inject_line" "injected click" 60 \
  "Count: 1" >/dev/null
echo "synthetic click reached the plugin (Count: 1)"

# 3. App edit swaps inside the same host process with state intact.
swaps_before="$(reload_count)"
edit_in_place "$app" 's/text("Hot Reload Probe")/text("Hot Reload Probe smoke")/'
wait_for_status "running" 2 "generation 2 reload"
wait_for_log "hot plugin ready (generation 2" "generation 2 plugin"
gen2_line="$(grep -n -F "hot plugin ready (generation 2" "$log" | tail -n 1 | cut -d: -f1)"
wait_for_frame_after "$gen2_line" "generation 2 state-preserved frame" "${MOUI_HOT_SMOKE_TIMEOUT:-300}" \
  "Hot Reload Probe smoke" "Count: 1" "Shared: shared alpha" >/dev/null
wait_for_log "moui-devhost: reloaded " "host loaded generation 2"
[[ "$(find_host_pid)" == "$host_pid" ]] || fail "host pid changed across a reload"
[[ "$(reload_count)" -gt "$swaps_before" ]] || fail "host did not load generation 2"
echo "generation 2 loaded; host pid retained; pre-swap Count: 1 preserved"

# 4. Imported package outside the app module triggers a rebuild.
swaps_before="$(reload_count)"
edit_in_place "$widgets" 's/"shared alpha"/"shared beta"/'
wait_for_status "running" 3 "generation 3 shared-package reload"
wait_for_log "hot plugin ready (generation 3" "generation 3 plugin"
gen3_line="$(grep -n -F "hot plugin ready (generation 3" "$log" | tail -n 1 | cut -d: -f1)"
wait_for_frame_after "$gen3_line" "generation 3 shared-widget frame" "${MOUI_HOT_SMOKE_TIMEOUT:-300}" \
  "Hot Reload Probe smoke" "Count: 1" "Shared: shared beta" >/dev/null
[[ "$(find_host_pid)" == "$host_pid" ]] || fail "host pid changed on the shared-package reload"
[[ "$(reload_count)" -gt "$swaps_before" ]] || fail "host did not load generation 3"
echo "generation 3 loaded from the imported widget package; host pid retained"

# 5. A compile error keeps generation 3 live and the host running.
swaps_before="$(reload_count)"
edit_in_place "$app" 's/count: model.count + 1/count: model.count + hot_smoke_missing_symbol/'
wait_for_status "error" 3 "build error"
sleep 1
kill -0 "$host_pid" 2>/dev/null || fail "host exited on a build error"
[[ "$(reload_count)" == "$swaps_before" ]] \
  || fail "host swapped a generation after a failed build"
wait_for_frame_after "$gen3_line" "generation 3 survives the failed build" 30 \
  "Shared: shared beta" "Count: 1" >/dev/null
echo "build error kept generation 3 live with Count: 1"

# 6. Fixing the source recovers as generation 4 with the model intact.
edit_in_place "$app" 's/count: model.count + hot_smoke_missing_symbol/count: model.count + 1/'
wait_for_status "running" 4 "generation 4 recovery"
wait_for_log "hot plugin ready (generation 4" "generation 4 plugin"
gen4_line="$(grep -n -F "hot plugin ready (generation 4" "$log" | tail -n 1 | cut -d: -f1)"
wait_for_frame_after "$gen4_line" "generation 4 recovered frame" "${MOUI_HOT_SMOKE_TIMEOUT:-300}" \
  "Hot Reload Probe smoke" "Shared: shared beta" "Count: 1" >/dev/null
[[ "$(reload_count)" -gt "$swaps_before" ]] || fail "host did not load generation 4"
[[ "$(find_host_pid)" == "$host_pid" ]] || fail "host pid changed during recovery"
echo "generation 4 recovered; host pid retained; Count: 1 preserved"

echo "macos-hot-reload smoke passed"
