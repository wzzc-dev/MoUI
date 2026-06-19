#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/fetch-release-skia.sh [options]

Options:
  --platform auto|macos|linux|windows|android|ios|iosSim|tvos|tvosSim|wasm
                         Target release package platform. Default: auto.
  --arch auto|arm64|x64|riscv64
                         Target package architecture. Default: auto.
                         wasm uses the manifest wasm asset when --arch auto.
  --config Release|Debug Target package configuration. Default: Release.
  --link-mode static|dynamic|auto
                         Release asset link mode. Default: static.
  --tag TAG              GitHub release tag. Default from skia-provider-lock.json.
  --cache-dir PATH       Cache root. Default: .skia-cache/release.
  --dry-run-config       Print selected asset and resolved paths without
                         downloading or extracting archives.
  --print-env            Print only KEY=value lines suitable for wrappers.
  --force                Re-download and re-extract archives.
  -h, --help             Show this help.

The cache layout is:
  .skia-cache/release/<tag>/<platform>-<config>-<arch>-<link-mode>/

Output keys include MOUI_SKIA_SKIA_INCLUDE, MOUI_SKIA_SKIA_LIB_DIR,
MOUI_SKIA_SKIA_LIB, MOUI_SKIA_SKIA_PROVIDER, MOUI_SKIA_LINK_MODE,
MOUI_SKIA_EXTRA_CC_FLAGS, MOUI_SKIA_EXTRA_LINK_FLAGS, and release metadata used
by real-smoke logs.
EOF
}

reject_legacy_link_mode_env() {
  if [[ -n "${MOUI_SKIA_SKIA_LINK_MODE+x}" || -n "${MOUI_SKIA_MACOS_LINK_MODE+x}" ]]; then
    echo "MOUI_SKIA_SKIA_LINK_MODE and MOUI_SKIA_MACOS_LINK_MODE are no longer supported; use MOUI_SKIA_LINK_MODE=dynamic|static|auto." >&2
    exit 2
  fi
}

reject_legacy_link_mode_env

platform="auto"
arch="auto"
config="Release"
link_mode="${MOUI_SKIA_LINK_MODE:-static}"
tag=""
cache_dir=".skia-cache/release"
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
  auto|arm64|x64|riscv64) ;;
  *) echo "unsupported arch: $arch" >&2; exit 2 ;;
esac
case "$config" in
  Release|Debug) ;;
  *) echo "unsupported config: $config" >&2; exit 2 ;;
esac
case "$link_mode" in
  static|dynamic|auto) ;;
  *) echo "unsupported --link-mode: $link_mode" >&2; exit 2 ;;
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
    *) echo "cannot auto-detect Skia release platform from uname: $(uname -s)" >&2; return 1 ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    arm64|aarch64) printf '%s\n' arm64 ;;
    x86_64|amd64) printf '%s\n' x64 ;;
    riscv64) printf '%s\n' riscv64 ;;
    *) echo "cannot auto-detect Skia release arch from uname: $(uname -m)" >&2; return 1 ;;
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
  echo "Skia release provider manifest is missing: $manifest_path" >&2
  exit 1
fi

manifest_values="$(python3 - "$manifest_path" "$tag" "$resolved_platform" "$config" "$resolved_arch" "$link_mode" <<'PY'
import json
import pathlib
import sys

manifest_path = pathlib.Path(sys.argv[1])
requested_tag = sys.argv[2]
platform = sys.argv[3]
config = sys.argv[4]
arch = sys.argv[5]
requested_mode = sys.argv[6]

manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
provider = manifest.get("providers", {}).get("release")
if not isinstance(provider, dict):
    raise SystemExit("skia-provider-lock.json is missing providers.release")

tag = requested_tag or provider.get("tag", "")
if tag != provider.get("tag"):
    raise SystemExit(f"manifest only locks release tag {provider.get('tag')}, requested {tag}")

entry = (
    provider.get("assets", {})
    .get(platform, {})
    .get(config, {})
    .get(arch)
)
if not isinstance(entry, dict):
    raise SystemExit(
        f"manifest has no release asset for platform={platform} config={config} arch={arch}"
    )

mode = requested_mode
if mode == "auto":
    mode = "dynamic" if "dynamic" in entry else "static"
asset = entry.get(mode)
if not isinstance(asset, dict):
    raise SystemExit(
        f"manifest has no {mode} release asset for platform={platform} config={config} arch={arch}"
    )

source = provider.get("source_archive", {})
items = {
    "owner": provider["owner"],
    "repo": provider["repo"],
    "tag": tag,
    "commit": provider["commit"],
    "release_url": provider["release_url"],
    "asset_name": asset["name"],
    "asset_sha256": asset["sha256"],
    "asset_size": str(asset.get("size", "")),
    "asset_url": asset["url"],
    "link_mode": mode,
    "library_names": " ".join(asset.get("library_names", [])),
    "source_name": source.get("name", f"{provider['owner']}-{provider['repo']}-{tag}-source.zip"),
    "source_url": source.get(
        "url", f"https://github.com/{provider['owner']}/{provider['repo']}/archive/refs/tags/{tag}.zip"
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

owner="$(get_manifest_value owner)"
repo="$(get_manifest_value repo)"
tag="$(get_manifest_value tag)"
commit="$(get_manifest_value commit)"
release_url="$(get_manifest_value release_url)"
asset_name="$(get_manifest_value asset_name)"
asset_sha256="$(get_manifest_value asset_sha256)"
asset_size="$(get_manifest_value asset_size)"
asset_url="$(get_manifest_value asset_url)"
resolved_link_mode="$(get_manifest_value link_mode)"
library_names="$(get_manifest_value library_names)"
source_name="$(get_manifest_value source_name)"
source_url="$(get_manifest_value source_url)"
extra_cc_flags="$(get_manifest_value extra_cc_flags)"
extra_link_flags="$(get_manifest_value extra_link_flags)"

tag_dir="$resolved_cache_dir/$tag"
entry_dir="$tag_dir/$resolved_platform-$config-$resolved_arch-$resolved_link_mode"
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
  local name lib
  for name in $library_names libskia.a libskia.so libskia.dylib skia.lib; do
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
  local label="${3:-Skia release file}"
  local expected_sha256="${4:-}"
  local expected_size="${5:-}"
  if ! command -v curl >/dev/null 2>&1; then
    echo "missing required command: curl" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$output")"
  {
    echo "Downloading $label:"
    echo "  url=$url"
    echo "  output=$output"
    if [[ -n "$expected_size" ]]; then
      echo "  expected_size=$expected_size"
    fi
    if [[ -n "$expected_sha256" ]]; then
      echo "  expected_sha256=$expected_sha256"
    fi
  } >&2
  if [[ -s "$output" ]]; then
    echo "  mode=resume" >&2
    curl \
      --fail \
      --location \
      --http1.1 \
      --connect-timeout 30 \
      --retry 5 \
      --retry-delay 2 \
      --speed-limit 1024 \
      --speed-time 60 \
      --continue-at - \
      -o "$output" \
      "$url"
    return
  fi
  echo "  mode=fresh" >&2
  curl \
    --fail \
    --location \
    --http1.1 \
    --connect-timeout 30 \
    --retry 5 \
    --retry-delay 2 \
    --speed-limit 1024 \
    --speed-time 60 \
    -o "$output" \
    "$url"
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
    if [[ $force -eq 1 && -f "$package_zip" ]]; then
      rm -f "$package_zip"
    fi
    if [[ $force -eq 1 || ! -f "$package_zip" ]]; then
      download_file "$asset_url" "$package_zip" "Skia release asset $asset_name" "$asset_sha256" "$asset_size"
    fi
    actual_sha256="$(compute_sha256 "$package_zip" | tr '[:upper:]' '[:lower:]')"
    if [[ "$actual_sha256" != "$asset_sha256" ]]; then
      echo "Skia release asset SHA256 mismatch after initial check; retrying download: $package_zip" >&2
      echo "  expected=$asset_sha256" >&2
      echo "  actual=$actual_sha256" >&2
      download_file "$asset_url" "$package_zip" "Skia release asset $asset_name" "$asset_sha256" "$asset_size"
      actual_sha256="$(compute_sha256 "$package_zip" | tr '[:upper:]' '[:lower:]')"
    fi
    if [[ "$actual_sha256" != "$asset_sha256" ]]; then
      echo "Skia release asset SHA256 mismatch after resumed retry; downloading a fresh copy: $package_zip" >&2
      echo "  expected=$asset_sha256" >&2
      echo "  actual=$actual_sha256" >&2
      rm -f "$package_zip"
      download_file "$asset_url" "$package_zip" "Skia release asset $asset_name" "$asset_sha256" "$asset_size"
      actual_sha256="$(compute_sha256 "$package_zip" | tr '[:upper:]' '[:lower:]')"
    fi
    if [[ "$actual_sha256" != "$asset_sha256" ]]; then
      echo "Skia release asset SHA256 mismatch: $package_zip" >&2
      echo "  expected=$asset_sha256" >&2
      echo "  actual=$actual_sha256" >&2
      exit 1
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
      download_file "$source_url" "$source_zip" "Skia release source archive for headers $tag"
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
    echo "Skia library for platform=$resolved_platform link_mode=$resolved_link_mode was not found in $package_dir" >&2
    exit 1
  fi
fi

skia_root="$skia_include"
lib_dir_normalized="${skia_lib_dir%/}"
suffix="/out/$config-$resolved_arch"
if [[ "$lib_dir_normalized" == *"$suffix" ]]; then
  skia_root="${lib_dir_normalized:0:${#lib_dir_normalized}-${#suffix}}"
fi

if [[ $print_env -eq 1 ]]; then
  cat <<EOF
MOUI_SKIA_PROVIDER=release
MOUI_SKIA_SKIA_PROVIDER=release
MOUI_SKIA_RELEASE_OWNER=$owner
MOUI_SKIA_RELEASE_REPO=$repo
MOUI_SKIA_RELEASE_TAG=$tag
MOUI_SKIA_RELEASE_URL=$release_url
MOUI_SKIA_SKIA_ROOT=$skia_root
MOUI_SKIA_SKIA_COMMIT=$commit
MOUI_SKIA_SKIA_PACKAGE=$asset_name
MOUI_SKIA_SKIA_PACKAGE_SHA256=$asset_sha256
MOUI_SKIA_LINK_MODE=$resolved_link_mode
MOUI_SKIA_SKIA_INCLUDE=$skia_include
MOUI_SKIA_SKIA_LIB_DIR=$skia_lib_dir
MOUI_SKIA_SKIA_LIB=skia
MOUI_SKIA_EXTRA_CC_FLAGS=$extra_cc_flags
MOUI_SKIA_EXTRA_LINK_FLAGS=$extra_link_flags
EOF
  exit 0
fi

cat <<EOF
Skia release provider:
  skia_provider=release
  release_owner=$owner
  release_repo=$repo
  release_tag=$tag
  release_url=$release_url
  skia_commit=$commit
  skia_package=$asset_name
  skia_package_sha256=$asset_sha256
  skia_package_size=$asset_size
  skia_package_url=$asset_url
  skia_link_mode=$resolved_link_mode
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
  echo "Dry run complete; Skia release asset was not downloaded or extracted."
fi
