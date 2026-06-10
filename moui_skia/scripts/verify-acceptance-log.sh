#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workspace_root="$(cd "$repo_root/.." && pwd)"
tool_package="tools/moui_skia/verify_acceptance_log"
tool_dir="$workspace_root/$tool_package"

if [[ ! -d "$tool_dir" && -d "$repo_root/$tool_package" ]]; then
  workspace_root="$repo_root"
  tool_dir="$workspace_root/$tool_package"
fi

if [[ ! -d "$tool_dir" ]]; then
  echo "MoonBit acceptance log tool is missing: $tool_dir" >&2
  exit 1
fi

args=()
if [[ $# -gt 0 ]]; then
  case "$1" in
    -h|--help|--repo-root)
      ;;
    *)
      log_path="$1"
      shift
      case "$log_path" in
        /*) args+=("$log_path") ;;
        *)
          log_dir="$(dirname "$log_path")"
          log_base="$(basename "$log_path")"
          if [[ -d "$log_dir" ]]; then
            args+=("$(cd "$log_dir" && pwd)/$log_base")
          else
            args+=("$(pwd)/$log_path")
          fi
          ;;
      esac
      ;;
  esac
fi
args+=("$@")

cd "$workspace_root"
moon build "$tool_package" --target native
tool_exe="$workspace_root/_build/native/debug/build/wzzc-dev/moui_tools/moui_skia/verify_acceptance_log/verify_acceptance_log.exe"
"$tool_exe" \
  --repo-root "$repo_root" \
  "${args[@]}"
