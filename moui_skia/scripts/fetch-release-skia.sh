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
  --list-mirrors         List every recorded download source for the selected
                         release asset, source archive, and stub, then exit.
  --probe                Print a probe report (first 256 KiB from each candidate
                         plus a ready-to-use MOUI_SKIA_MIRROR suggestion) and
                         exit. A large download runs the same probe anyway.
  --no-probe             Skip the automatic speed probe and keep the default
                         order (primary host, then the mirrors).
  --auto-probe           Force the automatic speed probe (the default).
  --progress MODE        auto|off|stderr|tty (default: auto). auto writes live
                         progress to the terminal even when stderr is captured.
  --no-progress          Same as --progress off.
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
mirror to try first. Mirrors are either `release-download` copies (the GitCode
repository) or `url-prefix` proxies such as gh-proxy.com that front GitHub
without hosting a copy. Every candidate is verified against the locked SHA256
and size, so a proxy that truncates or rewrites a file is rejected.

MOUI_SKIA_PROBE selects the automatic speed probe. auto (default) times the first
256 KiB of every recorded candidate before a release asset of at least 4 MiB is
downloaded and starts from the fastest one; the probe runs once per invocation,
and the real download still verifies the locked SHA256 and size. off (or
--no-probe) keeps the default order: primary host first, then the mirrors.
--mirror NAME, --no-mirror, and MOUI_SKIA_MIRROR=<name> already name the order
the user wants, so they skip the probe. --probe always prints its report on
stdout and exits; the automatic probe writes to the progress channel, so
--print-env stdout stays machine readable.

MOUI_SKIA_PROGRESS selects the progress channel. auto (default) uses stderr when
it is a terminal; otherwise it writes to /dev/tty, which makes download progress
visible inside `moon build` (MoonBit hides hook stderr unless --verbose). off
silences progress, stderr forces it onto stderr for CI logs, and tty requires a
terminal. Progress lines never go to stdout, so --print-env stays machine
readable. Use --list-mirrors to inspect the recorded sources and --probe for a
standalone measurement; the automatic probe reports the fastest source through
the progress channel.
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
list_mirrors=0
probe=0
progress_mode="${MOUI_SKIA_PROGRESS:-auto}"
mirror_mode="${MOUI_SKIA_MIRROR:-auto}"
probe_mode="${MOUI_SKIA_PROBE:-auto}"

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
    --list-mirrors)
      list_mirrors=1
      shift
      ;;
    --probe)
      probe=1
      shift
      ;;
    --no-probe)
      probe_mode="off"
      shift
      ;;
    --auto-probe)
      probe_mode="auto"
      shift
      ;;
    --progress)
      progress_mode="${2:-}"
      shift 2
      ;;
    --no-progress)
      progress_mode="off"
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
case "$progress_mode" in
  auto|off|stderr|tty) ;;
  *) echo "unsupported --progress mode: $progress_mode (use auto|off|stderr|tty)" >&2; exit 2 ;;
esac
case "$probe_mode" in
  auto|off) ;;
  *) echo "unsupported MOUI_SKIA_PROBE mode: $probe_mode (use auto|off)" >&2; exit 2 ;;
esac
if [[ $list_mirrors -eq 1 || $probe -eq 1 ]]; then
  if [[ $print_env -eq 1 ]]; then
    echo "--list-mirrors and --probe cannot be combined with --print-env" >&2
    exit 2
  fi
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest_path="$repo_root/skia-provider-lock.json"
case "$cache_dir" in
  /*) resolved_cache_dir="$cache_dir" ;;
  *) resolved_cache_dir="$repo_root/$cache_dir" ;;
esac

ui_fd=2
ui_tty=0
ui_target=""

# Progress goes to the terminal even when stderr is captured: MoonBit's prebuild
# hook collects stderr and drops it on success, so a fetch that only writes to
# stderr is invisible during `moon build`. stdout is reserved for --print-env.
setup_ui_channel() {
  ui_fd=2
  ui_tty=0
  ui_target=""
  case "$progress_mode" in
    off)
      ui_fd=""
      return 0
      ;;
    stderr)
      ui_fd=2
      if [[ -t 2 ]]; then ui_tty=1; fi
      return 0
      ;;
    auto|tty)
      if [[ -t 2 ]]; then
        ui_fd=2
        ui_tty=1
        return 0
      fi
      if { : 9>/dev/tty; } 2>/dev/null && { exec 9>/dev/tty; } 2>/dev/null; then
        ui_fd=9
        ui_tty=1
        ui_target="/dev/tty"
        return 0
      fi
      if [[ "$progress_mode" == "tty" ]]; then
        echo "note: MOUI_SKIA_PROGRESS=tty requested but no terminal is available; writing progress to stderr" >&2
      fi
      ui_fd=2
      if [[ -t 2 ]]; then ui_tty=1; fi
      return 0
      ;;
  esac
}

ui() {
  if [[ -z "$ui_fd" ]]; then
    return 0
  fi
  printf '%s\n' "$*" >&"$ui_fd"
}

ui_clear_line() {
  if [[ -n "$ui_fd" && "$ui_tty" -eq 1 ]]; then
    printf '\r\033[K' >&"$ui_fd"
  fi
}

format_bytes() {
  awk -v b="${1:-0}" 'BEGIN {
    split("B KiB MiB GiB TiB", unit, " ");
    i = 1;
    while (b >= 1024 && i < 5) { b /= 1024; i++ }
    if (i == 1) printf "%.0f %s", b, unit[i];
    else printf "%.1f %s", b, unit[i];
  }'
}

format_seconds() {
  awk -v s="${1:-0}" 'BEGIN {
    if (s < 60) printf "%.1fs", s;
    else if (s < 3600) printf "%dm%02.0fs", int(s / 60), s - int(s / 60) * 60;
    else printf "%dh%02.0fm", int(s / 3600), int((s - int(s / 3600) * 3600) / 60);
  }'
}

format_latency() {
  awk -v s="${1:-0}" 'BEGIN { printf "%.2fs", s }'
}

setup_ui_channel

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


def mirror_candidates(scope, artifact_name, primary_url):
    """Mirror URLs for one artifact, filtered by each mirror's selection.

    A `release-download` mirror serves `<base_url>/<asset name>`; a `url-prefix`
    mirror serves `<prefix><primary url>`, which is how ghproxy-style services
    that front GitHub without hosting a copy are recorded.
    """
    candidates = []
    for mirror in provider.get("mirrors") or []:
        if not isinstance(mirror, dict):
            continue
        scopes = mirror.get("scope")
        if isinstance(scopes, str):
            scopes = [scopes]
        if scope not in (scopes or []):
            continue
        name = mirror.get("name", "")
        if not name or not artifact_name:
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
        kind = mirror.get("kind", "release-download")
        if kind == "release-download":
            base_url = mirror.get("base_url", "")
            if not base_url:
                continue
            url = base_url.replace("{tag}", tag) + artifact_name
        elif kind == "url-prefix":
            prefix = mirror.get("prefix", "")
            if not prefix or not primary_url:
                continue
            url = prefix + primary_url
        else:
            continue
        candidates.append(f"{name}::{url}")
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
    "asset_mirrors": mirror_candidates("skia", asset["name"], asset["url"]),
    "link_mode": mode,
    "library_names": " ".join(asset.get("library_names", [])),
    "source_name": source_name,
    "source_url": source.get(
        "url", f"https://github.com/{provider['owner']}/{provider['repo']}/archive/refs/tags/{tag}.zip"
    ),
    "source_mirrors": mirror_candidates(
        "source",
        source_name,
        source.get(
            "url",
            f"https://github.com/{provider['owner']}/{provider['repo']}/archive/refs/tags/{tag}.zip",
        ),
    ),
    "extra_cc_flags": provider.get("default_extra_cc_flags", {}).get(platform, ""),
    "extra_link_flags": provider.get("default_extra_link_flags", {}).get(platform, ""),
    "stub_name": stub.get("name", ""),
    "stub_sha256": stub.get("sha256", ""),
    "stub_size": str(stub.get("size", "")),
    "stub_url": stub.get("url", ""),
    "stub_mirrors": mirror_candidates("stub", stub.get("name", ""), stub.get("url", "")),
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
  local source_name="${6:-primary}"
  local metrics_file metrics http_code bytes elapsed speed status=0 transfer_mode
  local -a curl_args=(
    --fail
    --location
    --http1.1
    --connect-timeout 30
    --retry 5
    --retry-delay 2
    --speed-limit 1024
    --speed-time 60
  )
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
  if [[ -n "$ui_fd" && "$ui_tty" -eq 1 ]]; then
    curl_args+=(--progress-bar)
    if [[ "$ui_fd" != "2" ]]; then
      curl_args+=(--stderr "$ui_target")
    fi
  else
    curl_args+=(--no-progress-meter)
  fi
  metrics_file="$(mktemp "${TMPDIR:-/tmp}/moui-skia-curl.XXXXXX")" || {
    echo "failed to create a curl metrics temporary file" >&2
    return 1
  }
  ui "  [skia] fetching $label from $source_name"
  ui "         url=$url"
  if [[ -s "$output" ]]; then
    transfer_mode="resume"
    echo "  mode=resume" >&2
    curl "${curl_args[@]}" \
      --continue-at - \
      -o "$output" \
      -w '%{http_code} %{size_download} %{time_total} %{speed_download}\n' \
      "$url" > "$metrics_file" || status=$?
  else
    transfer_mode="fresh"
    echo "  mode=fresh" >&2
    curl "${curl_args[@]}" \
      -o "$output" \
      -w '%{http_code} %{size_download} %{time_total} %{speed_download}\n' \
      "$url" > "$metrics_file" || status=$?
  fi
  metrics=""
  if [[ -f "$metrics_file" ]]; then
    metrics="$(< "$metrics_file")"
  fi
  rm -f "$metrics_file"
  ui_clear_line
  http_code=""
  bytes=""
  elapsed=""
  speed=""
  if [[ -n "$metrics" ]]; then
    read -r http_code bytes elapsed speed <<< "$metrics" || true
  fi
  if [[ $status -ne 0 ]]; then
    ui "  [skia] download failed from $source_name (curl exit $status)"
    return $status
  fi
  if [[ -n "$bytes" && -n "$elapsed" && -n "$speed" ]]; then
    ui "  [skia] ${transfer_mode}: received $(format_bytes "$bytes") in $(format_seconds "$elapsed") ($(format_bytes "$speed")/s, http $http_code) from $source_name"
  else
    ui "  [skia] downloaded from $source_name"
  fi
  return 0
}

download_source=""

# Print the ordered download candidates for one artifact as "name::url" lines.
# MOUI_SKIA_MIRROR=auto tries the primary host first and then every mirror, or
# the source picked by the automatic probe (preferred_source, matched exactly or
# by the "<name>-something" convention) before the primary host; off keeps the
# primary host only, and any other value names one mirror to try first (that
# mirror, then the primary host, then the remaining mirrors).
build_candidates() {
  local primary_url="$1"
  local mirror_list="$2"
  local prefer="$preferred_source"
  local entry name url
  local -a preferred=()
  local -a others=()
  local matched=0
  if [[ -n "$mirror_list" && "$mirror_mode" != "off" ]]; then
    for entry in $mirror_list; do
      name="${entry%%::*}"
      url="${entry#*::}"
      if [[ "$mirror_mode" == "auto" ]]; then
        if [[ -n "$prefer" && ( "$name" == "$prefer" || "$name" == "$prefer"-* ) ]]; then
          preferred+=("$name::$url")
        else
          others+=("$name::$url")
        fi
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
  if [[ ${#candidates[@]} -eq 0 ]]; then
    printf '%s' ""
    return 0
  fi
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

# Every recorded candidate in discovery order (primary first), regardless of the
# active mirror mode. Used by --list-mirrors and --probe so users can see and
# measure sources that the current mode would not try.
all_candidates() {
  local primary_url="$1"
  local mirror_list="$2"
  local entry
  if [[ -n "$primary_url" ]]; then
    printf 'primary::%s\n' "$primary_url"
  fi
  for entry in $mirror_list; do
    if [[ -n "$entry" ]]; then
      printf '%s\n' "$entry"
    fi
  done
}

print_mirror_sources() {
  local label="$1"
  local primary_url="$2"
  local mirror_list="$3"
  local entry name url marker
  local -a candidates=()
  while IFS= read -r entry; do
    [[ -n "$entry" ]] && candidates+=("$entry")
  done < <(all_candidates "$primary_url" "$mirror_list")
  printf '%s\n' "$label"
  if [[ ${#candidates[@]} -eq 0 ]]; then
    printf '  (none recorded)\n'
    return 0
  fi
  for entry in "${candidates[@]}"; do
    name="${entry%%::*}"
    url="${entry#*::}"
    marker=""
    if [[ "$mirror_mode" != "auto" && "$mirror_mode" != "off" && ( "$name" == "$mirror_mode" || "$name" == "$mirror_mode"-* ) ]]; then
      marker="  (preferred by --mirror $mirror_mode)"
    fi
    printf '  %-26s %s%s\n' "$name" "$url" "$marker"
  done
}

probe_best_name=""
probe_best_speed=0
probe_primary_speed=0
probe_report_mode="stdout"
probe_done=0
preferred_source=""

# --probe reads its report on stdout; the automatic probe routes it through the
# progress channel, whose stdout is reserved for --print-env.
probe_line() {
  if [[ "$probe_report_mode" == "ui" ]]; then
    ui "$*"
  else
    printf '%s\n' "$*"
  fi
}

# Measure connection setup, time to first byte, and throughput for a bounded
# 256 KiB range. It is deliberately approximate: no archive is written, and a
# slow mirror is only ever a suggestion, since the real download still has to
# pass SHA256 and size verification.
probe_candidate() {
  local name="$1"
  local url="$2"
  local err_file metrics status=0 http_code connect ttfb total bytes speed detail suffix
  if ! command -v curl >/dev/null 2>&1; then
    echo "missing required command: curl" >&2
    return 1
  fi
  err_file="$(mktemp "${TMPDIR:-/tmp}/moui-skia-probe.XXXXXX")" || return 1
  metrics="$(curl \
    --location \
    --http1.1 \
    --connect-timeout 8 \
    --max-time 25 \
    --max-filesize 16777216 \
    --range 0-262143 \
    --no-progress-meter \
    -sS \
    -o /dev/null \
    -w '%{http_code} %{time_connect} %{time_starttransfer} %{time_total} %{size_download} %{speed_download}' \
    "$url" 2>"$err_file")" || status=$?
  http_code=""
  connect=""
  ttfb=""
  total=""
  bytes=""
  speed=""
  if [[ -n "$metrics" ]]; then
    read -r http_code connect ttfb total bytes speed <<< "$metrics" || true
  fi
  detail="$(head -n 1 "$err_file" 2>/dev/null || true)"
  rm -f "$err_file"
  if [[ "$http_code" =~ ^[0-9]+$ ]] && (( http_code >= 400 )); then
    probe_line "$(printf '  %-26s failed (http=%s)' "$name" "$http_code")"
    return 1
  fi
  if [[ $status -eq 63 ]]; then
    probe_line "$(printf '  %-26s skipped (too large and does not honor Range; try it directly with --mirror %s)' \
      "$name" "$name")"
    return 1
  fi
  if [[ $status -ne 0 && "${bytes:-0}" == "0" ]]; then
    if [[ -n "$detail" ]]; then
      probe_line "$(printf '  %-26s failed (curl %s: %s)' "$name" "$status" "$detail")"
    else
      probe_line "$(printf '  %-26s failed (curl %s)' "$name" "$status")"
    fi
    return 1
  fi
  suffix=""
  if [[ $status -ne 0 ]]; then
    suffix="  (probe cut off)"
  fi
  probe_line "$(printf '  %-26s http=%s  ttfb=%s  %s in %s  %s/s%s' \
    "$name" "${http_code:-?}" "$(format_latency "${ttfb:-0}")" \
    "$(format_bytes "${bytes:-0}")" "$(format_seconds "${total:-0}")" \
    "$(format_bytes "${speed:-0}")" "$suffix")"
  if awk -v s="${speed:-0}" -v b="$probe_best_speed" 'BEGIN { exit !(s > b) }'; then
    probe_best_name="$name"
    probe_best_speed="${speed:-0}"
  fi
  if [[ "$name" == "primary" ]]; then
    probe_primary_speed="${speed:-0}"
  fi
  return 0
}

# Probe every recorded candidate once and record the fastest one in the
# probe_* globals. Returns 1 when the lock records no candidate.
probe_all_candidates() {
  local primary_url="$1"
  local mirror_list="$2"
  local entry name url
  local -a candidates=()
  probe_best_name=""
  probe_best_speed=0
  probe_primary_speed=0
  while IFS= read -r entry; do
    [[ -n "$entry" ]] && candidates+=("$entry")
  done < <(all_candidates "$primary_url" "$mirror_list")
  if [[ ${#candidates[@]} -eq 0 ]]; then
    return 1
  fi
  for entry in "${candidates[@]}"; do
    name="${entry%%::*}"
    url="${entry#*::}"
    probe_candidate "$name" "$url" || true
  done
  return 0
}

# --probe writes its report on stdout and downloads nothing.
run_probe() {
  local label="$1"
  local primary_url="$2"
  local mirror_list="$3"
  probe_report_mode="stdout"
  printf 'Probing %s: first 256 KiB from each candidate (max 25s each).\n' "$label"
  if ! probe_all_candidates "$primary_url" "$mirror_list"; then
    printf '  (no download source is recorded)\n'
    return 0
  fi
  printf '\n'
  if [[ -z "$probe_best_name" ]]; then
    printf 'No candidate answered the probe; the default order still verifies every source.\n'
    return 0
  fi
  if [[ "$probe_best_name" == "primary" ]]; then
    printf 'Fastest probe: primary host (%s/s). The default auto order already tries it first.\n' \
      "$(format_bytes "$probe_best_speed")"
  elif awk -v m="$probe_best_speed" -v p="$probe_primary_speed" 'BEGIN { exit !(m > p * 1.15) }'; then
    printf 'Fastest probe: %s (%s/s). Prefer it with:\n' "$probe_best_name" "$(format_bytes "$probe_best_speed")"
    printf '  MOUI_SKIA_MIRROR=%s sh scripts/fetch-release-skia.sh\n' "$probe_best_name"
    printf '  # or: sh scripts/fetch-release-skia.sh --mirror %s\n' "$probe_best_name"
  else
    printf 'Fastest probe: %s (%s/s), close to the primary host.\n' \
      "$probe_best_name" "$(format_bytes "$probe_best_speed")"
  fi
  printf 'Note: the probe only measures the first 256 KiB; the real download still verifies the full SHA256 and size.\n'
}

# The automatic probe runs once per invocation before a large download. It
# reports through the progress channel (stdout is reserved for --print-env) and
# only reorders the candidates: every download still verifies SHA256 and size.
auto_probe_sources() {
  local label="$1"
  local primary_url="$2"
  local mirror_list="$3"
  probe_report_mode="ui"
  ui "  [skia] probing $label (first 256 KiB from each recorded source)"
  if ! probe_all_candidates "$primary_url" "$mirror_list"; then
    ui "  [skia] no download source is recorded; keeping the default order"
  elif [[ -z "$probe_best_name" ]]; then
    ui "  [skia] probe answered nothing; keeping the default order"
  elif [[ "$probe_best_name" == "primary" ]]; then
    ui "  [skia] fastest source: primary host ($(format_bytes "$probe_best_speed")/s)"
  else
    preferred_source="$probe_best_name"
    ui "  [skia] fastest source: $probe_best_name ($(format_bytes "$probe_best_speed")/s); trying it first"
  fi
  probe_report_mode="stdout"
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
  local probe_size_ok=0
  download_source=""
  if [[ -z "$primary_url" && -z "$mirror_list" ]]; then
    echo "no download URL is recorded for $label" >&2
    return 1
  fi
  # Automatic speed probe: default in auto mirror mode, at most once per run,
  # and only for an asset worth measuring (a tiny stub keeps the plain order).
  if [[ -z "$expected_size" ]]; then
    probe_size_ok=1
  elif [[ "$expected_size" =~ ^[0-9]+$ ]] && (( expected_size >= 4194304 )); then
    probe_size_ok=1
  fi
  if [[ "$probe_mode" == "auto" && "$mirror_mode" == "auto" && -n "$mirror_list" && $probe_done -eq 0 && $probe_size_ok -eq 1 ]]; then
    probe_done=1
    auto_probe_sources "$label" "$primary_url" "$mirror_list"
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
    if ! download_file "$url" "$output" "$label" "$expected_sha256" "$expected_size" "$name"; then
      echo "download failed from $url; trying the next candidate" >&2
      ui "  [skia] $name failed; trying the next source"
      rm -f "$output"
      continue
    fi
    actual_sha256="$(compute_sha256 "$output" | tr '[:upper:]' '[:lower:]')"
    if [[ -n "$expected_sha256" && "$actual_sha256" != "$expected_sha256" ]]; then
      echo "SHA256 mismatch from $url" >&2
      echo "  expected=$expected_sha256" >&2
      echo "  actual=$actual_sha256" >&2
      ui "  [skia] $name returned a file with the wrong SHA256; trying the next source"
      rm -f "$output"
      continue
    fi
    actual_size="$(wc -c < "$output" | tr -d '[:space:]')"
    if [[ -n "$expected_size" && "$actual_size" != "$expected_size" ]]; then
      echo "size mismatch from $url" >&2
      echo "  expected=$expected_size" >&2
      echo "  actual=$actual_size" >&2
      ui "  [skia] $name returned the wrong size; trying the next source"
      rm -f "$output"
      continue
    fi
    download_source="$name"
    echo "  verified_from=$name" >&2
    ui "  [skia] verified $(format_bytes "${actual_size:-0}") from $name"
    return 0
  done
  echo "could not download $label from any recorded source" >&2
  ui "  [skia] all recorded sources failed for $label"
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

if [[ $list_mirrors -eq 1 ]]; then
  printf 'Skia download sources (mirror mode: %s)\n\n' "$mirror_mode"
  print_mirror_sources "release asset: $asset_name" "$asset_url" "$asset_mirrors"
  printf '\n'
  print_mirror_sources "source archive: $source_name" "$source_url" "$source_mirrors"
  printf '\n'
  if [[ -n "$stub_name" ]]; then
    print_mirror_sources "stub library: $stub_name" "$stub_url" "$stub_mirrors"
  else
    printf 'stub library: not published for %s-%s-%s (native/*.cpp compiles locally)\n' \
      "$resolved_platform" "$config" "$resolved_arch"
  fi
  printf '\nPick a source with --mirror <name> or MOUI_SKIA_MIRROR=<name>; --no-mirror keeps the primary host only.\n'
  exit 0
fi

if [[ $probe -eq 1 ]]; then
  run_probe "Skia release asset $asset_name" "$asset_url" "$asset_mirrors"
  exit 0
fi

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
