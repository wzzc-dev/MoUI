#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
config="$repo_root/examples/component_gallery/.mobile-harmonyos-plugin-fixture-$$.json"
cleanup() {
  rm -f "$config"
}
trap cleanup EXIT

node - "$repo_root/examples/component_gallery/mobile.json" "$config" <<'NODE'
const fs = require("fs");
const source = process.argv[2];
const output = process.argv[3];
const config = JSON.parse(fs.readFileSync(source, "utf8"));
config.mobile.plugins = ["moui/mobile/harmonyos/tests/fixtures/plugin/moui.plugin.json"];
fs.writeFileSync(output, `${JSON.stringify(config, null, 2)}\n`);
NODE

"$repo_root/moui/scripts/mobile/build-harmonyos-hap.sh" \
  --workspace-root "$repo_root" \
  --moui-root "$repo_root/moui" \
  --skia-root "$repo_root/moui_skia" \
  --app component_gallery \
  --app-config "$config" \
  --build-dir "$repo_root/artifacts/harmonyos/component-gallery-plugin-fixture" \
  "$@"
