#!/usr/bin/env sh
set -eu

root_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$root_dir"

web_port="${MOUI_A11Y_WEB_PORT:-18082}"
cdp_port="${MOUI_A11Y_CDP_PORT:-9225}"
base_url="${MOUI_A11Y_WEB_BASE_URL:-http://127.0.0.1:${web_port}}"
cdp_url="${MOUI_A11Y_WEB_CDP_URL:-http://127.0.0.1:${cdp_port}}"
manifest="${MOUI_A11Y_WEB_MANIFEST:-artifacts/accessibility/web/manifest.json}"
server_pid=""
chrome_pid=""
user_data_dir=""

cleanup() {
  [ -z "$chrome_pid" ] || kill "$chrome_pid" >/dev/null 2>&1 || true
  [ -z "$server_pid" ] || kill "$server_pid" >/dev/null 2>&1 || true
  [ -z "$chrome_pid" ] || wait "$chrome_pid" >/dev/null 2>&1 || true
  [ -z "$server_pid" ] || wait "$server_pid" >/dev/null 2>&1 || true
  [ -z "$user_data_dir" ] || rm -rf "$user_data_dir" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

find_chrome() {
  if [ -n "${WEB_RUNTIME_CHROME_BIN:-}" ]; then printf '%s\n' "$WEB_RUNTIME_CHROME_BIN"; return 0; fi
  for candidate in google-chrome-stable google-chrome chromium-browser chromium; do
    command -v "$candidate" >/dev/null 2>&1 && command -v "$candidate" && return 0
  done
  for candidate in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" "/Applications/Chromium.app/Contents/MacOS/Chromium"; do
    [ -x "$candidate" ] && printf '%s\n' "$candidate" && return 0
  done
  return 1
}

run() {
  printf '\n==> %s\n' "$*"
  "$@"
}

mkdir -p artifacts/accessibility/web
run moon build examples/showcase/web_wasm --target wasm-gc
python3 -m http.server "$web_port" --bind 127.0.0.1 > artifacts/accessibility/web/http-server.log 2>&1 &
server_pid="$!"
chrome_bin="$(find_chrome)"
user_data_dir="$(mktemp -d "${TMPDIR:-/tmp}/moui-a11y-web.XXXXXX")"
"$chrome_bin" --headless=new --remote-debugging-address=127.0.0.1 --remote-debugging-port="$cdp_port" --enable-unsafe-webgpu --enable-features=Vulkan,UnsafeWebGPU --use-angle=swiftshader --use-gl=angle --use-vulkan=swiftshader --no-sandbox --disable-dev-shm-usage --user-data-dir="$user_data_dir" about:blank > artifacts/accessibility/web/chrome.log 2>&1 &
chrome_pid="$!"

deadline=$(( $(date +%s) + 60 ))
while ! curl -fsS "$cdp_url/json/version" >/dev/null 2>&1; do
  [ "$(date +%s)" -lt "$deadline" ] || { echo "Chrome CDP did not become ready" >&2; exit 1; }
  sleep 1
done

node scripts/record-web-accessibility-evidence.mjs --base-url "$base_url" --cdp-url "$cdp_url" --manifest "$manifest" --require-passed
