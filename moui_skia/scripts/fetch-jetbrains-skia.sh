#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/fetch-jetbrains-skia.sh [options]

Compatibility wrapper for the old JetBrains provider command. The repository's
locked binary provider is now the generic GitHub release provider in
scripts/fetch-release-skia.sh. This wrapper accepts the legacy option names and
forwards them to the release fetcher.

Options:
  --platform auto|macos|linux|windows|android|ios|iosSim|tvos|tvosSim|wasm
  --arch auto|arm64|x64|riscv64
  --config Release|Debug
  --link-mode static|dynamic|auto
  --tag TAG              Accepted for compatibility; ignored unless it matches
                         the locked release tag.
  --cache-dir PATH       Cache root. Default: .skia-cache/release.
  --dry-run-config
  --print-env
  --force
  -h, --help
EOF
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
platform="auto"
arch="auto"
config="Release"
link_mode="${MOUI_SKIA_SKIA_LINK_MODE:-${MOUI_SKIA_MACOS_LINK_MODE:-static}}"
tag=""
cache_dir=".skia-cache/release"
args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      platform="${2:-}"
      shift 2
      ;;
    --arch)
      arch="${2:-}"
      shift 2
      ;;
    --config)
      config="${2:-}"
      shift 2
      ;;
    --link-mode)
      link_mode="${2:-}"
      shift 2
      ;;
    --tag)
      tag="${2:-}"
      shift 2
      ;;
    --cache-dir)
      cache_dir="${2:-}"
      shift 2
      ;;
    --dry-run-config|--print-env|--force)
      args+=("$1")
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

locked_tag="$(
  python3 - "$repo_root/skia-provider-lock.json" <<'PY'
import json
import pathlib
import sys

manifest = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
print(manifest.get("providers", {}).get("release", {}).get("tag", ""))
PY
)"
if [[ -n "$tag" && "$tag" != "$locked_tag" ]]; then
  echo "fetch-jetbrains-skia.sh is a compatibility wrapper; requested legacy tag $tag, using locked release tag $locked_tag" >&2
fi

exec bash "$repo_root/scripts/fetch-release-skia.sh" \
  --platform "$platform" \
  --arch "$arch" \
  --config "$config" \
  --link-mode "$link_mode" \
  --tag "$locked_tag" \
  --cache-dir "$cache_dir" \
  "${args[@]}"
