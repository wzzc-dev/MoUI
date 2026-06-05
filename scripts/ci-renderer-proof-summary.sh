#!/usr/bin/env sh
set -eu

ROOT="${1:-artifacts}"

required='
webgpu-wasm-web.json
wgpu-native-macos.json
wgpu-native-windows.json
wgpu-native-linux.json
skia-native-macos.json
skia-native-windows.json
skia-native-linux.json
'

for name in $required; do
  path="$(find "$ROOT" -name "$name" -type f | head -n 1 || true)"
  if [ -z "$path" ]; then
    printf 'Missing renderer proof manifest: %s\n' "$name" >&2
    exit 1
  fi
  node - "$path" <<'NODE'
const { readFileSync } = require("node:fs");
const path = process.argv[2];
const manifest = JSON.parse(readFileSync(path, "utf8"));
const failed = Object.entries(manifest.observations || {})
  .filter(([, observation]) => observation?.status !== "passed")
  .map(([key]) => key);
console.log(
  `renderer proof summary manifest=${path} backend=${manifest.backend} platform=${manifest.platform} status=${manifest.status} failed=${failed.length > 0 ? failed.join(",") : "(none)"}`,
);
NODE
  node scripts/validate-renderer-proof-manifest.mjs "$path" --require-passed --artifact-root "$ROOT"
done

printf 'renderer proof summary: all required renderer proof manifests passed\n'
