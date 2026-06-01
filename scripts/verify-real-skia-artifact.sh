#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/verify-real-skia-artifact.sh --platform NAME --log-dir PATH [options]

Checks a real Skia smoke artifact/log directory as a bundle. The directory must
contain the preflight log, wrapper log, native smoke executable log, and
acceptance summary for the selected platform.

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

for log_path in "$preflight_log" "$wrapper_log" "$native_log" "$acceptance_log"; do
  if [[ ! -f "$log_path" ]]; then
    echo "real Skia artifact is missing expected log: $log_path" >&2
    exit 1
  fi
done

extract_field() {
  local log_path="$1"
  local field="$2"
  grep -E "^[[:space:]]*${field}=" "$log_path" \
    | tail -n 1 \
    | sed -E "s/^[[:space:]]*${field}=//" \
    | sed -E 's/[[:space:]]*$//' \
    || true
}

require_log_field() {
  local log_path="$1"
  local field="$2"
  local message_prefix="$3"
  if ! grep -Eq "^[[:space:]]*${field}" "$log_path"; then
    echo "$message_prefix: $field" >&2
    exit 1
  fi
}

require_exact_log_line() {
  local log_path="$1"
  local expected="$2"
  local message_prefix="$3"
  if ! grep -Eq "^[[:space:]]*${expected}[[:space:]]*$" "$log_path"; then
    echo "$message_prefix: $expected" >&2
    exit 1
  fi
}

wrapper_provider="$(extract_field "$wrapper_log" skia_provider || true)"
acceptance_provider="$(extract_field "$acceptance_log" skia_provider || true)"
if [[ -z "$wrapper_provider" || "$wrapper_provider" == "unknown" ]]; then
  wrapper_provider="source"
fi
if [[ -z "$acceptance_provider" || "$acceptance_provider" == "unknown" ]]; then
  acceptance_provider="$wrapper_provider"
fi
if [[ "$wrapper_provider" != "$acceptance_provider" ]]; then
  echo "wrapper and acceptance logs disagree on skia_provider" >&2
  echo "  wrapper_provider=$wrapper_provider" >&2
  echo "  acceptance_provider=$acceptance_provider" >&2
  exit 1
fi

if [[ "$platform" == "linux" && $require_commit -eq 1 && "$wrapper_provider" == "source" ]]; then
  if [[ ! -f "$build_log" ]]; then
    echo "source-built Linux artifact is missing expected build log: $build_log" >&2
    exit 1
  fi
  require_log_field "$wrapper_log" "build_log=" "wrapper log is missing required field"
fi

bash "$repo_root/scripts/verify-native-smoke-log.sh" "$native_log"
acceptance_args=("$acceptance_log")
if [[ $require_commit -eq 1 ]]; then
  acceptance_args+=(--require-commit)
fi
bash "$repo_root/scripts/verify-acceptance-log.sh" "${acceptance_args[@]}"

for field in skia_include= skia_lib_dir= skia_lib= stub_cc_flags= cc_link_flags=; do
  require_log_field "$wrapper_log" "$field" "wrapper log is missing required field"
done

if ! grep -Eq 'library=.*\b(lib)?skia\.(a|so|dylib|lib)\b' "$wrapper_log"; then
  echo "wrapper log does not record a Skia library file" >&2
  exit 1
fi

artifact_log_names=(
  "$(basename "$preflight_log")"
  "$(basename "$wrapper_log")"
  "$(basename "$native_log")"
  "$(basename "$acceptance_log")"
)

for log_name in "${artifact_log_names[@]}"; do
  if ! grep -Fq "$log_name" "$acceptance_log"; then
    echo "acceptance log does not reference expected artifact log: $log_name" >&2
    exit 1
  fi
done

if [[ "$platform" == "linux" && $require_commit -eq 1 && "$wrapper_provider" == "source" ]]; then
  if ! grep -Fq "$(basename "$build_log")" "$acceptance_log"; then
    echo "acceptance log does not reference expected source build log: $(basename "$build_log")" >&2
    exit 1
  fi
fi

if [[ $require_commit -eq 1 ]] && ! grep -Eq 'skia_commit=[0-9a-fA-F]{40}[[:space:]]*$' "$wrapper_log"; then
  echo "wrapper log is missing a full 40-character skia_commit hash" >&2
  exit 1
fi

if [[ "$wrapper_provider" == "jetbrains" ]]; then
  for field in skia_provider= jetbrains_tag= skia_commit= skia_package= skia_package_sha256=; do
    require_log_field "$wrapper_log" "$field" "JetBrains wrapper log is missing required field"
  done
  if ! grep -Eq '^[[:space:]]*skia_commit=[0-9a-fA-F]{40}[[:space:]]*$' "$wrapper_log"; then
    echo "JetBrains wrapper log is missing a full 40-character skia_commit hash" >&2
    exit 1
  fi
  if ! grep -Eq '^[[:space:]]*skia_package_sha256=[0-9a-fA-F]{64}[[:space:]]*$' "$wrapper_log"; then
    echo "JetBrains wrapper log is missing a full 64-character skia_package_sha256 hash" >&2
    exit 1
  fi

  python3 - \
    "$repo_root/skia-provider-lock.json" \
    "$platform" \
    "$(extract_field "$wrapper_log" jetbrains_tag)" \
    "$(extract_field "$wrapper_log" skia_commit)" \
    "$(extract_field "$wrapper_log" skia_package)" \
    "$(extract_field "$wrapper_log" skia_package_sha256)" <<'PY'
import json
import pathlib
import sys

manifest_path = pathlib.Path(sys.argv[1])
platform = sys.argv[2]
tag = sys.argv[3]
commit = sys.argv[4].lower()
package = sys.argv[5]
sha256 = sys.argv[6].lower()

def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)

try:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
except FileNotFoundError:
    fail(f"JetBrains provider manifest is missing: {manifest_path}")
except json.JSONDecodeError as error:
    fail(f"JetBrains provider manifest is invalid: {error}")

provider = manifest.get("providers", {}).get("jetbrains")
if not isinstance(provider, dict):
    fail("JetBrains provider manifest is missing providers.jetbrains")
if tag != provider.get("tag"):
    fail(f"JetBrains tag mismatch: log={tag} manifest={provider.get('tag')}")
if commit != str(provider.get("commit", "")).lower():
    fail(f"JetBrains commit mismatch: log={commit} manifest={provider.get('commit')}")

assets = provider.get("assets", {}).get(platform, {})
matches = []
for by_arch in assets.values():
    if isinstance(by_arch, dict):
        for asset in by_arch.values():
            if isinstance(asset, dict) and asset.get("name") == package:
                matches.append(asset)
if not matches:
    fail(f"JetBrains package is not locked for platform={platform}: {package}")
if not any(str(asset.get("sha256", "")).lower() == sha256 for asset in matches):
    fail(f"JetBrains package SHA256 mismatch for {package}: {sha256}")
PY

  for field in jetbrains_tag skia_commit skia_package skia_package_sha256; do
    wrapper_value="$(extract_field "$wrapper_log" "$field" | tr '[:upper:]' '[:lower:]' || true)"
    acceptance_value="$(extract_field "$acceptance_log" "$field" | tr '[:upper:]' '[:lower:]' || true)"
    if [[ "$wrapper_value" != "$acceptance_value" ]]; then
      echo "wrapper and acceptance logs disagree on JetBrains $field" >&2
      echo "  wrapper_$field=$wrapper_value" >&2
      echo "  acceptance_$field=$acceptance_value" >&2
      exit 1
    fi
  done
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

if [[ "$platform" == "linux" && $require_commit -eq 1 && "$wrapper_provider" == "source" ]]; then
  require_exact_log_line \
    "$build_log" \
    "Linux Skia source build environment:" \
    "Linux source build log is missing required field"
  for field in skia_checkout= skia_commit= gn_args=; do
    require_log_field "$build_log" "$field" "Linux source build log is missing required field"
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
