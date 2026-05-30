#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"

PACKAGE="examples/showcase/web_wasm"
TARGET="wasm-gc"
WATCH=false
INTERVAL=1

usage() {
  printf 'Usage: %s [--package <dir>] [--target <target>] [--watch] [--interval <seconds>]\n' "$0"
  printf '\n'
  printf 'Builds a preview package once, or rebuilds it when MoonBit/docs inputs change.\n'
  printf 'Default package: examples/showcase/web_wasm\n'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --package)
      shift
      PACKAGE="$1"
      ;;
    --target)
      shift
      TARGET="$1"
      ;;
    --watch)
      WATCH=true
      ;;
    --interval)
      shift
      INTERVAL="$1"
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

snapshot_inputs() {
  find moui examples docs resource skills scripts README.md AGENTS.md moon.work -type f \
    \( -name '*.mbt' -o -name '*.mbti' -o -name '*.json' -o -name '*.md' -o -name '*.html' -o -name '*.js' -o -name '*.css' -o -name '*.sh' -o -name '*.mjs' -o -name 'moon.work' \) \
    -print0 2>/dev/null | {
      case "$(uname -s)" in
        Darwin|FreeBSD|OpenBSD|NetBSD)
          xargs -0 stat -f '%m %N' 2>/dev/null
          ;;
        *)
          xargs -0 stat -c '%Y %n' 2>/dev/null
          ;;
      esac
    } | sort
}

build_preview() {
  printf '\n==> moon build %s --target %s\n' "$PACKAGE" "$TARGET"
  moon build "$PACKAGE" --target "$TARGET"
  printf 'Preview build ready: %s (%s)\n' "$PACKAGE" "$TARGET"
}

build_preview

if ! "$WATCH"; then
  exit 0
fi

printf '\nWatching for changes every %s second(s). Press Ctrl-C to stop.\n' "$INTERVAL"
LAST_SNAPSHOT="$(snapshot_inputs)"
while :; do
  sleep "$INTERVAL"
  NEXT_SNAPSHOT="$(snapshot_inputs)"
  if [ "$NEXT_SNAPSHOT" != "$LAST_SNAPSHOT" ]; then
    LAST_SNAPSHOT="$NEXT_SNAPSHOT"
    build_preview
  fi
done
