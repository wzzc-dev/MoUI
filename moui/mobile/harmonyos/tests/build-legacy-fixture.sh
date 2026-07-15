#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
artifact_root="${MOUI_MOBILE_SHELL_CI_ROOT:-$repo_root/artifacts/mobile-shell-ci}"
config="$repo_root/moui/mobile/legacy/fixtures/component_gallery.mobile.json"

"$repo_root/moui/scripts/mobile/build-harmonyos-hap.sh" \
  --workspace-root "$repo_root" \
  --moui-root "$repo_root/moui" \
  --skia-root "$repo_root/moui_skia" \
  --app component_gallery \
  --app-config "$config" \
  --harmonyos-project "$repo_root/examples/component_gallery/harmonyos_app" \
  --build-dir "$artifact_root/harmonyos/legacy" \
  --output "$artifact_root/harmonyos/legacy/ComponentGallery.hap" \
  --legacy-shell \
  "$@"
