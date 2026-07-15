#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
config="$repo_root/moui/mobile/legacy/fixtures/component_gallery.mobile.json"

"$repo_root/moui/scripts/mobile/build-harmonyos-hap.sh" \
  --workspace-root "$repo_root" \
  --moui-root "$repo_root/moui" \
  --skia-root "$repo_root/moui_skia" \
  --app component_gallery \
  --app-config "$config" \
  --harmonyos-project "$repo_root/examples/component_gallery/harmonyos_app" \
  --build-dir "$repo_root/artifacts/harmonyos/component-gallery-legacy-fixture" \
  --legacy-shell \
  "$@"
