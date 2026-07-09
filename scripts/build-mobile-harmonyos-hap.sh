#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/build-mobile-harmonyos-hap.sh --app <harmonyos_demo|component_gallery> [options]

Repository example wrapper over moui/scripts/mobile/build-harmonyos-hap.sh.
USAGE
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --app)
      app="${2:?missing app after --app}"
      shift 2
      ;;
    -h|--help)
      usage
      "$repo_root/moui/scripts/mobile/build-harmonyos-hap.sh" --help
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

if [ -z "$app" ]; then
  echo "--app is required" >&2
  usage >&2
  exit 2
fi

case "$app" in
  harmonyos_demo|component_gallery)
    harmonyos_project="$repo_root/examples/$app/harmonyos_app"
    app_config="$repo_root/examples/$app/mobile.json"
    ;;
  *)
    echo "unsupported HarmonyOS app: $app" >&2
    usage >&2
    exit 2
    ;;
esac

exec "$repo_root/moui/scripts/mobile/build-harmonyos-hap.sh" \
  --workspace-root "$repo_root" \
  --moui-root "$repo_root/moui" \
  --skia-root "$repo_root/moui_skia" \
  --app "$app" \
  --app-config "$app_config" \
  --harmonyos-project "$harmonyos_project" \
  "$@"
