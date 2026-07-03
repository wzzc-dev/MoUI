#!/usr/bin/env sh
# Toggle bobzhang/openseek between local submodule source and mooncakes.io.
#
# Default (mooncakes mode): moon.work does NOT list "./openseek".
#
# Dev mode: moon.work lists "./openseek" so Mo Workbench resolves
# bobzhang/openseek packages from the git submodule checkout.
#
# Usage:
#   sh scripts/openseek-dev-mode.sh on
#   sh scripts/openseek-dev-mode.sh off
#   sh scripts/openseek-dev-mode.sh status
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
MOON_WORK="$ROOT_DIR/moon.work"
OPENSEEK_MEMBER='  "./openseek",'
ANCHOR='  "./examples/mo_workbench",'

usage() {
  cat <<EOF
Usage: sh scripts/openseek-dev-mode.sh <on|off|status>

  on       Resolve bobzhang/openseek from local ./openseek submodule.
  off      Do not list ./openseek in moon.work (mooncakes / no local override).
  status   Print current mode.
EOF
}

current_mode() {
  if grep -qF "$OPENSEEK_MEMBER" "$MOON_WORK"; then
    echo "dev"
  else
    echo "mooncakes"
  fi
}

ensure_submodule() {
  if [ ! -f "$ROOT_DIR/openseek/moon.mod" ]; then
    printf '==> openseek submodule missing. Running: git submodule update --init openseek\n' >&2
    cd "$ROOT_DIR"
    git submodule update --init openseek
  fi
}

case "${1:-}" in
  on)
    if [ "$(current_mode)" = "dev" ]; then
      printf 'Already in dev mode (moon.work lists "./openseek").\n'
      exit 0
    fi
    ensure_submodule
    awk -v anchor="$ANCHOR" -v entry="$OPENSEEK_MEMBER" '
      { print }
      $0 == anchor { print entry }
    ' "$MOON_WORK" > "$MOON_WORK.tmp" && mv "$MOON_WORK.tmp" "$MOON_WORK"
    printf 'Switched to openseek dev mode. moon.work now lists "./openseek".\n'
    printf 'Run `sh scripts/openseek-dev-mode.sh off` before committing unless intentional.\n'
    ;;

  off)
    if [ "$(current_mode)" = "mooncakes" ]; then
      printf 'Already in mooncakes mode (moon.work does not list "./openseek").\n'
      exit 0
    fi
    grep -vF "$OPENSEEK_MEMBER" "$MOON_WORK" > "$MOON_WORK.tmp" && mv "$MOON_WORK.tmp" "$MOON_WORK"
    printf 'Removed "./openseek" from moon.work.\n'
    ;;

  status)
    mode="$(current_mode)"
    if [ "$mode" = "dev" ]; then
      printf 'openseek dev mode: moon.work lists "./openseek".\n'
      exit 1
    fi
    printf 'openseek mooncakes mode: moon.work does not list "./openseek".\n'
    exit 0
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