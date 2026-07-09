#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/build-mobile-android-apk.sh --app <counter|component_gallery> [options]

Repository example wrapper over moui/scripts/mobile/build-android-apk.sh.
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
      "$repo_root/moui/scripts/mobile/build-android-apk.sh" --help
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
  counter|component_gallery)
    android_project="$repo_root/examples/$app/android_app"
    ;;
  *)
    echo "unknown repository mobile app: $app" >&2
    exit 2
    ;;
esac

exec "$repo_root/moui/scripts/mobile/build-android-apk.sh" \
  --workspace-root "$repo_root" \
  --moui-root "$repo_root/moui" \
  --skia-root "$repo_root/moui_skia" \
  --android-project "$android_project" \
  "$@"
