#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
WINDOW_DIR="$ROOT_DIR/.local_repos/window"
WINDOW_REMOTE="git@github.com:wzzc-dev/window.git"
WINDOW_UPSTREAM="https://github.com/moonbit-community/window.git"
WINDOW_BRANCH="moui-support"

run() {
  printf '==> %s\n' "$*"
  "$@"
}

mkdir -p "$ROOT_DIR/.local_repos"

if [ ! -d "$WINDOW_DIR/.git" ]; then
  run git clone "$WINDOW_REMOTE" "$WINDOW_DIR"
else
  printf '==> Reusing existing %s\n' "$WINDOW_DIR"
fi

cd "$WINDOW_DIR"

origin_url="$(git remote get-url origin 2>/dev/null || true)"
case "$origin_url" in
  *wzzc-dev/window.git|*wzzc-dev/window)
    ;;
  "")
    printf 'No origin remote is configured in %s\n' "$WINDOW_DIR" >&2
    exit 1
    ;;
  *)
    printf 'Unexpected window origin remote: %s\n' "$origin_url" >&2
    printf 'Expected the MoUI fork: %s\n' "$WINDOW_REMOTE" >&2
    exit 1
    ;;
esac

current_branch="$(git branch --show-current)"
if [ "$current_branch" != "$WINDOW_BRANCH" ]; then
  run git fetch origin "$WINDOW_BRANCH"
  if git show-ref --verify --quiet "refs/heads/$WINDOW_BRANCH"; then
    run git checkout "$WINDOW_BRANCH"
  else
    run git checkout -b "$WINDOW_BRANCH" "origin/$WINDOW_BRANCH"
  fi
fi

upstream_url="$(git remote get-url upstream 2>/dev/null || true)"
case "$upstream_url" in
  "")
    run git remote add upstream "$WINDOW_UPSTREAM"
    ;;
  *moonbit-community/window.git|*moonbit-community/window)
    ;;
  *)
    printf 'Unexpected window upstream remote: %s\n' "$upstream_url" >&2
    printf 'Expected upstream: %s\n' "$WINDOW_UPSTREAM" >&2
    exit 1
    ;;
esac

printf '\nLocal dependencies are ready.\n'
printf 'window: %s on branch %s\n' "$WINDOW_DIR" "$WINDOW_BRANCH"
