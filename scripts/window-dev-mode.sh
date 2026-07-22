#!/usr/bin/env sh
# Toggle the local `window` and `windowing` workspace modules together.
#
# Default (mooncakes mode): moon.work does NOT list either nested window
# module, so Moon resolves published dependencies from .mooncakes/.
#
# Dev mode lists `./window/modules/window` and
# `./window/modules/windowing`, resolving the local compatibility module and
# its upstream raw-handle dependency together.
#
# Usage:
#   sh scripts/window-dev-mode.sh on       # use local window/ source
#   sh scripts/window-dev-mode.sh off      # use mooncakes.io (default)
#   sh scripts/window-dev-mode.sh status   # print current mode
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
MOON_WORK="$ROOT_DIR/moon.work"
WINDOW_MEMBER='  "./window/modules/window",'
WINDOWING_MEMBER='  "./window/modules/windowing",'
LEGACY_WINDOW_MEMBER='  "./window",'
ANCHOR='  "./moui_agent_mcp",'

usage() {
  cat <<EOF
Usage: sh scripts/window-dev-mode.sh <on|off|status>

  on       Resolve window modules from the local ./window submodule (dev mode).
           Requires the submodule to be initialized: git submodule update --init window
  off      Resolve published window modules from mooncakes.io (default, CI-enforced).
  status   Print current mode and exit 0 if mooncakes mode, 1 if dev mode.
EOF
}

current_mode() {
  has_window=false
  has_windowing=false
  has_legacy=false
  if grep -qF "$WINDOW_MEMBER" "$MOON_WORK"; then
    has_window=true
  fi
  if grep -qF "$WINDOWING_MEMBER" "$MOON_WORK"; then
    has_windowing=true
  fi
  if grep -qF "$LEGACY_WINDOW_MEMBER" "$MOON_WORK"; then
    has_legacy=true
  fi
  if [ "$has_legacy" = true ]; then
    echo "legacy"
  elif [ "$has_window" = true ] && [ "$has_windowing" = true ]; then
    echo "dev"
  elif [ "$has_window" = false ] && [ "$has_windowing" = false ]; then
    echo "mooncakes"
  else
    echo "incomplete"
  fi
}

ensure_submodule() {
  if [ ! -f "$ROOT_DIR/window/modules/window/moon.mod" ] || \
    [ ! -f "$ROOT_DIR/window/modules/windowing/moon.mod" ]; then
    printf '==> window submodule not initialized. Running: git submodule update --init window\n' >&2
    cd "$ROOT_DIR"
    git submodule update --init window
  fi
}

case "${1:-}" in
  on)
    if [ "$(current_mode)" = "dev" ]; then
      printf 'Already in dev mode (moon.work lists both local window modules).\n'
      exit 0
    fi
    ensure_submodule
    awk -v anchor="$ANCHOR" -v window="$WINDOW_MEMBER" \
      -v windowing="$WINDOWING_MEMBER" -v legacy="$LEGACY_WINDOW_MEMBER" '
      $0 == window || $0 == windowing || $0 == legacy { next }
      { print }
      $0 == anchor { print window; print windowing }
    ' "$MOON_WORK" > "$MOON_WORK.tmp" && mv "$MOON_WORK.tmp" "$MOON_WORK"
    printf 'Switched to dev mode. moon.work now resolves both local window modules.\n'
    printf 'Run `sh scripts/window-dev-mode.sh off` before committing.\n'
    ;;

  off)
    if [ "$(current_mode)" = "mooncakes" ]; then
      printf 'Already in mooncakes mode (moon.work lists no local window modules).\n'
      exit 0
    fi
    awk -v window="$WINDOW_MEMBER" -v windowing="$WINDOWING_MEMBER" \
      -v legacy="$LEGACY_WINDOW_MEMBER" '
      $0 != window && $0 != windowing && $0 != legacy { print }
    ' "$MOON_WORK" > "$MOON_WORK.tmp" && mv "$MOON_WORK.tmp" "$MOON_WORK"
    printf 'Switched to mooncakes mode. moon.work resolves published window modules.\n'
    printf 'Run `moon install` to refresh the published dependency.\n'
    ;;

  status)
    mode="$(current_mode)"
    if [ "$mode" = "dev" ]; then
      printf 'window dev mode: moon.work lists both local nested window modules.\n'
      exit 1
    elif [ "$mode" = "mooncakes" ]; then
      printf 'window mooncakes mode: moon.work lists no local window modules.\n'
      exit 0
    else
      printf 'window workspace mode is incomplete; run `sh scripts/window-dev-mode.sh on` or `off`.\n' >&2
      exit 2
    fi
    ;;

  ""|-h|--help|help)
    usage
    exit 0
    ;;

  *)
    printf 'Unknown argument: %s\n' "$1" >&2
    usage >&2
    exit 2
    ;;
esac
