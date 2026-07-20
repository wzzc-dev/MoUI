#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/build-shell-harmonyos-hap.sh --app <harmonyos_demo|showcase> [options]

Repository example wrapper over `moui build harmonyos`.
USAGE
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app=""

args=("$@")
index=0
forwarded=()
while [ "$index" -lt "${#args[@]}" ]; do
  case "${args[$index]}" in
    --app)
      app="${args[$((index + 1))]:-}"
      index=$((index + 2))
      ;;
    -h|--help)
      usage
      moon run moui_cli/cmd/moui --target native -- build harmonyos --help
      exit 0
      ;;
    *)
      forwarded+=("${args[$index]}")
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
  harmonyos_demo|showcase) ;;
  *)
    echo "unsupported HarmonyOS app: $app" >&2
    usage >&2
    exit 2
    ;;
esac

cd "$repo_root"
exec moon run moui_cli/cmd/moui --target native -- build harmonyos "$app" \
  --workspace-root "$repo_root" \
  --moui-root "$repo_root/moui" \
  --skia-root "$repo_root/moui_skia" \
  "${forwarded[@]+"${forwarded[@]}"}"
