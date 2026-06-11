#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WINDOW_VERSION="${MOUI_WINDOW_VERSION:-0.5.1-fork.3}"
WINDOW_PACKAGE="wzzc-dev/window@${WINDOW_VERSION}"
WINDOW_ZIP="${MOUI_WINDOW_PACKAGE_ZIP:-$HOME/.moon/registry/cache/wzzc-dev/window/${WINDOW_VERSION}.zip}"

usage() {
  cat <<EOF
Usage: scripts/run-window-package-smoke.sh <macos|web|windows|linux> [smoke args...]

Extracts ${WINDOW_PACKAGE} from the MoonBit registry cache to a temporary
directory and runs that package's MoUI smoke helper without requiring an
editable window checkout.

Set MOUI_WINDOW_PACKAGE_ZIP to use an explicit package zip. If the cache is
missing, run moon update from the MoUI repository first.

For macOS runtime evidence collection, set WINDOW_MOUI_MACOS_SMOKE_LOG_PATH to
the log file path expected by the window package smoke helper.
EOF
}

if [ "$#" -lt 1 ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  [ "$#" -lt 1 ] && exit 2 || exit 0
fi

platform="$1"
shift

case "$platform" in
  macos|web|windows|linux)
    ;;
  *)
    printf 'unknown window package smoke platform: %s\n' "$platform" >&2
    usage >&2
    exit 2
    ;;
esac

if [ ! -f "$WINDOW_ZIP" ]; then
  printf '%s package cache not found: %s\n' "$WINDOW_PACKAGE" "$WINDOW_ZIP" >&2
  printf 'Run moon update from %s, then retry.\n' "$ROOT_DIR" >&2
  exit 1
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/moui-window-package-smoke.XXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

unzip -q "$WINDOW_ZIP" -d "$tmp_dir/window"

case "$platform" in
  macos)
    helper="scripts/check_moui_macos_smoke.sh"
    ;;
  web)
    helper="scripts/check_moui_web_smoke.sh"
    ;;
  windows)
    helper="scripts/check_moui_windows_smoke.sh"
    ;;
  linux)
    helper="scripts/check_moui_linux_smoke.sh"
    ;;
esac

if [ ! -f "$tmp_dir/window/$helper" ]; then
  printf '%s package cache is missing %s\n' "$WINDOW_PACKAGE" "$helper" >&2
  exit 1
fi

(
  cd "$tmp_dir/window"
  bash "$helper" "$@"
)
