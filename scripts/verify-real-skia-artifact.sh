#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/verify-real-skia-artifact.sh --platform NAME --log-dir PATH [options]

Checks a real Skia smoke artifact/log directory as a bundle. The directory must
contain the wrapper log, native smoke executable log, and acceptance summary for
the selected platform.

Options:
  --platform NAME    linux, macos, or windows.
  --log-dir PATH     Directory containing platform real-smoke logs.
  --require-commit   Require skia_commit=<40 hex chars> in wrapper and acceptance logs.
  -h, --help         Show this help.
EOF
}

platform=""
log_dir=""
require_commit=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      platform="${2:-}"
      shift 2
      ;;
    --log-dir)
      log_dir="${2:-}"
      shift 2
      ;;
    --require-commit)
      require_commit=1
      shift
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

case "$platform" in
  linux|macos|windows) ;;
  "")
    echo "--platform is required" >&2
    usage >&2
    exit 2
    ;;
  *)
    echo "unsupported platform: $platform" >&2
    usage >&2
    exit 2
    ;;
esac

if [[ -z "$log_dir" ]]; then
  echo "--log-dir is required" >&2
  usage >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "$log_dir" in
  /*) resolved_log_dir="$log_dir" ;;
  *) resolved_log_dir="$repo_root/$log_dir" ;;
esac

if [[ ! -d "$resolved_log_dir" ]]; then
  echo "real Skia artifact log directory is missing: $resolved_log_dir" >&2
  exit 1
fi

wrapper_log="$resolved_log_dir/$platform-real-skia-smoke.log"
preflight_log="$resolved_log_dir/$platform-real-skia-smoke-preflight.log"
native_log="$resolved_log_dir/$platform-native-smoke-output.log"
acceptance_log="$resolved_log_dir/$platform-real-skia-acceptance.log"
build_log="$resolved_log_dir/$platform-skia-build.log"

for log_path in "$wrapper_log" "$native_log" "$acceptance_log"; do
  if [[ ! -f "$log_path" ]]; then
    echo "real Skia artifact is missing expected log: $log_path" >&2
    exit 1
  fi
done

if [[ "$platform" == "macos" || "$platform" == "windows" ]]; then
  if [[ ! -f "$preflight_log" ]]; then
    echo "real Skia artifact is missing expected preflight log: $preflight_log" >&2
    exit 1
  fi
fi

if [[ "$platform" == "linux" && $require_commit -eq 1 ]]; then
  if [[ ! -f "$build_log" ]]; then
    echo "source-built Linux artifact is missing expected build log: $build_log" >&2
    exit 1
  fi
  if ! grep -Fq "build_log=" "$wrapper_log"; then
    echo "wrapper log is missing required field: build_log=" >&2
    exit 1
  fi
fi

bash "$repo_root/scripts/verify-native-smoke-log.sh" "$native_log"
acceptance_args=("$acceptance_log")
if [[ $require_commit -eq 1 ]]; then
  acceptance_args+=(--require-commit)
fi
bash "$repo_root/scripts/verify-acceptance-log.sh" "${acceptance_args[@]}"

for field in skia_include= skia_lib_dir= skia_lib= stub_cc_flags= cc_link_flags=; do
  if ! grep -Fq "$field" "$wrapper_log"; then
    echo "wrapper log is missing required field: $field" >&2
    exit 1
  fi
done

if ! grep -Eq 'library=.*\b(lib)?skia\.(a|so|dylib|lib)\b' "$wrapper_log"; then
  echo "wrapper log does not record a Skia library file" >&2
  exit 1
fi

artifact_log_names=(
  "$(basename "$wrapper_log")"
  "$(basename "$native_log")"
  "$(basename "$acceptance_log")"
)
if [[ "$platform" == "macos" || "$platform" == "windows" ]]; then
  artifact_log_names+=("$(basename "$preflight_log")")
fi

for log_name in "${artifact_log_names[@]}"; do
  if ! grep -Fq "$log_name" "$acceptance_log"; then
    echo "acceptance log does not reference expected artifact log: $log_name" >&2
    exit 1
  fi
done

if [[ "$platform" == "linux" && $require_commit -eq 1 ]]; then
  if ! grep -Fq "$(basename "$build_log")" "$acceptance_log"; then
    echo "acceptance log does not reference expected source build log: $(basename "$build_log")" >&2
    exit 1
  fi
fi

if [[ $require_commit -eq 1 ]] && ! grep -Eq 'skia_commit=[0-9a-fA-F]{40}[[:space:]]*$' "$wrapper_log"; then
  echo "wrapper log is missing a full 40-character skia_commit hash" >&2
  exit 1
fi

extract_commit() {
  local log_path="$1"
  grep -E '^[[:space:]]*skia_commit=[0-9a-fA-F]{40}[[:space:]]*$' "$log_path" \
    | tail -n 1 \
    | sed -E 's/^[[:space:]]*skia_commit=([0-9a-fA-F]{40})[[:space:]]*$/\1/' \
    | tr '[:upper:]' '[:lower:]'
}

if [[ $require_commit -eq 1 ]]; then
  wrapper_commit="$(extract_commit "$wrapper_log")"
  acceptance_commit="$(extract_commit "$acceptance_log")"
  if [[ "$wrapper_commit" != "$acceptance_commit" ]]; then
    echo "wrapper and acceptance logs disagree on skia_commit" >&2
    echo "  wrapper_commit=$wrapper_commit" >&2
    echo "  acceptance_commit=$acceptance_commit" >&2
    exit 1
  fi
fi

if [[ "$platform" == "linux" && $require_commit -eq 1 ]]; then
  for field in 'Linux Skia source build environment:' 'skia_checkout=' 'skia_commit=' 'gn_args='; do
    if ! grep -Fq "$field" "$build_log"; then
      echo "Linux source build log is missing required field: $field" >&2
      exit 1
    fi
  done
  build_commit="$(extract_commit "$build_log")"
  if [[ "$wrapper_commit" != "$build_commit" ]]; then
    echo "Linux build and wrapper logs disagree on skia_commit" >&2
    echo "  build_commit=$build_commit" >&2
    echo "  wrapper_commit=$wrapper_commit" >&2
    exit 1
  fi
fi

echo "Verified $platform real Skia artifact logs in $resolved_log_dir."
