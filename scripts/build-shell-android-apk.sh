#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/build-shell-android-apk.sh --app <counter|showcase> [options]

Repository example wrapper over moui_shell/scripts/build-android-apk.sh.
USAGE
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app=""

args=("$@")
index=0
while [ "$index" -lt "${#args[@]}" ]; do
  case "${args[$index]}" in
    --app)
      app="${args[$((index + 1))]:-}"
      index=$((index + 2))
      ;;
    -h|--help)
      usage
      bash "$repo_root/moui_shell/scripts/build-android-apk.sh" --help
      exit 0
      ;;
    *)
      index=$((index + 1))
      ;;
  esac
done

if [ -z "$app" ]; then
  echo "--app is required" >&2
  usage >&2
  exit 2
fi

case "$app" in
  counter|showcase) ;;
  *)
    echo "unknown repository shell app: $app" >&2
    exit 2
    ;;
esac

exec bash "$repo_root/moui_shell/scripts/build-android-apk.sh" \
  --workspace-root "$repo_root" \
  --moui-root "$repo_root/moui" \
  --skia-root "$repo_root/moui_skia" \
  "$@"
