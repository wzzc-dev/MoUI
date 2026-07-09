#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

exec "$repo_root/moui/scripts/mobile/build-harmonyos-hap.sh" \
  --workspace-root "$repo_root" \
  --moui-root "$repo_root/moui" \
  --skia-root "$repo_root/moui_skia" \
  --app harmonyos_demo \
  --app-config "$repo_root/examples/harmonyos_demo/mobile.json" \
  --harmonyos-project "$repo_root/examples/harmonyos_demo/harmonyos_app" \
  "$@"
