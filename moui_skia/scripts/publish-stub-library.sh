#!/usr/bin/env bash
# Package the locally built Skia C++ stub archive as a wzzc-dev/skia release asset.
#
# Why this exists
# ---------------
# `mbt` classifies MSVC stub compiles as C and injects `/std:c11`, which clashes
# with the `/std:c++20` that the Skia stub needs (MSVC D8016). Until MoonBit
# ships a `stub-cxx-flags` c/cpp split, `moui_skia/native/` keeps only pure-C
# sources in the `mbt` build and the C++ stub travels as a prebuilt archive in
# the `wzzc-dev/skia` release next to the Skia archives. This script turns a
# local stub build into that archive and prints the exact upload command plus
# the `skia-provider-lock.json` entry for it.
#
# Nothing here uploads or edits the lock: it prints what to paste and run.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: publish-stub-library.sh [options]

Options:
  --stub PATH        Stub archive to publish. Defaults to $MOUI_SKIA_STUB_LIB_PATH
                     (emitted by the build.mbtx prebuild), then to the newest
                     .skia-cache/stub-build/*/lib*mui_skia_stub.a under the module.
  --platform NAME    Lock platform key: macos (auto), linux, windows, android.
  --config NAME      Lock config key (auto, default Release).
  --arch NAME        Lock arch key (auto).
  --tag TAG          Release tag (auto, default from skia-provider-lock.json).
  --out-dir DIR      Where the zip is written (default dist/).
  --lock PATH        Lock path (default <module>/skia-provider-lock.json).
  --check            Do not package. Fail when the lock entry is missing, or when
                     its sources_sha256 does not match native/*.cpp|*.h in the tree
                     (detector for "stub assets went stale").
  -h, --help         Show this help.

Output keys (also usable with --print-env):
  MOUI_SKIA_STUB_ASSET_NAME / _PATH / _SHA256 / _SIZE / _SOURCES_SHA256
EOF
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
module_root="$(cd "$script_dir/.." && pwd)"

stub_path=""
platform="auto"
config="auto"
arch="auto"
tag=""
out_dir=""
lock_path="$module_root/skia-provider-lock.json"
check_mode=0
print_env=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stub) stub_path="$2"; shift 2 ;;
    --platform) platform="$2"; shift 2 ;;
    --config) config="$2"; shift 2 ;;
    --arch) arch="$2"; shift 2 ;;
    --tag) tag="$2"; shift 2 ;;
    --out-dir) out_dir="$2"; shift 2 ;;
    --lock) lock_path="$2"; shift 2 ;;
    --check) check_mode=1; shift ;;
    --print-env) print_env=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

detect_platform() {
  case "$(uname -s)" in
    Darwin) echo macos ;;
    Linux) echo linux ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT) echo windows ;;
    *) uname -s | tr '[:upper:]' '[:lower:]' ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    arm64|aarch64) echo arm64 ;;
    x86_64|amd64) echo x64 ;;
    *) uname -m ;;
  esac
}

if [[ -z "$out_dir" ]]; then out_dir="$module_root/dist"; fi

# Source fingerprint: hashing the *sources* (not the archive) is what makes the
# stale-asset detector work, because `ar` output is not byte-reproducible.
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

sha256_of_stdin() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    shasum -a 256 | awk '{print $1}'
  fi
}

sources_sha256() (
  cd "$module_root"
  local list
  list="$( { ls -1 native/*.cpp 2>/dev/null || true; ls -1 native/*.h 2>/dev/null || true; } | LC_ALL=C sort )"
  if [[ -z "$list" ]]; then
    echo ""
    return 0
  fi
  local f
  while read -r f; do
    [[ -z "$f" ]] && continue
    printf '%s  %s\n' "$(sha256_of "$f")" "$f"
  done <<<"$list" | sha256_of_stdin
)

lock_get() {
  python3 - "$lock_path" "$@" <<'PY'
import json
import pathlib
import sys

lock_path = pathlib.Path(sys.argv[1])
platform, config, arch, tag = sys.argv[2:6]
lock = json.loads(lock_path.read_text(encoding="utf-8"))
provider = lock.get("providers", {}).get("release", {})
entry = (
    provider.get("stub_libraries", {})
    .get(platform, {})
    .get(config, {})
    .get(arch)
)
resolved_tag = tag or provider.get("tag", "")
if not isinstance(entry, dict):
    print(f"status=missing")
else:
    print(f"status=present")
    print(f"name={entry.get('name', '')}")
    print(f"sha256={entry.get('sha256', '')}")
    print(f"size={entry.get('size', '')}")
    print(f"sources_sha256={entry.get('sources_sha256', '')}")
    print(f"library_names={','.join(entry.get('library_names', []))}")
print(f"tag={resolved_tag}")
print(f"owner={provider.get('owner', 'wzzc-dev')}")
print(f"repo={provider.get('repo', 'skia')}")
PY
}

lock_value() {
  local key="$1"
  shift
  printf '%s\n' "$(lock_get "$@" 2>/dev/null)" | sed -n "s/^${key}=//p" | tail -n 1
}

if [[ "$platform" == "auto" ]]; then platform="$(detect_platform)"; fi
if [[ "$arch" == "auto" ]]; then arch="$(detect_arch)"; fi

resolved_tag="$(lock_value tag "$platform" "$config" "$arch" "$tag")"
if [[ -z "$resolved_tag" ]]; then
  echo "could not resolve release tag from $lock_path" >&2
  exit 1
fi
if [[ "$config" == "auto" ]]; then
  config="$(python3 - "$lock_path" <<'PY'
import json, pathlib, sys
lock = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
print(lock.get("default_config", "Release"))
PY
)"
fi

sources_sha="$(sources_sha256)"

# ----- --check: stale detector (no packaging, no network) -----
if [[ $check_mode -eq 1 ]]; then
  status="$(lock_value status "$platform" "$config" "$arch" "$tag")"
  locked_sources="$(lock_value sources_sha256 "$platform" "$config" "$arch" "$tag")"
  locked_name="$(lock_value name "$platform" "$config" "$arch" "$tag")"
  echo "stub asset check:"
  echo "  platform=$platform config=$config arch=$arch tag=$resolved_tag"
  echo "  sources_sha256=$sources_sha"
  echo "  lock=$lock_path"
  if [[ "$status" != "present" ]]; then
    echo "  status=missing"
    echo "FAIL: no stub library entry for $platform/$config/$arch." >&2
    echo "      Publish it with: moui_skia/scripts/publish-stub-library.sh" >&2
    exit 1
  fi
  echo "  asset=$locked_name"
  echo "  locked_sources_sha256=$locked_sources"
  if [[ "$locked_sources" != "$sources_sha" ]]; then
    echo "FAIL: stub sources changed since the released asset was published." >&2
    echo "      native/*.cpp no longer match $locked_name." >&2
    echo "      Republish: moui_skia/scripts/publish-stub-library.sh --platform $platform --config $config --arch $arch" >&2
    exit 1
  fi
  echo "  status=ok (native/*.cpp match the published stub asset)"
  exit 0
fi

# ----- locate the stub archive -----
if [[ -z "$stub_path" ]]; then
  if [[ -n "${MOUI_SKIA_STUB_LIB_PATH:-}" && -f "${MOUI_SKIA_STUB_LIB_PATH}" ]]; then
    stub_path="$MOUI_SKIA_STUB_LIB_PATH"
  else
    stub_path="$(ls -t "$module_root"/.skia-cache/stub-build/*/lib*mui_skia_stub.a 2>/dev/null | head -n 1 || true)"
  fi
fi
if [[ -z "$stub_path" || ! -f "$stub_path" ]]; then
  echo "no stub archive found; pass --stub PATH or set MOUI_SKIA_STUB_LIB_PATH" >&2
  echo "hint: run 'moon build moui_skia --target native' first (prebuild builds it)" >&2
  exit 1
fi

stub_name="$(basename "$stub_path")"
case "$stub_name" in
  *.a|*.lib) ;;
  *) echo "stub archive must end in .a or .lib: $stub_path" >&2; exit 1 ;;
esac

asset_name="MoUISkiaStub-$resolved_tag-$platform-$config-$arch.zip"
mkdir -p "$out_dir"
asset_path="$out_dir/$asset_name"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
cp "$stub_path" "$staging/$stub_name"
( cd "$staging" && zip -q -X "$asset_path" "$stub_name" )

asset_size="$(wc -c < "$asset_path" | tr -d ' ')"
stub_sha="$(sha256_of "$stub_path")"
asset_sha="$(sha256_of "$asset_path")"
owner="$(lock_value owner "$platform" "$config" "$arch" "$tag")"
repo="$(lock_value repo "$platform" "$config" "$arch" "$tag")"
asset_url="https://github.com/$owner/$repo/releases/download/$resolved_tag/$asset_name"

if [[ $print_env -eq 1 ]]; then
  cat <<EOF
MOUI_SKIA_STUB_ASSET_NAME=$asset_name
MOUI_SKIA_STUB_ASSET_PATH=$asset_path
MOUI_SKIA_STUB_ASSET_SHA256=$asset_sha
MOUI_SKIA_STUB_ASSET_SIZE=$asset_size
MOUI_SKIA_STUB_SHA256=$stub_sha
MOUI_SKIA_STUB_SOURCES_SHA256=$sources_sha
MOUI_SKIA_STUB_RELEASE_TAG=$resolved_tag
MOUI_SKIA_STUB_RELEASE_URL=$asset_url
EOF
  exit 0
fi

cat <<EOF
Skia stub library package:
  module_root=$module_root
  stub=$stub_path
  stub_sha256=$stub_sha
  sources_sha256=$sources_sha
  platform=$platform
  config=$config
  arch=$arch
  release_tag=$resolved_tag
  asset=$asset_path
  asset_size=$asset_size
  asset_sha256=$asset_sha
  asset_url=$asset_url

Upload (do not run before the lead approves the release change):
  gh release upload $resolved_tag "$asset_path" --repo $owner/$repo

Lock entry for skia-provider-lock.json (providers.release.stub_libraries):
  "$platform": {
    "$config": {
      "$arch": {
        "name": "$asset_name",
        "url": "$asset_url",
        "sha256": "$asset_sha",
        "size": $asset_size,
        "sources_sha256": "$sources_sha",
        "library_names": [
          "$stub_name"
        ]
      }
    }
  }

After uploading, keep lock and asset consistent and re-run:
  moui_skia/scripts/publish-stub-library.sh --check --platform $platform --config $config --arch $arch
EOF
