#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workspace_root="$(cd "$repo_root/.." && pwd)"
tool_package="tools/moui_skia/verify_native_smoke_capabilities"
tool_dir="$workspace_root/$tool_package"

if [[ ! -d "$tool_dir" && -d "$repo_root/$tool_package" ]]; then
  workspace_root="$repo_root"
  tool_dir="$workspace_root/$tool_package"
fi

if [[ ! -d "$tool_dir" ]]; then
  echo "MoonBit native smoke capability tool is missing: $tool_dir" >&2
  exit 1
fi

cd "$workspace_root"
moon build "$tool_package" --target native
tool_exe="$workspace_root/_build/native/debug/build/wzzc-dev/moui_tools/moui_skia/verify_native_smoke_capabilities/verify_native_smoke_capabilities.exe"
log_verifier_source="$workspace_root/tools/moui_skia/native_smoke_log_contract"
"$tool_exe" \
  --repo-root "$repo_root" \
  --log-verifier-source "$log_verifier_source" \
  "$@"
