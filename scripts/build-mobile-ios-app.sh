#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/build-mobile-ios-app.sh --app <counter|component_gallery> [options]

Repository example wrapper over moui/scripts/mobile/build-ios-app.sh.
USAGE
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app=""
legacy_uikit_shell=0

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
      "$repo_root/moui/scripts/mobile/build-ios-app.sh" --help
      exit 0
      ;;
    --legacy-uikit-shell)
      legacy_uikit_shell=1
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
  counter)
    xcode_project="$repo_root/examples/counter/ios_app/MoUICounter.xcodeproj"
    scheme="MoUICounter"
    product_name="MoUICounter"
    ;;
  component_gallery)
    xcode_project="$repo_root/examples/component_gallery/ios_app/ComponentGallery.xcodeproj"
    scheme="ComponentGallery"
    product_name="ComponentGallery"
    ;;
  *)
    echo "unknown repository mobile app: $app" >&2
    exit 2
    ;;
esac

project_args=()
if [ "$legacy_uikit_shell" -eq 1 ]; then
  project_args=(
    --xcode-project "$xcode_project"
    --scheme "$scheme"
    --product-name "$product_name"
    --app-config "$repo_root/moui/mobile/legacy/fixtures/$app.mobile.json"
  )
fi

exec "$repo_root/moui/scripts/mobile/build-ios-app.sh" \
  --workspace-root "$repo_root" \
  --moui-root "$repo_root/moui" \
  --skia-root "$repo_root/moui_skia" \
  "${project_args[@]}" \
  "$@"
