#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workspace_root="$(cd "$repo_root/.." && pwd)"
tool_package="tools/moui_skia/verify_native_fallback_parity"
tool_dir="$workspace_root/$tool_package"

if [[ ! -d "$tool_dir" && -d "$repo_root/$tool_package" ]]; then
  workspace_root="$repo_root"
  tool_dir="$workspace_root/$tool_package"
fi

if [[ ! -d "$tool_dir" ]]; then
  echo "MoonBit fallback parity tool is missing: $tool_dir" >&2
  exit 1
fi

cd "$workspace_root"
moon build "$tool_package" --target native
tool_exe="$workspace_root/_build/native/debug/build/wzzc-dev/moui_tools/moui_skia/verify_native_fallback_parity/verify_native_fallback_parity.exe"
"$tool_exe" \
  --repo-root "$repo_root" \
  "$@"
