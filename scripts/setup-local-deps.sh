#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
WINDOW_DIR="$ROOT_DIR/.local_repos/window"
WINDOW_REMOTE_SSH="git@github.com:wzzc-dev/window.git"
WINDOW_REMOTE_HTTPS="https://github.com/wzzc-dev/window.git"
WINDOW_UPSTREAM="https://github.com/moonbit-community/window.git"
WINDOW_BRANCH="moui-support"
MOUI_SKIA_DIR="$ROOT_DIR/moui_skia"

if [ -n "${MOUI_WINDOW_REMOTE:-}" ]; then
  WINDOW_REMOTE="$MOUI_WINDOW_REMOTE"
elif [ -n "${CI:-}" ]; then
  WINDOW_REMOTE="$WINDOW_REMOTE_HTTPS"
else
  WINDOW_REMOTE="$WINDOW_REMOTE_SSH"
fi

run() {
  printf '==> %s\n' "$*"
  "$@"
}

assert_clean_worktree() {
  repo_dir="$1"
  status="$(git -C "$repo_dir" status --porcelain)"
  if [ -n "$status" ]; then
    printf '%s has local changes. Commit, stash, or discard them before updating local dependencies.\n' "$repo_dir" >&2
    exit 1
  fi
}

checkout_and_fast_forward() {
  repo_dir="$1"
  branch="$2"

  assert_clean_worktree "$repo_dir"
  run git -C "$repo_dir" fetch origin "$branch" --prune

  current_branch="$(git -C "$repo_dir" branch --show-current)"
  if [ "$current_branch" != "$branch" ]; then
    if git -C "$repo_dir" show-ref --verify --quiet "refs/heads/$branch"; then
      run git -C "$repo_dir" checkout "$branch"
    else
      run git -C "$repo_dir" checkout -b "$branch" "origin/$branch"
    fi
  fi

  run git -C "$repo_dir" merge --ff-only "origin/$branch"
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
    printf 'Expected the MoUI fork: %s or %s\n' "$WINDOW_REMOTE_SSH" "$WINDOW_REMOTE_HTTPS" >&2
    exit 1
    ;;
esac

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

checkout_and_fast_forward "$WINDOW_DIR" "$WINDOW_BRANCH"

WINDOW_SUMMARY="window: $WINDOW_DIR on branch $WINDOW_BRANCH"

[ -d "$MOUI_SKIA_DIR" ] || {
  printf 'Missing repo-local moui_skia workspace at %s. Update the main MoUI checkout.\n' "$MOUI_SKIA_DIR" >&2
  exit 1
}

printf '\nLocal dependencies are ready.\n'
printf '%s\n' "$WINDOW_SUMMARY"
printf 'moui_skia: %s workspace member\n' "$MOUI_SKIA_DIR"
