#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/verify-native-capability-contract.sh [options]

Checks native/capabilities.json against native MoonBit implementation files,
fallback twins, ownership metadata, and smoke capability markers. This is the
release gate for adding a Canvas, Path, Text, Shader, Filter, GPU, or other
native capability.

Options:
  --manifest PATH       Native capability manifest. Defaults to native/capabilities.json.
  --native-dir PATH     Native package directory. Defaults to native.
  --pkg PATH            Native moon.pkg path. Defaults to native/moon.pkg.
  --ownership PATH      Native ownership manifest. Defaults to native/ownership.json.
  --status-file PATH    Platform status JSON. Defaults to skia-platform-status.json.
  --smoke-source PATH   Native smoke source file or directory. Defaults to scripts/native_smoke.
  -h, --help            Show this help.
EOF
}

manifest="native/capabilities.json"
native_dir="native"
pkg_path="native/moon.pkg"
ownership="native/ownership.json"
status_file="skia-platform-status.json"
smoke_source="scripts/native_smoke"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest)
      manifest="${2:-}"
      shift 2
      ;;
    --native-dir)
      native_dir="${2:-}"
      shift 2
      ;;
    --pkg)
      pkg_path="${2:-}"
      shift 2
      ;;
    --ownership)
      ownership="${2:-}"
      shift 2
      ;;
    --status-file)
      status_file="${2:-}"
      shift 2
      ;;
    --smoke-source)
      smoke_source="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workspace_root="$(cd "$repo_root/.." && pwd)"
tool_package="tools/moui_skia/verify_native_capability_contract"
tool_dir="$workspace_root/$tool_package"

if [[ ! -d "$tool_dir" && -d "$repo_root/$tool_package" ]]; then
  workspace_root="$repo_root"
  tool_dir="$workspace_root/$tool_package"
fi

if [[ ! -d "$tool_dir" ]]; then
  echo "MoonBit native capability contract tool is missing: $tool_dir" >&2
  exit 1
fi

resolve_repo_path() {
  local path="$1"
  case "$path" in
    /*) printf '%s\n' "$path" ;;
    *) printf '%s\n' "$repo_root/$path" ;;
  esac
}

resolved_manifest="$(resolve_repo_path "$manifest")"
resolved_native_dir="$(resolve_repo_path "$native_dir")"
resolved_pkg_path="$(resolve_repo_path "$pkg_path")"
resolved_ownership="$(resolve_repo_path "$ownership")"
resolved_status_file="$(resolve_repo_path "$status_file")"
resolved_smoke_source="$(resolve_repo_path "$smoke_source")"

bash "$repo_root/scripts/verify-native-fallback-parity.sh" \
  --native-dir "$resolved_native_dir" \
  --pkg "$resolved_pkg_path"
bash "$repo_root/scripts/verify-native-ownership.sh" --manifest "$resolved_ownership"
bash "$repo_root/scripts/verify-native-ffi-borrows.sh" --native-dir "$resolved_native_dir"
bash "$repo_root/scripts/verify-native-smoke-capabilities.sh" \
  --status-file "$resolved_status_file" \
  --smoke-source "$resolved_smoke_source"

cd "$workspace_root"
moon build "$tool_package" --target native
tool_exe="$workspace_root/_build/native/debug/build/wzzc-dev/moui_tools/moui_skia/verify_native_capability_contract/verify_native_capability_contract.exe"
"$tool_exe" \
  --repo-root "$repo_root" \
  --manifest "$resolved_manifest" \
  --native-dir "$resolved_native_dir" \
  --pkg "$resolved_pkg_path" \
  --ownership "$resolved_ownership" \
  --status-file "$resolved_status_file" \
  --smoke-source "$resolved_smoke_source"
