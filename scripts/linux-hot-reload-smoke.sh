#!/usr/bin/env bash
set -euo pipefail

# Linux native dev hot-reload smoke (manual / path-triggered).
#
# Drives `moui dev --hot` under Xvfb with the rich probe app: a real frame
# vocabulary (image, divider, shadow, clips, text), timer-driven updates, and
# click injection for opt-in model state. It proves:
#   1. generation 1 draws every probe command with unsupported=0 and ticks;
#   2. a synthetic click reaches the plugin, changing Count: 0 -> Count: 1;
#   3. editing the app swaps in generation 2 in the same host pid and the
#      pre-swap Count: 1 survives;
#   4. editing the shared widget package outside the app module swaps in
#      generation 3 (dependency-closure watching) with the new shared text;
#   5. a compile error keeps generation 3 live and the host running;
#   6. fixing the source recovers as generation 4, state intact, with the
#      Linux dlclose image-unmap marker.
#
# Usage:
#   scripts/linux-hot-reload-smoke.sh --run
#
# Environment:
#   MOUI_HOT_SMOKE_TIMEOUT  seconds to wait per leg (default 300)
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

evidence_dir="artifacts/linux-hot-reload"
mkdir -p "$evidence_dir"
log="$evidence_dir/smoke.log"
: > "$log"

app_backup="$(mktemp)"
widgets_backup="$(mktemp)"
cp "$app" "$app_backup"
cp "$widgets" "$widgets_backup"
runner_pid=""
host_pid=""

# Start from a clean opt-in state so the injected click is the only source of
# Count: 1 in this run.
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

# Wait for a traced frame that starts after a marker line and contains every
# requested needle. Frame traces use unsupported=0 only when every decoded
# command painted.
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

MOUI_SKIA_RENDERER="${MOUI_SKIA_RENDERER:-skia-raster}" \
MOUI_HOT_DEBUG=1 \
MOUI_HOT_FRAME_TRACE_INTERVAL="${MOUI_HOT_FRAME_TRACE_INTERVAL:-40}" \
MOUI_HOT_INJECT_FILE="$inject_file" \
node scripts/moui-dev.mjs --package examples/hot_reload_probe --hot --interval-ms 250 \
  >> "$log" 2>&1 &
runner_pid=$!

wait_for_log "hot plugin ready (generation 1" "first plugin generation"
wait_for_log "moui windowing backend:" "host window"
host_pid="$(find_host_pid)"
kill -0 "$host_pid" 2>/dev/null || fail "hot host is not running"
echo "generation 1 loaded; host pid=$host_pid"

# 1. Rich frame vocabulary: every decoded command paints, and the animation
# clock/timer keep ticking instead of freezing at time 0.
wait_for_frame_after 1 "generation 1 rich frame" "${MOUI_HOT_SMOKE_TIMEOUT:-300}" \
  "Hot Reload Probe" "Count: 0" "Ticks: " "Shared: shared alpha" "clock " >/dev/null
rich_line="$(tail -n +1 "$log" | grep -F "unsupported=0" | grep -F "texts=[" | tail -n 1)"
assert_kinds "$rich_line"
if grep -Fq "unsupported=" "$log" && grep -E "unsupported=[1-9]" "$log" >/dev/null; then
  fail "a hot frame reported unsupported draw commands"
fi
tick_before="$(last_tick)"
deadline=$(( $(date +%s) + 30 ))
while (( $(date +%s) < deadline )); do
  tick_after="$(last_tick)"
  [[ -n "$tick_before" && -n "$tick_after" && "$tick_after" -gt "$tick_before" ]] && break
  sleep 1
done
[[ "${tick_after:-0}" -gt "${tick_before:-0}" ]] || fail "app timer ticks did not advance"
echo "generation 1 frame vocabulary complete; ticks ${tick_before} -> ${tick_after}"

# 2. Inject a click at the probe's tap target. Count is opt-in persisted model
# state, so it is the value that must survive the upcoming swap.
inject_line="$(log_line_count)"
printf '%s\n' \
  '{"kind":"pointer","phase":"Down","x":260,"y":180,"button":0,"id":1}' \
  '{"kind":"pointer","phase":"Up","x":260,"y":180,"button":0,"id":1}' >> "$inject_file"
wait_for_frame_after "$inject_line" "injected click" 60 \
  "Count: 1" >/dev/null
echo "synthetic click reached the plugin (Count: 1)"

# 3. An app edit swaps the plugin inside the same host process; Count: 1 must
# still be there after the new generation loads.
closed_before="$(reload_close_count)"
sed -i 's/text("Hot Reload Probe")/text("Hot Reload Probe smoke")/' "$app"
wait_for_status "running" 2 "generation 2 reload"
wait_for_log "hot plugin ready (generation 2" "generation 2 plugin"
gen2_line="$(grep -n -F "hot plugin ready (generation 2" "$log" | tail -n 1 | cut -d: -f1)"
wait_for_frame_after "$gen2_line" "generation 2 state-preserved frame" "${MOUI_HOT_SMOKE_TIMEOUT:-300}" \
  "Hot Reload Probe smoke" "Count: 1" "Shared: shared alpha" >/dev/null
wait_for_log "reload-old dlclose=1 rc=0 images=1" "Linux image unmap"
[[ "$(find_host_pid)" == "$host_pid" ]] || fail "host pid changed across a reload"
[[ "$(reload_close_count)" -gt "$closed_before" ]] || fail "generation 2 did not close the previous image"
echo "generation 2 loaded; host pid retained; pre-swap Count: 1 preserved"

# 4. Edit a package the app imports from outside the app module. The watcher
# must rebuild from the dependency closure, not only app-directory files.
closed_before="$(reload_close_count)"
sed -i 's/"shared alpha"/"shared beta"/' "$widgets"
wait_for_status "running" 3 "generation 3 shared-package reload"
wait_for_log "hot plugin ready (generation 3" "generation 3 plugin"
gen3_line="$(grep -n -F "hot plugin ready (generation 3" "$log" | tail -n 1 | cut -d: -f1)"
wait_for_frame_after "$gen3_line" "generation 3 shared-widget frame" "${MOUI_HOT_SMOKE_TIMEOUT:-300}" \
  "Hot Reload Probe smoke" "Count: 1" "Shared: shared beta" >/dev/null
[[ "$(find_host_pid)" == "$host_pid" ]] || fail "host pid changed on the shared-package reload"
[[ "$(reload_close_count)" -gt "$closed_before" ]] || fail "generation 3 did not close the previous image"
echo "generation 3 loaded from the imported widget package; host pid retained"

# 5. A compile error keeps generation 3 live and the host running.
closed_before="$(reload_close_count)"
sed -i 's/count: model.count + 1/count: model.count + hot_smoke_missing_symbol/' "$app"
wait_for_status "error" 3 "build error"
sleep 1
kill -0 "$host_pid" 2>/dev/null || fail "host exited on a build error"
[[ "$(reload_close_count)" == "$closed_before" ]] \
  || fail "host swapped a generation after a failed build"
wait_for_frame_after "$gen3_line" "generation 3 survives the failed build" 30 \
  "Shared: shared beta" "Count: 1" >/dev/null
echo "build error kept generation 3 live with Count: 1"

# 6. Fixing the source recovers with generation 4 and preserves the model.
sed -i 's/count: model.count + hot_smoke_missing_symbol/count: model.count + 1/' "$app"
wait_for_status "running" 4 "generation 4 recovery"
wait_for_log "hot plugin ready (generation 4" "generation 4 plugin"
gen4_line="$(grep -n -F "hot plugin ready (generation 4" "$log" | tail -n 1 | cut -d: -f1)"
wait_for_frame_after "$gen4_line" "generation 4 recovered frame" "${MOUI_HOT_SMOKE_TIMEOUT:-300}" \
  "Hot Reload Probe smoke" "Shared: shared beta" "Count: 1" >/dev/null
[[ "$(reload_close_count)" -gt "$closed_before" ]] \
  || fail "generation 4 did not close the previous image"
[[ "$(find_host_pid)" == "$host_pid" ]] || fail "host pid changed during recovery"
echo "generation 4 recovered; host pid retained; Count: 1 preserved"

echo "linux-hot-reload smoke passed"
