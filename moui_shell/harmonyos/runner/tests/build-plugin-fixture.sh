#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
config="$repo_root/examples/showcase/.shell-harmonyos-plugin-fixture-$$.json"
cleanup() {
  rm -f "$config"
}
trap cleanup EXIT

node - "$repo_root/examples/showcase/shell.json" "$config" <<'NODE'
const fs = require("fs");
const source = process.argv[2];
const output = process.argv[3];
const config = JSON.parse(fs.readFileSync(source, "utf8"));
config.shell.plugins = ["moui_shell/test_probe/moui.plugin.json"];
fs.writeFileSync(output, `${JSON.stringify(config, null, 2)}\n`);
NODE

moon run moui_cli/cmd/moui --target native -- build harmonyos showcase \
  --workspace-root "$repo_root" \
  --moui-root "$repo_root/moui" \
  --skia-root "$repo_root/moui_skia" \
  --app-config "$config" \
  --build-dir "$repo_root/artifacts/harmonyos/showcase-plugin-fixture" \
  "$@"
