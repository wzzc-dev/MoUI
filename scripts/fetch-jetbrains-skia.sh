#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/fetch-jetbrains-skia.sh [options]

Options:
  --platform auto|macos|linux|windows|android|ios|iosSim|tvos|tvosSim|wasm
                         Target JetBrains Skia package platform. Default: auto.
  --arch auto|arm64|x64  Target package architecture. Default: auto.
                         wasm uses the manifest wasm asset when --arch auto.
  --config Release|Debug Target package configuration. Default: Release.
  --tag TAG              JetBrains/skia release tag. Default: m148-8967a2e80c.
  --cache-dir PATH       Cache root. Default: .skia-cache/jetbrains.
  --dry-run-config       Print selected asset and resolved paths without
                         downloading or extracting archives.
  --print-env            Print only KEY=value lines suitable for wrappers.
  --force                Re-download and re-extract archives.
  -h, --help             Show this help.

The cache layout is:
  .skia-cache/jetbrains/<tag>/<platform>-<config>-<arch>/

Output keys include SKIA_MBT_SKIA_INCLUDE, SKIA_MBT_SKIA_LIB_DIR,
SKIA_MBT_SKIA_LIB, SKIA_MBT_EXTRA_CC_FLAGS, SKIA_MBT_EXTRA_LINK_FLAGS, and
JetBrains provider metadata used by the real-smoke logs.
EOF
}

platform="auto"
arch="auto"
config="Release"
tag="m148-8967a2e80c"
cache_dir=".skia-cache/jetbrains"
dry_run_config=0
print_env=0
force=0

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
    --tag)
      tag="${2:-}"
      shift 2
      ;;
    --cache-dir)
      cache_dir="${2:-}"
      shift 2
      ;;
    --dry-run-config)
      dry_run_config=1
      shift
      ;;
    --print-env)
      print_env=1
      shift
      ;;
    --force)
      force=1
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
  auto|macos|linux|windows|android|ios|iosSim|tvos|tvosSim|wasm) ;;
  *) echo "unsupported platform: $platform" >&2; exit 2 ;;
esac
case "$arch" in
  auto|arm64|x64) ;;
  *) echo "unsupported arch: $arch" >&2; exit 2 ;;
esac
case "$config" in
  Release|Debug) ;;
  *) echo "unsupported config: $config" >&2; exit 2 ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest_path="$repo_root/skia-provider-lock.json"
case "$cache_dir" in
  /*) resolved_cache_dir="$cache_dir" ;;
  *) resolved_cache_dir="$repo_root/$cache_dir" ;;
esac

detect_platform() {
  case "$(uname -s)" in
    Darwin) printf '%s\n' macos ;;
    Linux) printf '%s\n' linux ;;
    MINGW*|MSYS*|CYGWIN*) printf '%s\n' windows ;;
    *) echo "cannot auto-detect JetBrains Skia platform from uname: $(uname -s)" >&2; return 1 ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    arm64|aarch64) printf '%s\n' arm64 ;;
    x86_64|amd64) printf '%s\n' x64 ;;
    *) echo "cannot auto-detect JetBrains Skia arch from uname: $(uname -m)" >&2; return 1 ;;
  esac
}

resolved_platform="$platform"
if [[ "$resolved_platform" == "auto" ]]; then
  resolved_platform="$(detect_platform)"
fi

resolved_arch="$arch"
if [[ "$resolved_platform" == "wasm" ]]; then
  if [[ "$resolved_arch" != "auto" ]]; then
    echo "--platform wasm only supports --arch auto with the wasm manifest asset" >&2
    exit 2
  fi
  resolved_arch="wasm"
elif [[ "$resolved_arch" == "auto" ]]; then
  resolved_arch="$(detect_arch)"
fi

if [[ ! -f "$manifest_path" ]]; then
  echo "JetBrains Skia provider manifest is missing: $manifest_path" >&2
  exit 1
fi

manifest_values="$(python3 - "$manifest_path" "$tag" "$resolved_platform" "$config" "$resolved_arch" <<'PY'
import json
import pathlib
import sys

manifest_path = pathlib.Path(sys.argv[1])
tag = sys.argv[2]
platform = sys.argv[3]
config = sys.argv[4]
arch = sys.argv[5]

manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
provider = manifest.get("providers", {}).get("jetbrains")
if not isinstance(provider, dict):
    raise SystemExit("skia-provider-lock.json is missing providers.jetbrains")
if provider.get("tag") != tag:
    raise SystemExit(
        f"manifest only locks JetBrains tag {provider.get('tag')}, requested {tag}"
    )
asset = (
    provider.get("assets", {})
    .get(platform, {})
    .get(config, {})
    .get(arch)
)
if not isinstance(asset, dict):
    raise SystemExit(
        f"manifest has no JetBrains asset for platform={platform} config={config} arch={arch}"
    )
name = asset["name"]
url = asset.get(
    "url",
    f"https://github.com/JetBrains/skia/releases/download/{tag}/{name}",
)
source = provider.get("source_archive", {})
items = {
    "commit": provider["commit"],
    "asset_name": name,
    "asset_sha256": asset["sha256"],
    "asset_size": str(asset.get("size", "")),
    "asset_url": url,
    "source_name": source.get("name", f"JetBrains-skia-{tag}-source.zip"),
    "source_url": source.get(
        "url", f"https://github.com/JetBrains/skia/archive/refs/tags/{tag}.zip"
    ),
    "extra_cc_flags": provider.get("default_extra_cc_flags", {}).get(platform, ""),
    "extra_link_flags": provider.get("default_extra_link_flags", {}).get(platform, ""),
}
for key, value in items.items():
    print(f"{key}={value}")
PY
)"

get_manifest_value() {
  local key="$1"
  printf '%s\n' "$manifest_values" | sed -n "s/^${key}=//p" | tail -n 1
}

commit="$(get_manifest_value commit)"
asset_name="$(get_manifest_value asset_name)"
asset_sha256="$(get_manifest_value asset_sha256)"
asset_size="$(get_manifest_value asset_size)"
asset_url="$(get_manifest_value asset_url)"
source_name="$(get_manifest_value source_name)"
source_url="$(get_manifest_value source_url)"
extra_cc_flags="$(get_manifest_value extra_cc_flags)"
extra_link_flags="$(get_manifest_value extra_link_flags)"

tag_dir="$resolved_cache_dir/$tag"
entry_dir="$tag_dir/$resolved_platform-$config-$resolved_arch"
package_zip="$entry_dir/$asset_name"
package_dir="$entry_dir/package"
source_dir="$tag_dir/source"
source_zip="$tag_dir/$source_name"

find_header_root() {
  local root="$1"
  if [[ ! -d "$root" ]]; then
    return 1
  fi
  local header
  header="$(find "$root" -path '*/include/core/SkSurface.h' -type f -print 2>/dev/null | head -n 1 || true)"
  if [[ -z "$header" ]]; then
    return 1
  fi
  printf '%s\n' "${header%/include/core/SkSurface.h}"
}

find_lib_dir() {
  local root="$1"
  if [[ ! -d "$root" ]]; then
    return 1
  fi
  local names=()
  case "$resolved_platform" in
    macos) names=("libskia.dylib" "libskia.a") ;;
    linux) names=("libskia.so" "libskia.a") ;;
    windows) names=("skia.lib") ;;
    ios|iosSim|tvos|tvosSim) names=("libskia.a" "libskia.dylib") ;;
    android) names=("libskia.so" "libskia.a") ;;
    wasm) names=("libskia.a") ;;
    *) names=("libskia.a" "libskia.so" "libskia.dylib" "skia.lib") ;;
  esac
  local name lib
  for name in "${names[@]}"; do
    lib="$(find "$root" -name "$name" -type f -print 2>/dev/null | head -n 1 || true)"
    if [[ -n "$lib" ]]; then
      dirname "$lib"
      return 0
    fi
  done
  return 1
}

compute_sha256() {
  local path="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{print $1}'
  else
    shasum -a 256 "$path" | awk '{print $1}'
  fi
}

download_file() {
  local url="$1"
  local output="$2"
  if ! command -v curl >/dev/null 2>&1; then
    echo "missing required command: curl" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$output")"
  curl -fL --retry 3 --retry-delay 2 -o "$output" "$url"
}

extract_zip() {
  local archive="$1"
  local dest="$2"
  if ! command -v unzip >/dev/null 2>&1; then
    echo "missing required command: unzip" >&2
    exit 1
  fi
  mkdir -p "$dest"
  unzip -q -o "$archive" -d "$dest"
}

ensure_package_extracted() {
  if [[ $dry_run_config -eq 1 ]]; then
    return 0
  fi
  if [[ $force -eq 1 || ! -d "$package_dir" ]]; then
    mkdir -p "$entry_dir"
    if [[ $force -eq 1 || ! -f "$package_zip" ]]; then
      echo "Downloading JetBrains Skia asset: $asset_name" >&2
      download_file "$asset_url" "$package_zip"
    fi
    if [[ "${SKIA_MBT_ALLOW_FAKE_JETBRAINS_ZIP:-0}" != "1" ]]; then
      actual_sha256="$(compute_sha256 "$package_zip" | tr '[:upper:]' '[:lower:]')"
      if [[ "$actual_sha256" != "$asset_sha256" ]]; then
        echo "JetBrains Skia asset SHA256 mismatch: $package_zip" >&2
        echo "  expected=$asset_sha256" >&2
        echo "  actual=$actual_sha256" >&2
        exit 1
      fi
    fi
    extract_zip "$package_zip" "$package_dir"
  fi
}

ensure_source_extracted() {
  if [[ $dry_run_config -eq 1 ]]; then
    return 0
  fi
  if [[ $force -eq 1 || ! -d "$source_dir" ]]; then
    mkdir -p "$tag_dir"
    if [[ $force -eq 1 || ! -f "$source_zip" ]]; then
      echo "Downloading JetBrains Skia source archive for headers: $tag" >&2
      download_file "$source_url" "$source_zip"
    fi
    extract_zip "$source_zip" "$source_dir"
  fi
}

ensure_package_extracted

skia_include=""
include_source="package"
if skia_include="$(find_header_root "$package_dir")"; then
  include_source="package"
else
  include_source="source"
  ensure_source_extracted
  if ! skia_include="$(find_header_root "$source_dir")"; then
    if [[ $dry_run_config -eq 1 ]]; then
      skia_include="$source_dir"
    else
      echo "Skia headers were not found in package or source archive for tag $tag" >&2
      exit 1
    fi
  fi
fi

if skia_lib_dir="$(find_lib_dir "$package_dir")"; then
  :
else
  if [[ $dry_run_config -eq 1 ]]; then
    skia_lib_dir="$package_dir"
  else
    echo "Skia library for platform=$resolved_platform was not found in $package_dir" >&2
    exit 1
  fi
fi

skia_root="$skia_include"
lib_dir_normalized="${skia_lib_dir%/}"
suffix="/out/$config-$resolved_arch"
lib_dir_lower="$(printf '%s' "$lib_dir_normalized" | tr '[:upper:]' '[:lower:]')"
suffix_lower="$(printf '%s' "$suffix" | tr '[:upper:]' '[:lower:]')"
if [[ "$lib_dir_lower" == *"$suffix_lower" ]]; then
  skia_root="${lib_dir_normalized:0:${#lib_dir_normalized}-${#suffix}}"
fi

if [[ $print_env -eq 1 ]]; then
  cat <<EOF
SKIA_MBT_PROVIDER=jetbrains
SKIA_MBT_SKIA_PROVIDER=jetbrains
SKIA_MBT_SKIA_ROOT=$skia_root
SKIA_MBT_JETBRAINS_TAG=$tag
SKIA_MBT_SKIA_COMMIT=$commit
SKIA_MBT_SKIA_PACKAGE=$asset_name
SKIA_MBT_SKIA_PACKAGE_SHA256=$asset_sha256
SKIA_MBT_SKIA_INCLUDE=$skia_include
SKIA_MBT_SKIA_LIB_DIR=$skia_lib_dir
SKIA_MBT_SKIA_LIB=skia
SKIA_MBT_EXTRA_CC_FLAGS=$extra_cc_flags
SKIA_MBT_EXTRA_LINK_FLAGS=$extra_link_flags
EOF
  exit 0
fi

cat <<EOF
JetBrains Skia provider:
  skia_provider=jetbrains
  jetbrains_tag=$tag
  skia_commit=$commit
  skia_package=$asset_name
  skia_package_sha256=$asset_sha256
  skia_package_size=$asset_size
  skia_package_url=$asset_url
  platform=$resolved_platform
  config=$config
  arch=$resolved_arch
  cache_dir=$entry_dir
  include_source=$include_source
  skia_root=$skia_root
  skia_include=$skia_include
  skia_lib_dir=$skia_lib_dir
  skia_lib=skia
  extra_cc_flags=$extra_cc_flags
  extra_link_flags=$extra_link_flags
EOF
if [[ $dry_run_config -eq 1 ]]; then
  echo "Dry run complete; JetBrains Skia was not downloaded or extracted."
fi
