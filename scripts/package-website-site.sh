#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"

OUT_DIR="dist/pages"
SKIP_DOCS=false
SKIP_PLAYGROUND=false
VERIFY=true

usage() {
  printf 'Usage: %s [--out <dir>] [--skip-docs] [--skip-playground] [--no-verify]\n' "$0"
  printf '\n'
  printf 'One-shot local/GitHub Pages layout for the MoUI website:\n'
  printf '  <out>/                 packaged website/web_wasm\n'
  printf '  <out>/playground/      packaged website playground (unless --skip-playground)\n'
  printf '  <out>/docs/            synced docs catalog (unless --skip-docs)\n'
  printf '\n'
  printf 'Default --out: dist/pages (same shape as .github/workflows/pages.yml).\n'
  printf '\n'
  printf 'Serve after packaging (site root = out dir):\n'
  printf '  cd dist/pages && python3 -m http.server 8080 --bind 127.0.0.1\n'
  printf '  open http://127.0.0.1:8080/\n'
  printf '  open http://127.0.0.1:8080/playground/\n'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --out)
      shift
      if [ "$#" -eq 0 ]; then
        printf 'Missing value for --out\n' >&2
        usage >&2
        exit 2
      fi
      OUT_DIR="$1"
      ;;
    --skip-docs)
      SKIP_DOCS=true
      ;;
    --skip-playground)
      SKIP_PLAYGROUND=true
      ;;
    --no-verify)
      VERIFY=false
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

run() {
  printf '\n==> %s\n' "$*"
  "$@"
}

run node scripts/package-web-app.mjs website/web_wasm --out "$OUT_DIR"

if ! "$SKIP_PLAYGROUND"; then
  run node scripts/package-website-playground.mjs --out "$OUT_DIR/playground"
fi

if ! "$SKIP_DOCS"; then
  run node scripts/sync-website-docs.mjs --out "$OUT_DIR/docs"
fi

if "$VERIFY"; then
  printf '\n==> verify site layout under %s\n' "$OUT_DIR"
  test -f "$OUT_DIR/index.html"
  test -f "$OUT_DIR/web_wasm.wasm"
  test -f "$OUT_DIR/runtime.js"
  test -f "$OUT_DIR/browser_runtime.js"
  test -f "$OUT_DIR/canvas2d_runtime.js"
  test -f "$OUT_DIR/semantics_dom.js"
  test -f "$OUT_DIR/bundle-size.json"
  if ! "$SKIP_DOCS"; then
    test -f "$OUT_DIR/docs/catalog.json"
    test -f "$OUT_DIR/docs/architecture.md"
  fi
  if ! "$SKIP_PLAYGROUND"; then
    test -f "$OUT_DIR/playground/index.html"
    test -f "$OUT_DIR/playground/playground.wasm"
    test -f "$OUT_DIR/playground/runtime.js"
    test -f "$OUT_DIR/playground/host/compiler-worker.js"
    test -f "$OUT_DIR/playground/assets/moonc-web.cjs"
    test -f "$OUT_DIR/playground/assets/manifest.json"
    test -f "$OUT_DIR/playground/lessons/catalog.json"
    run node scripts/test-playground-assets.mjs --root "$OUT_DIR/playground"
  fi
fi

printf '\nWebsite site ready: %s\n' "$OUT_DIR"
printf 'Serve from the out directory as site root, for example:\n'
printf '  cd %s && python3 -m http.server 8080 --bind 127.0.0.1\n' "$OUT_DIR"
printf '  home:        http://127.0.0.1:8080/\n'
if ! "$SKIP_PLAYGROUND"; then
  printf '  playground:  http://127.0.0.1:8080/playground/\n'
fi
