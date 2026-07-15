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
legacy_shell=0

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
      "$repo_root/moui/scripts/mobile/build-harmonyos-hap.sh" --help
      exit 0
      ;;
    --legacy-shell)
      legacy_shell=1
      index=$((index + 1))
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
  harmonyos_demo|component_gallery)
    harmonyos_project="$repo_root/examples/$app/harmonyos_app"
    ;;
  *)
    echo "unsupported HarmonyOS app: $app" >&2
    usage >&2
    exit 2
    ;;
esac

project_args=()
if [ "$legacy_shell" -eq 1 ]; then
  project_args=(
    --harmonyos-project "$harmonyos_project"
    --app-config "$repo_root/moui/mobile/legacy/fixtures/$app.mobile.json"
  )
fi

exec "$repo_root/moui/scripts/mobile/build-harmonyos-hap.sh" \
  --workspace-root "$repo_root" \
  --moui-root "$repo_root/moui" \
  --skia-root "$repo_root/moui_skia" \
  --app "$app" \
  "${project_args[@]}" \
  "$@"
