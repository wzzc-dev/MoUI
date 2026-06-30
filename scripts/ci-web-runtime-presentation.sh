#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"

WEB_RUNTIME_HTTP_PORT="${WEB_RUNTIME_HTTP_PORT:-18080}"
WEB_RUNTIME_CDP_PORT="${WEB_RUNTIME_CDP_PORT:-9223}"
WEB_RUNTIME_BASE_URL="${WEB_RUNTIME_BASE_URL:-http://127.0.0.1:${WEB_RUNTIME_HTTP_PORT}}"
WEB_RUNTIME_CDP_URL="${WEB_RUNTIME_CDP_URL:-http://127.0.0.1:${WEB_RUNTIME_CDP_PORT}}"
WEB_RUNTIME_PRESENTATION_MANIFEST="${WEB_RUNTIME_PRESENTATION_MANIFEST:-artifacts/smoke/web-runtime-presentation/presentation-smoke.json}"
WEB_RUNTIME_PRESENTATION_TIMEOUT_MS="${WEB_RUNTIME_PRESENTATION_TIMEOUT_MS:-20000}"

SERVER_PID=""
CHROME_PID=""
USER_DATA_DIR=""

cleanup() {
  if [ -n "$CHROME_PID" ]; then
    kill "$CHROME_PID" >/dev/null 2>&1 || true
    wait "$CHROME_PID" >/dev/null 2>&1 || true
  fi
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" >/dev/null 2>&1 || true
  fi
  if [ -n "$USER_DATA_DIR" ]; then
    for _attempt in 1 2 3; do
      if rm -rf "$USER_DATA_DIR" 2>/dev/null; then
        break
      fi
      sleep 1
    done
    rm -rf "$USER_DATA_DIR" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

run() {
  printf '\n==> %s\n' "$*"
  "$@"
}

wait_for_url() {
  url="$1"
  label="$2"
  timeout_seconds="$3"
  deadline=$(( $(date +%s) + timeout_seconds ))
  while :; do
    if curl -fsS "$url" >/dev/null 2>&1; then
      printf '%s ready: %s\n' "$label" "$url"
      return 0
    fi
    if [ "$(date +%s)" -ge "$deadline" ]; then
      printf '%s did not become ready: %s\n' "$label" "$url" >&2
      return 1
    fi
    sleep 1
  done
}

find_chrome() {
  if [ -n "${WEB_RUNTIME_CHROME_BIN:-}" ]; then
    if [ -x "$WEB_RUNTIME_CHROME_BIN" ] || command -v "$WEB_RUNTIME_CHROME_BIN" >/dev/null 2>&1; then
      printf '%s\n' "$WEB_RUNTIME_CHROME_BIN"
      return 0
    fi
    printf 'WEB_RUNTIME_CHROME_BIN is not executable or on PATH: %s\n' "$WEB_RUNTIME_CHROME_BIN" >&2
    return 1
  fi

  for candidate in google-chrome-stable google-chrome chromium-browser chromium; do
    if command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi
  done

  # macOS: Chrome is installed in /Applications, not on PATH
  case "$(uname -s)" in
    Darwin)
      for app_path in \
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
        "/Applications/Chromium.app/Contents/MacOS/Chromium" \
        "$HOME/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
        "$HOME/Applications/Chromium.app/Contents/MacOS/Chromium"; do
        if [ -x "$app_path" ]; then
          printf '%s\n' "$app_path"
          return 0
        fi
      done
      ;;
  esac

  printf 'No Chrome or Chromium binary found for Web runtime presentation smoke.\n' >&2
  return 1
}

mkdir -p artifacts/smoke/web-runtime-presentation

run moon build examples/showcase/web_wasm --target wasm-gc

printf '\n==> python3 -m http.server %s --bind 127.0.0.1\n' "$WEB_RUNTIME_HTTP_PORT"
python3 -m http.server "$WEB_RUNTIME_HTTP_PORT" --bind 127.0.0.1 \
  > artifacts/smoke/web-runtime-presentation/http-server.log 2>&1 &
SERVER_PID="$!"
wait_for_url "${WEB_RUNTIME_BASE_URL}/" "static server" 30

CHROME_BIN="$(find_chrome)"
USER_DATA_DIR="$(mktemp -d "${TMPDIR:-/tmp}/moui-web-runtime-presentation.XXXXXX")"
printf '\n==> %s --headless=new --remote-debugging-port=%s\n' "$CHROME_BIN" "$WEB_RUNTIME_CDP_PORT"
"$CHROME_BIN" \
  --headless=new \
  --remote-debugging-address=127.0.0.1 \
  --remote-debugging-port="$WEB_RUNTIME_CDP_PORT" \
  --enable-unsafe-webgpu \
  --enable-features=Vulkan,UnsafeWebGPU \
  --use-angle=swiftshader \
  --use-gl=angle \
  --use-vulkan=swiftshader \
  --no-sandbox \
  --disable-dev-shm-usage \
  --user-data-dir="$USER_DATA_DIR" \
  about:blank \
  > artifacts/smoke/web-runtime-presentation/chrome.log 2>&1 &
CHROME_PID="$!"
wait_for_url "${WEB_RUNTIME_CDP_URL}/json/version" "Chrome CDP" 60

presentation_status=0
run node scripts/record-web-runtime-presentation.mjs \
  --base-url "$WEB_RUNTIME_BASE_URL" \
  --cdp-url "$WEB_RUNTIME_CDP_URL" \
  --manifest "$WEB_RUNTIME_PRESENTATION_MANIFEST" \
  --timeout-ms "$WEB_RUNTIME_PRESENTATION_TIMEOUT_MS" \
  --require-passed || presentation_status="$?"

if [ "$presentation_status" -ne 0 ]; then
  exit "$presentation_status"
fi

run node scripts/validate-web-runtime-presentation-manifest.mjs \
  "$WEB_RUNTIME_PRESENTATION_MANIFEST" \
  --require-passed
