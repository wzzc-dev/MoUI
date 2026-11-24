#!/usr/bin/env bash
set -euo pipefail

# Web state-preserving hot-reload smoke (manual / path-triggered).
#
# Starts `moui dev --web --hot` for the fixture app, drives it in headless
# Chromium over CDP, then for each run edits the app source and waits for the
# rebuilt wasm to refresh the page. The first run asserts the committed model
# plus the flushed focus/scroll transient snapshot survived; the remaining runs
# measure edit-to-paint latency. The script restores the fixture source through
# a trap even when a leg fails.
#
# Usage:
#   scripts/web-hot-reload-smoke.sh --run
#
# Environment:
#   WEB_HOT_CHROME_BIN   Chromium/Chrome binary (default: Playwright cache or
#                        google-chrome/chromium from PATH)
#   WEB_HOT_RUNS         reload runs for the latency sample (default 10)
#   WEB_HOT_PORT         dev server port (default: an ephemeral free port)
#   WEB_HOT_CDP_PORT     Chrome DevTools port (default: an ephemeral free port)
#   WEB_HOT_TIMEOUT      seconds to wait for the dev build (default 180)
#
# Evidence: artifacts/web-hot-reload/{report.json,smoke.log,dev.log,chrome.log}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "${1:-}" != "--run" ]]; then
  echo "usage: scripts/web-hot-reload-smoke.sh --run" >&2
  exit 2
fi

fail() { printf 'web-hot-reload smoke failed: %s\n' "$1" >&2; exit 1; }

for tool in node moon; do
  command -v "$tool" >/dev/null 2>&1 || fail "missing tool: $tool"
done

node -e 'if (typeof WebSocket !== "function") process.exit(1)' \
  || fail "web-hot-reload smoke needs Node 22+ (the CDP client uses the global WebSocket)"

app="moui_tests/web_hot_fixture/app/app.mbt"
[[ -f "$app" ]] || fail "fixture app source missing: $app"
grep -Fq 'Web Hot Reload Fixture' "$app" || fail "fixture source changed; update this smoke"
grep -Fq 'count: model.count + 1' "$app" || fail "fixture update arm changed; update this smoke"

pick_port() {
  node -e 'const net = require("node:net"); const s = net.createServer(); s.listen(0, "127.0.0.1", () => { process.stdout.write(String(s.address().port)); s.close(); });'
}

find_chrome() {
  if [[ -n "${WEB_HOT_CHROME_BIN:-}" ]]; then
    printf '%s' "$WEB_HOT_CHROME_BIN"
    return 0
  fi
  for candidate in google-chrome google-chrome-stable chromium chromium-browser; do
    if command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi
  done
  local playwright
  playwright="$(ls -d "$HOME"/.cache/ms-playwright/chromium-*/chrome-linux64/chrome 2>/dev/null | tail -1 || true)"
  if [[ -n "$playwright" ]]; then
    printf '%s' "$playwright"
    return 0
  fi
  return 1
}

chrome_bin="$(find_chrome)" || fail "no Chrome/Chromium binary; set WEB_HOT_CHROME_BIN"
[[ -x "$chrome_bin" ]] || fail "not executable: $chrome_bin"

PORT="${WEB_HOT_PORT:-$(pick_port)}"
CDP_PORT="${WEB_HOT_CDP_PORT:-$(pick_port)}"
RUNS="${WEB_HOT_RUNS:-10}"
TIMEOUT="${WEB_HOT_TIMEOUT:-180}"
[[ "$PORT" != "$CDP_PORT" ]] || fail "dev and CDP ports must differ"

evidence_dir="artifacts/web-hot-reload"
mkdir -p "$evidence_dir"
log="$evidence_dir/smoke.log"
dev_log="$evidence_dir/dev.log"
chrome_log="$evidence_dir/chrome.log"
profile="$(mktemp -d "${TMPDIR:-/tmp}/moui-web-hot-XXXXXX")"
source_backup="$evidence_dir/app.mbt.bak"
cp "$app" "$source_backup"
: > "$log"
: > "$dev_log"
: > "$chrome_log"

dev_pid=""
chrome_pid=""

cleanup() {
  if [[ -n "$chrome_pid" ]] && kill -0 "$chrome_pid" 2>/dev/null; then
    kill -TERM "$chrome_pid" 2>/dev/null || true
    for _ in 1 2 3 4 5; do
      kill -0 "$chrome_pid" 2>/dev/null || break
      sleep 0.2
    done
    kill -KILL "$chrome_pid" 2>/dev/null || true
  fi
  if [[ -n "$dev_pid" ]] && kill -0 "$dev_pid" 2>/dev/null; then
    kill -TERM "$dev_pid" 2>/dev/null || true
    for _ in 1 2 3 4 5; do
      kill -0 "$dev_pid" 2>/dev/null || break
      sleep 0.2
    done
    kill -KILL "$dev_pid" 2>/dev/null || true
  fi
  rm -rf "$profile"
  # The driver restores the source too; do it again in case it crashed mid-run.
  cp "$source_backup" "$app"
}
trap cleanup EXIT

status_file=".moui/dev-status.json"
rm -f "$status_file"

echo "web hot reload smoke: dev port $PORT, cdp port $CDP_PORT, runs $RUNS" | tee -a "$log"

node scripts/moui-dev.mjs \
  --package moui_tests/web_hot_fixture/web_wasm \
  --web --hot --port "$PORT" --interval-ms 250 \
  >>"$dev_log" 2>&1 &
dev_pid=$!

node -e '
const fs = require("node:fs");
const [file, timeoutMs] = process.argv.slice(1);
const deadline = Date.now() + Number(timeoutMs);
const poll = () => {
  try {
    const status = JSON.parse(fs.readFileSync(file, "utf8"));
    if (status.ok && status.generation >= 1) process.exit(0);
  } catch (_) {}
  if (Date.now() > deadline) {
    console.error("dev status did not reach a ready generation");
    process.exit(1);
  }
  setTimeout(poll, 250);
};
poll();
' "$status_file" "$((TIMEOUT * 1000))" || fail "dev server did not build the fixture; see $dev_log"

"$chrome_bin" \
  --headless=new \
  --remote-debugging-address=127.0.0.1 \
  --remote-debugging-port="$CDP_PORT" \
  --no-sandbox --disable-dev-shm-usage --disable-gpu \
  --noerrdialogs --no-first-run \
  --ozone-platform=headless --ozone-override-screen-size=800,600 \
  --user-data-dir="$profile" \
  about:blank >>"$chrome_log" 2>&1 &
chrome_pid=$!

node -e '
const url = process.argv[1];
const deadline = Date.now() + 60000;
const poll = async () => {
  try {
    const response = await fetch(`${url}/json/version`);
    if (response.ok) process.exit(0);
  } catch (_) {}
  if (Date.now() > deadline) {
    console.error("Chrome DevTools endpoint did not start");
    process.exit(1);
  }
  setTimeout(poll, 200);
};
poll();
' "http://127.0.0.1:$CDP_PORT" || fail "Chrome did not expose CDP; see $chrome_log"

set +e
node scripts/web-hot-reload-smoke.mjs \
  --port "$PORT" \
  --cdp "http://127.0.0.1:$CDP_PORT" \
  --runs "$RUNS" \
  --evidence "$evidence_dir" 2>&1 | tee -a "$log"
driver_status=${PIPESTATUS[0]}
set -e

if [[ "$driver_status" -ne 0 ]]; then
  echo "--- dev log (tail) ---" | tee -a "$log"
  tail -40 "$dev_log" | tee -a "$log" || true
  fail "headless driver failed; report: $evidence_dir/report.json"
fi

echo "web hot reload smoke: ok (report: $evidence_dir/report.json)" | tee -a "$log"
