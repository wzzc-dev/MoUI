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
  node scripts/validate-renderer-proof-manifest.mjs "$path" --require-passed --artifact-root "$ROOT"
done

printf 'renderer proof summary: all required renderer proof manifests passed\n'
