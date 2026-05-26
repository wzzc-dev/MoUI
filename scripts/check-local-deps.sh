#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
WINDOW_DIR="$ROOT_DIR/.local_repos/window"
WINDOW_BRANCH="moui-support"

fail() {
  printf 'local dependency check failed: %s\n' "$1" >&2
  exit 1
}

[ -d "$WINDOW_DIR/.git" ] || fail "missing .local_repos/window checkout; run sh scripts/setup-local-deps.sh"

case "$(git -C "$WINDOW_DIR" remote get-url origin 2>/dev/null || true)" in
  *wzzc-dev/window.git|*wzzc-dev/window)
    ;;
  *)
    fail ".local_repos/window origin must be the wzzc-dev/window fork over SSH or HTTPS"
    ;;
esac

case "$(git -C "$WINDOW_DIR" remote get-url upstream 2>/dev/null || true)" in
  *moonbit-community/window.git|*moonbit-community/window)
    ;;
  *)
    fail ".local_repos/window upstream remote must point at moonbit-community/window; run sh scripts/setup-local-deps.sh"
    ;;
esac

[ "$(git -C "$WINDOW_DIR" branch --show-current)" = "$WINDOW_BRANCH" ] ||
  fail ".local_repos/window must be on branch $WINDOW_BRANCH"

grep -q '"Milky2018/window@0.5.1"' "$ROOT_DIR/moon.mod" ||
  fail "moon.mod must import Milky2018/window@0.5.1"

grep -q '".local_repos/window"' "$ROOT_DIR/moon.work" ||
  fail "moon.work must include .local_repos/window"

for pkg in core dpi web windows linux macos; do
  [ -f "$WINDOW_DIR/$pkg/moon.pkg" ] || fail "missing .local_repos/window/$pkg/moon.pkg"
done

printf 'Local dependency check passed.\n'
