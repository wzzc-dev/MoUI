#!/usr/bin/env sh
# Toggle wzzc-dev/window between local workspace source and mooncakes.io.
#
# Default (mooncakes mode): moon.work does NOT list "./window", so moon
# resolves wzzc-dev/window from .mooncakes/ (the published version).
#
# Dev mode: moon.work lists "./window", so moon resolves wzzc-dev/window
# from the local submodule checkout. Use this when you need to edit window
# source and validate changes inside MoUI before publishing.
#
# Usage:
#   sh scripts/window-dev-mode.sh on       # use local window/ source
#   sh scripts/window-dev-mode.sh off      # use mooncakes.io (default)
#   sh scripts/window-dev-mode.sh status   # print current mode
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
MOON_WORK="$ROOT_DIR/moon.work"
WINDOW_MEMBER='  "./window",'
ANCHOR='  "./moui_agent_mcp",'

usage() {
  cat <<EOF
Usage: sh scripts/window-dev-mode.sh <on|off|status>

  on       Resolve wzzc-dev/window from local ./window submodule (dev mode).
           Requires the submodule to be initialized: git submodule update --init window
  off      Resolve wzzc-dev/window from mooncakes.io (default, CI-enforced).
  status   Print current mode and exit 0 if mooncakes mode, 1 if dev mode.
EOF
}

current_mode() {
  if grep -qF "$WINDOW_MEMBER" "$MOON_WORK"; then
    echo "dev"
  else
    echo "mooncakes"
  fi
}

ensure_submodule() {
  if [ ! -f "$ROOT_DIR/window/moon.mod" ]; then
    printf '==> window submodule not initialized. Running: git submodule update --init window\n' >&2
    cd "$ROOT_DIR"
    git submodule update --init window
  fi
}

case "${1:-}" in
  on)
    if [ "$(current_mode)" = "dev" ]; then
      printf 'Already in dev mode (moon.work lists "./window").\n'
      exit 0
    fi
    ensure_submodule
    # Insert "./window" right after the moui_agent_mcp anchor to preserve
    # the historical member ordering. awk handles in-place edit portably.
    awk -v anchor="$ANCHOR" -v entry="$WINDOW_MEMBER" '
      { print }
      $0 == anchor { print entry }
    ' "$MOON_WORK" > "$MOON_WORK.tmp" && mv "$MOON_WORK.tmp" "$MOON_WORK"
    printf 'Switched to dev mode. moon.work now resolves wzzc-dev/window from ./window.\n'
    printf 'Run `sh scripts/window-dev-mode.sh off` before committing.\n'
    ;;

  off)
    if [ "$(current_mode)" = "mooncakes" ]; then
      printf 'Already in mooncakes mode (moon.work does not list "./window").\n'
      exit 0
    fi
    grep -vF "$WINDOW_MEMBER" "$MOON_WORK" > "$MOON_WORK.tmp" && mv "$MOON_WORK.tmp" "$MOON_WORK"
    printf 'Switched to mooncakes mode. moon.work resolves wzzc-dev/window from .mooncakes/.\n'
    printf 'Run `moon install` to refresh the published dependency.\n'
    ;;

  status)
    mode="$(current_mode)"
    if [ "$mode" = "dev" ]; then
      printf 'window dev mode: moon.work lists "./window" (local source override).\n'
      exit 1
    else
      printf 'window mooncakes mode: moon.work does not list "./window" (published dependency).\n'
      exit 0
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
