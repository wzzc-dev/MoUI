#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/fetch-release-skia.sh [options]

Options:
  --platform auto|macos|linux|windows|android|harmonyos|ios|iosSim|tvos|tvosSim|wasm
                         Target release package platform. Default: auto.
  --arch auto|arm64|x64|riscv64
                         Target package architecture. Default: auto.
                         wasm uses the manifest wasm asset when --arch auto.
  --config Release|Debug Target package configuration. Default: Release.
  --link-mode static|dynamic|auto
                         Release asset link mode. Default: static.
  --tag TAG              GitHub release tag. Default from skia-provider-lock.json.
  --cache-dir PATH       Cache root. Default: .skia-cache/release.
  --mirror NAME          Prefer the named provider mirror from
                         providers.<provider>.mirrors before the primary host.
                         A name also covers mirrors named "<NAME>-something", so
                         --mirror gitcode prefers gitcode-skia and
                         gitcode-skia-stub at once.
  --no-mirror            Ignore every mirror and download from the primary host
                         only.
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

Mirror behaviour: MOUI_SKIA_MIRROR=auto (default) downloads from the primary
release host and falls back to every mirror recorded in
skia-provider-lock.json, off disables mirrors, and any other value names one
mirror to try first. Mirrors must serve byte-identical assets; every candidate
is verified against the locked SHA256 and size.
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
mirror_mode="${MOUI_SKIA_MIRROR:-auto}"

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
    --mirror)
      mirror_mode="${2:-}"
      shift 2
      ;;
    --no-mirror)
      mirror_mode="off"
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
  auto|macos|linux|windows|android|harmonyos|ios|iosSim|tvos|tvosSim|wasm) ;;
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
if [[ -z "$mirror_mode" ]]; then
  echo "--mirror requires a mirror name (or use --no-mirror)" >&2
  exit 2
fi

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
providers = manifest.get("providers", {})
provider_key = "release"
if platform == "harmonyos" and isinstance(providers.get("harmonyos_release"), dict):
    provider_key = "harmonyos_release"
provider = providers.get(provider_key)
if not isinstance(provider, dict):
    raise SystemExit(f"skia-provider-lock.json is missing providers.{provider_key}")

tag = requested_tag or provider.get("tag", "")
if tag != provider.get("tag"):
    raise SystemExit(
        f"manifest provider {provider_key} only locks release tag {provider.get('tag')}, requested {tag}"
    )

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

stub_entry = (
    provider.get("stub_libraries", {})
    .get(platform, {})
    .get(config, {})
    .get(arch)
)
stub = stub_entry if isinstance(stub_entry, dict) else {}
source = provider.get("source_archive", {})


def mirror_candidates(scope, artifact_name):
    """Mirror URLs serving artifact_name, filtered by the mirror's selection."""
    candidates = []
    for mirror in provider.get("mirrors") or []:
        if not isinstance(mirror, dict) or mirror.get("scope") != scope:
            continue
        base_url = mirror.get("base_url", "")
        name = mirror.get("name", "")
        if not base_url or not name or not artifact_name:
            continue
        platforms = mirror.get("platforms")
        if platforms and platform not in platforms:
            continue
        configs = mirror.get("configs")
        if configs and config not in configs:
            continue
        arches = mirror.get("arches")
        if arches and arch not in arches:
            continue
        link_modes = mirror.get("link_modes")
        if link_modes and mode not in link_modes:
            continue
        candidates.append(f"{name}::{base_url.replace('{tag}', tag)}{artifact_name}")
    return " ".join(candidates)


source_name = source.get("name", f"{provider['owner']}-{provider['repo']}-{tag}-source.zip")
items = {
    "provider_key": provider_key,
    "owner": provider["owner"],
    "repo": provider["repo"],
    "tag": tag,
    "commit": provider["commit"],
    "release_url": provider["release_url"],
    "asset_name": asset["name"],
    "asset_sha256": asset["sha256"],
    "asset_size": str(asset.get("size", "")),
    "asset_url": asset["url"],
    "asset_mirrors": mirror_candidates("skia", asset["name"]),
    "link_mode": mode,
    "library_names": " ".join(asset.get("library_names", [])),
    "source_name": source_name,
    "source_url": source.get(
        "url", f"https://github.com/{provider['owner']}/{provider['repo']}/archive/refs/tags/{tag}.zip"
    ),
    "source_mirrors": mirror_candidates("source", source_name),
    "extra_cc_flags": provider.get("default_extra_cc_flags", {}).get(platform, ""),
    "extra_link_flags": provider.get("default_extra_link_flags", {}).get(platform, ""),
    "stub_name": stub.get("name", ""),
    "stub_sha256": stub.get("sha256", ""),
    "stub_size": str(stub.get("size", "")),
    "stub_url": stub.get("url", ""),
    "stub_mirrors": mirror_candidates("stub", stub.get("name", "")),
    "stub_sources_sha256": stub.get("sources_sha256", ""),
    "stub_library_names": " ".join(stub.get("library_names", [])),
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
provider_key="$(get_manifest_value provider_key)"
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
stub_name="$(get_manifest_value stub_name)"
stub_sha256="$(get_manifest_value stub_sha256)"
stub_size="$(get_manifest_value stub_size)"
stub_url="$(get_manifest_value stub_url)"
stub_sources_sha256="$(get_manifest_value stub_sources_sha256)"
stub_library_names="$(get_manifest_value stub_library_names)"
asset_mirrors="$(get_manifest_value asset_mirrors)"
source_mirrors="$(get_manifest_value source_mirrors)"
stub_mirrors="$(get_manifest_value stub_mirrors)"

tag_dir="$resolved_cache_dir/$tag"
entry_dir="$tag_dir/$resolved_platform-$config-$resolved_arch-$resolved_link_mode"
package_zip="$entry_dir/$asset_name"
package_dir="$entry_dir/package"
source_dir="$tag_dir/source"
source_zip="$tag_dir/$source_name"
stub_entry_dir="$tag_dir/$resolved_platform-$config-$resolved_arch-stub"
stub_zip="$stub_entry_dir/$stub_name"
stub_dir="$stub_entry_dir/package"

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

download_source=""

# Print the ordered download candidates for one artifact as "name::url" lines.
# MOUI_SKIA_MIRROR=auto tries the primary host first and then every mirror,
# off keeps the primary host only, and any other value names one mirror to try
# first (that mirror, then the primary host, then the remaining mirrors).
build_candidates() {
  local primary_url="$1"
  local mirror_list="$2"
  local entry name url
  local -a preferred=()
  local -a others=()
  local matched=0
  if [[ -n "$mirror_list" && "$mirror_mode" != "off" ]]; then
    for entry in $mirror_list; do
      name="${entry%%::*}"
      url="${entry#*::}"
      if [[ "$mirror_mode" == "auto" ]]; then
        others+=("$name::$url")
      elif [[ "$name" == "$mirror_mode" || "$name" == "$mirror_mode"-* ]]; then
        preferred+=("$name::$url")
        matched=1
      else
        others+=("$name::$url")
      fi
    done
  fi
  if [[ "$mirror_mode" != "auto" && "$mirror_mode" != "off" && $matched -eq 0 ]]; then
    echo "note: mirror $mirror_mode does not serve this artifact; using the primary host and the remaining mirrors" >&2
  fi
  if [[ "$mirror_mode" != "off" && ${#preferred[@]} -gt 0 ]]; then
    printf '%s\n' "${preferred[@]}"
  fi
  if [[ -n "$primary_url" ]]; then
    printf '%s\n' "primary::$primary_url"
  fi
  if [[ "$mirror_mode" != "off" && ${#others[@]} -gt 0 ]]; then
    printf '%s\n' "${others[@]}"
  fi
}

candidate_names() {
  local primary_url="$1"
  local mirror_list="$2"
  local entry name names=""
  local -a candidates=()
  while IFS= read -r entry; do
    [[ -n "$entry" ]] && candidates+=("$entry")
  done < <(build_candidates "$primary_url" "$mirror_list")
  for entry in "${candidates[@]}"; do
    name="${entry%%::*}"
    if [[ -z "$names" ]]; then
      names="$name"
    else
      names="$names,$name"
    fi
  done
  printf '%s' "$names"
}

# Download one artifact from its ordered candidates, then verify sha256 and size.
# On success download_source holds the candidate that served the file.
download_artifact() {
  local label="$1"
  local output="$2"
  local expected_sha256="$3"
  local expected_size="$4"
  local primary_url="$5"
  local mirror_list="$6"
  local entry name url actual_size actual_sha256 first=1
  local -a candidates=()
  download_source=""
  if [[ -z "$primary_url" && -z "$mirror_list" ]]; then
    echo "no download URL is recorded for $label" >&2
    return 1
  fi
  while IFS= read -r entry; do
    [[ -n "$entry" ]] && candidates+=("$entry")
  done < <(build_candidates "$primary_url" "$mirror_list")
  if [[ ${#candidates[@]} -eq 0 ]]; then
    echo "no download candidate is recorded for $label" >&2
    return 1
  fi
  for entry in "${candidates[@]}"; do
    name="${entry%%::*}"
    url="${entry#*::}"
    if [[ $first -eq 0 ]]; then
      rm -f "$output"
    fi
    first=0
    echo "  candidate=$name" >&2
    if ! download_file "$url" "$output" "$label" "$expected_sha256" "$expected_size"; then
      echo "download failed from $url; trying the next candidate" >&2
      rm -f "$output"
      continue
    fi
    actual_sha256="$(compute_sha256 "$output" | tr '[:upper:]' '[:lower:]')"
    if [[ -n "$expected_sha256" && "$actual_sha256" != "$expected_sha256" ]]; then
      echo "SHA256 mismatch from $url" >&2
      echo "  expected=$expected_sha256" >&2
      echo "  actual=$actual_sha256" >&2
      rm -f "$output"
      continue
    fi
    if [[ -n "$expected_size" ]]; then
      actual_size="$(wc -c < "$output" | tr -d '[:space:]')"
      if [[ "$actual_size" != "$expected_size" ]]; then
        echo "size mismatch from $url" >&2
        echo "  expected=$expected_size" >&2
        echo "  actual=$actual_size" >&2
        rm -f "$output"
        continue
      fi
    fi
    download_source="$name"
    echo "  verified_from=$name" >&2
    return 0
  done
  echo "could not download $label from any recorded source" >&2
  return 1
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

stub_mode="$(printf '%s' "${MOUI_SKIA_STUB_MODE:-auto}" | tr '[:upper:]' '[:lower:]')"
package_mirror=""
stub_mirror=""

ensure_package_extracted() {
  if [[ $dry_run_config -eq 1 ]]; then
    return 0
  fi
  if [[ $force -eq 1 || ! -d "$package_dir" ]]; then
    mkdir -p "$entry_dir"
    if [[ $force -eq 1 && -f "$package_zip" ]]; then
      rm -f "$package_zip"
    fi
    if [[ -f "$package_zip" ]]; then
      actual_sha256="$(compute_sha256 "$package_zip" | tr '[:upper:]' '[:lower:]')"
      if [[ "$actual_sha256" != "$asset_sha256" ]]; then
        echo "cached Skia release asset SHA256 mismatch; re-downloading: $package_zip" >&2
        echo "  expected=$asset_sha256" >&2
        echo "  actual=$actual_sha256" >&2
        rm -f "$package_zip"
      fi
    fi
    if [[ ! -f "$package_zip" ]]; then
      download_artifact "Skia release asset $asset_name" "$package_zip" \
        "$asset_sha256" "$asset_size" "$asset_url" "$asset_mirrors" || exit 1
      if [[ "$download_source" != "primary" ]]; then
        package_mirror="$download_source"
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
      download_artifact "Skia release source archive for headers $tag" "$source_zip" \
        "" "" "$source_url" "$source_mirrors" || exit 1
    fi
    extract_zip "$source_zip" "$source_dir"
  fi
}

find_stub_lib() {
  local root="$1"
  if [[ ! -d "$root" ]]; then
    return 0
  fi
  local wanted found=""
  for wanted in $stub_library_names libmoui_skia_stub.a moui_skia_stub.lib; do
    found="$(find "$root" -type f -name "$wanted" -print 2>/dev/null | head -n 1 || true)"
    if [[ -n "$found" ]]; then
      echo "$found"
      return 0
    fi
  done
  echo ""
}

ensure_stub_extracted() {
  if [[ -z "$stub_name" ]]; then
    echo "note: skia-provider-lock.json has no released stub library for platform=$resolved_platform config=$config arch=$resolved_arch; the build compiles native/*.cpp locally instead" >&2
    return 0
  fi
  if [[ $dry_run_config -eq 1 ]]; then
    return 0
  fi
  if [[ "${stub_mode:-auto}" == "build" ]]; then
    return 0
  fi
  if [[ $force -eq 0 && -d "$stub_dir" ]]; then
    return 0
  fi
  mkdir -p "$stub_entry_dir"
  if [[ $force -eq 1 && -f "$stub_zip" ]]; then
    rm -f "$stub_zip"
  fi
  if [[ $force -eq 1 || ! -f "$stub_zip" ]]; then
    if ! download_artifact "Skia stub library asset $stub_name" "$stub_zip" \
      "$stub_sha256" "$stub_size" "$stub_url" "$stub_mirrors"; then
      return 1
    fi
    if [[ "$download_source" != "primary" ]]; then
      stub_mirror="$download_source"
    fi
  fi
  local actual_stub_sha256
  actual_stub_sha256="$(compute_sha256 "$stub_zip" | tr '[:upper:]' '[:lower:]')"
  if [[ -n "$stub_sha256" && "$actual_stub_sha256" != "$stub_sha256" ]]; then
    echo "cached Skia stub library SHA256 mismatch; re-downloading: $stub_zip" >&2
    rm -f "$stub_zip"
    if ! download_artifact "Skia stub library asset $stub_name" "$stub_zip" \
      "$stub_sha256" "$stub_size" "$stub_url" "$stub_mirrors"; then
      return 1
    fi
    if [[ "$download_source" != "primary" ]]; then
      stub_mirror="$download_source"
    fi
    actual_stub_sha256="$(compute_sha256 "$stub_zip" | tr '[:upper:]' '[:lower:]')"
  fi
  if [[ -n "$stub_sha256" && "$actual_stub_sha256" != "$stub_sha256" ]]; then
    echo "Skia stub library SHA256 mismatch: $stub_zip" >&2
    echo "  expected=$stub_sha256" >&2
    echo "  actual=$actual_stub_sha256" >&2
    return 1
  fi
  if ! extract_zip "$stub_zip" "$stub_dir"; then
    echo "failed to extract Skia stub library archive: $stub_zip" >&2
    return 1
  fi
  return 0
}

ensure_package_extracted
if ! ensure_stub_extracted; then
  if [[ "$stub_mode" == "prebuilt" ]]; then
    echo "MOUI_SKIA_STUB_MODE=prebuilt requires the released stub asset $stub_name ($stub_url), which is unavailable" >&2
    exit 1
  fi
  echo "note: released stub asset $stub_name is unavailable ($stub_url); the build compiles native/*.cpp locally instead" >&2
  rm -rf "$stub_entry_dir"
  stub_name=""
fi

stub_lib_path=""
if [[ -n "$stub_name" && -d "$stub_dir" ]]; then
  stub_lib_path="$(find_stub_lib "$stub_dir")"
fi

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
for suffix in \
  "/out/$config-$resolved_platform-$resolved_arch-shared" \
  "/out/$config-$resolved_platform-$resolved_arch" \
  "/out/$config-$resolved_arch-shared" \
  "/out/$config-$resolved_arch"; do
  if [[ "$lib_dir_normalized" == *"$suffix" ]]; then
    skia_root="${lib_dir_normalized:0:${#lib_dir_normalized}-${#suffix}}"
    break
  fi
done

stub_env_lines=""
if [[ -n "$stub_lib_path" ]]; then
  stub_env_lines="MOUI_SKIA_STUB_LIB=$stub_lib_path
MOUI_SKIA_STUB_ASSET_SHA256=$stub_sha256
MOUI_SKIA_STUB_SOURCES_SHA256=$stub_sources_sha256
MOUI_SKIA_STUB_SOURCE=release"
else
  stub_env_lines="MOUI_SKIA_STUB_LIB=
MOUI_SKIA_STUB_SOURCE="
fi

if [[ $print_env -eq 1 ]]; then
  cat <<EOF
MOUI_SKIA_PROVIDER=$provider_key
MOUI_SKIA_SKIA_PROVIDER=$provider_key
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
MOUI_SKIA_SKIA_PACKAGE_MIRROR=$package_mirror
MOUI_SKIA_STUB_ASSET_MIRROR=$stub_mirror
$stub_env_lines
EOF
  exit 0
fi

cat <<EOF
Skia release provider:
  skia_provider=$provider_key
  release_owner=$owner
  release_repo=$repo
  release_tag=$tag
  release_url=$release_url
  skia_commit=$commit
  skia_package=$asset_name
  skia_package_sha256=$asset_sha256
  skia_package_size=$asset_size
  skia_package_url=$asset_url
  skia_package_candidates=$(candidate_names "$asset_url" "$asset_mirrors")
  skia_package_mirror=$package_mirror
  skia_link_mode=$resolved_link_mode
  mirror_mode=$mirror_mode
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
  stub_asset=$stub_name
  stub_asset_candidates=$(candidate_names "$stub_url" "$stub_mirrors")
  stub_asset_mirror=$stub_mirror
  stub_asset_sha256=$stub_sha256
  stub_asset_size=$stub_size
  stub_sources_sha256=$stub_sources_sha256
  stub_lib=$stub_lib_path
EOF
if [[ $dry_run_config -eq 1 ]]; then
  echo "Dry run complete; Skia release asset was not downloaded or extracted."
fi
