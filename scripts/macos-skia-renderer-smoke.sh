#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/macos-skia-renderer-smoke.sh [options]

Temporarily configures the local skia_mbt native package plus MoUI's Skia
renderer smoke and macos_skia showcase entrypoints, runs the renderer pixel
smoke, builds examples/showcase/macos_skia, then restores all package files.

Options:
  --skia-provider existing|jetbrains|source
                         Skia acquisition mode. Default: jetbrains unless
                         --skia-include/--skia-lib-dir select existing.
  --work-dir PATH        Directory for source-built Skia work output.
                         Default: .skia-cache/macos.
  --skia-include PATH    Skia checkout or include root containing Skia headers.
                         When supplied with --skia-lib-dir, selects existing.
  --skia-lib-dir PATH    Directory containing libskia.a or libskia.dylib.
  --skia-lib NAME        Library name without lib prefix, default: skia.
  --skia-rev REV         Skia git revision, branch, or tag for source provider.
                         Default: .local_repos/skia_mbt/skia-revision.txt.
  --jetbrains-tag TAG    JetBrains/skia release tag. Default: m148-8967a2e80c.
  --jetbrains-config Release|Debug
                         JetBrains/skia package configuration. Default: Release.
  --jetbrains-cache-dir PATH
                         JetBrains/skia cache root. Default: .skia-cache/jetbrains.
  --extra-gn-args STR    Extra GN args appended to the source-built Skia build.
  --extra-cc-flags STR   Extra C/C++ flags appended to skia_mbt stub flags.
  --extra-link-flags STR Extra linker flags appended to executable link flags.
  --build-log PATH       Write source-built Skia build output to PATH. Relative
                         paths are resolved from the repository root.
  --smoke-log PATH       Write MoUI renderer smoke output to PATH. Relative
                         paths are resolved from the repository root.
  --showcase-log PATH    Write macos_skia Showcase smoke output to PATH.
                         Relative paths are resolved from the repository root.
  --no-sync-deps         Skip python3 tools/git-sync-deps for source provider.
  --no-fetch             Reuse an existing Skia checkout for source provider.
  --skip-showcase-build  Only run the renderer pixel smoke.
  --run-showcase-smoke   After building macos_skia, run it with a first-frame
                         exit flag and verify the renderer-present marker.
  --showcase-timeout SECONDS
                         Seconds to wait for --run-showcase-smoke. Default: 20.
  --dry-run-config       Print resolved paths and flags, then exit without
                         rewriting package files or building executables.
  -h, --help             Show this help.

Environment defaults:
  SKIA_MBT_SKIA_PROVIDER, SKIA_MBT_PROVIDER, SKIA_MBT_SKIA_INCLUDE,
  SKIA_MBT_SKIA_LIB_DIR, SKIA_MBT_SKIA_LIB, SKIA_MBT_SKIA_REV,
  SKIA_MBT_JETBRAINS_TAG, SKIA_MBT_JETBRAINS_CONFIG,
  SKIA_MBT_JETBRAINS_CACHE_DIR, SKIA_MBT_EXTRA_GN_ARGS,
  SKIA_MBT_EXTRA_CC_FLAGS, and SKIA_MBT_EXTRA_LINK_FLAGS are used when the
  matching command-line option is omitted.
EOF
}

work_dir=".skia-cache/macos"
skia_include="${SKIA_MBT_SKIA_INCLUDE:-}"
skia_lib_dir="${SKIA_MBT_SKIA_LIB_DIR:-}"
skia_lib="${SKIA_MBT_SKIA_LIB:-skia}"
skia_provider="${SKIA_MBT_SKIA_PROVIDER:-${SKIA_MBT_PROVIDER:-}}"
skia_provider_explicit=0
if [[ -n "${SKIA_MBT_SKIA_PROVIDER:-}${SKIA_MBT_PROVIDER:-}" ]]; then
  skia_provider_explicit=1
fi
skia_rev="${SKIA_MBT_SKIA_REV:-main}"
skia_rev_explicit=0
if [[ -n "${SKIA_MBT_SKIA_REV:-}" ]]; then
  skia_rev_explicit=1
fi
jetbrains_tag="${SKIA_MBT_JETBRAINS_TAG:-m148-8967a2e80c}"
jetbrains_config="${SKIA_MBT_JETBRAINS_CONFIG:-Release}"
jetbrains_cache_dir="${SKIA_MBT_JETBRAINS_CACHE_DIR:-.skia-cache/jetbrains}"
extra_gn_args="${SKIA_MBT_EXTRA_GN_ARGS:-}"
extra_cc_flags="${SKIA_MBT_EXTRA_CC_FLAGS:-}"
extra_link_flags="${SKIA_MBT_EXTRA_LINK_FLAGS:-}"
extra_cc_flags_explicit=0
extra_link_flags_explicit=0
if [[ -n "${SKIA_MBT_EXTRA_CC_FLAGS:-}" ]]; then
  extra_cc_flags_explicit=1
fi
if [[ -n "${SKIA_MBT_EXTRA_LINK_FLAGS:-}" ]]; then
  extra_link_flags_explicit=1
fi
requested_build_log=""
requested_smoke_log=""
requested_showcase_log=""
sync_deps=1
fetch_repo=1
skip_showcase_build=0
run_showcase_smoke=0
showcase_timeout=20
dry_run_config=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --work-dir)
      work_dir="${2:-}"
      shift 2
      ;;
    --skia-include)
      skia_include="${2:-}"
      shift 2
      ;;
    --skia-lib-dir)
      skia_lib_dir="${2:-}"
      shift 2
      ;;
    --skia-lib)
      skia_lib="${2:-}"
      shift 2
      ;;
    --skia-provider)
      skia_provider="${2:-}"
      skia_provider_explicit=1
      shift 2
      ;;
    --skia-rev)
      skia_rev="${2:-}"
      skia_rev_explicit=1
      shift 2
      ;;
    --jetbrains-tag)
      jetbrains_tag="${2:-}"
      shift 2
      ;;
    --jetbrains-config)
      jetbrains_config="${2:-}"
      shift 2
      ;;
    --jetbrains-cache-dir)
      jetbrains_cache_dir="${2:-}"
      shift 2
      ;;
    --extra-gn-args)
      extra_gn_args="${2:-}"
      shift 2
      ;;
    --extra-cc-flags)
      extra_cc_flags="${2:-}"
      extra_cc_flags_explicit=1
      shift 2
      ;;
    --extra-link-flags)
      extra_link_flags="${2:-}"
      extra_link_flags_explicit=1
      shift 2
      ;;
    --build-log)
      requested_build_log="${2:-}"
      shift 2
      ;;
    --smoke-log)
      requested_smoke_log="${2:-}"
      shift 2
      ;;
    --showcase-log)
      requested_showcase_log="${2:-}"
      shift 2
      ;;
    --no-sync-deps)
      sync_deps=0
      shift
      ;;
    --no-fetch)
      fetch_repo=0
      shift
      ;;
    --skip-showcase-build)
      skip_showcase_build=1
      shift
      ;;
    --run-showcase-smoke)
      run_showcase_smoke=1
      shift
      ;;
    --showcase-timeout)
      showcase_timeout="${2:-}"
      shift 2
      ;;
    --dry-run-config)
      dry_run_config=1
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

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skia_repo="$repo_root/.local_repos/skia_mbt"
native_pkg="$skia_repo/native/moon.pkg"
native_pkg_backup="$native_pkg.moui-smoke.bak"
renderer_pkg="$repo_root/moui/tests/skia_renderer_smoke/native/moon.pkg"
renderer_pkg_backup="$renderer_pkg.moui-smoke.bak"
showcase_pkg="$repo_root/examples/showcase/macos_skia/moon.pkg"
showcase_pkg_backup="$showcase_pkg.moui-smoke.bak"
build_log=""
smoke_log=""
showcase_log=""
smoke_log_is_temporary=0
showcase_log_is_temporary=0

resolve_path() {
  local path="$1"
  case "$path" in
    /*) printf '%s\n' "$path" ;;
    *) printf '%s\n' "$repo_root/$path" ;;
  esac
}

resolve_existing_dir() {
  local label="$1"
  local path="$2"
  if [[ ! -d "$path" ]]; then
    echo "$label does not exist or is not a directory: $path" >&2
    exit 1
  fi
  cd "$path" && pwd
}

get_assignment_value() {
  local input="$1"
  local key="$2"
  printf '%s\n' "$input" | sed -n "s/^${key}=//p" | tail -n 1
}

check_package_backups() {
  for backup in "$native_pkg_backup" "$renderer_pkg_backup" "$showcase_pkg_backup"; do
    if [[ -f "$backup" ]]; then
      echo "package backup already exists: $backup" >&2
      echo "Resolve the stale backup before running the MoUI Skia renderer smoke." >&2
      exit 1
    fi
  done
}

if [[ $dry_run_config -eq 0 ]]; then
  check_package_backups
fi

if [[ $skia_rev_explicit -eq 0 && -f "$skia_repo/skia-revision.txt" ]]; then
  pinned_skia_rev="$(grep -v '^[[:space:]]*#' "$skia_repo/skia-revision.txt" | grep -v '^[[:space:]]*$' | head -n 1 || true)"
  if [[ -n "$pinned_skia_rev" ]]; then
    skia_rev="$pinned_skia_rev"
  fi
fi

if [[ $skia_provider_explicit -eq 0 ]]; then
  if [[ -n "$skia_include" || -n "$skia_lib_dir" ]]; then
    skia_provider="existing"
  else
    skia_provider="jetbrains"
  fi
fi

case "$skia_provider" in
  source|existing|jetbrains) ;;
  *) echo "unsupported --skia-provider: $skia_provider" >&2; exit 2 ;;
esac
case "$jetbrains_config" in
  Release|Debug) ;;
  *) echo "unsupported --jetbrains-config: $jetbrains_config" >&2; exit 2 ;;
esac

resolved_work_dir="$(resolve_path "$work_dir")"
resolved_jetbrains_cache_dir="$(resolve_path "$jetbrains_cache_dir")"

if [[ -n "$requested_build_log" ]]; then
  build_log="$(resolve_path "$requested_build_log")"
fi

if [[ -n "$requested_smoke_log" ]]; then
  smoke_log="$(resolve_path "$requested_smoke_log")"
fi

if [[ -n "$requested_showcase_log" ]]; then
  showcase_log="$(resolve_path "$requested_showcase_log")"
fi

if [[ $run_showcase_smoke -eq 1 && $skip_showcase_build -eq 1 ]]; then
  echo "--run-showcase-smoke cannot be combined with --skip-showcase-build" >&2
  exit 2
fi

if ! [[ "$showcase_timeout" =~ ^[0-9]+$ ]] || [[ "$showcase_timeout" -lt 1 ]]; then
  echo "--showcase-timeout must be a positive integer number of seconds" >&2
  exit 2
fi

source_build_args=()
smoke_mode=""
jetbrains_package=""
jetbrains_package_sha256=""
jetbrains_commit=""

if [[ "$skia_provider" == "existing" ]]; then
  if [[ -z "$skia_include" || -z "$skia_lib_dir" ]]; then
    echo "--skia-include and --skia-lib-dir must be supplied together for --skia-provider existing" >&2
    exit 2
  fi
  smoke_mode="existing Skia build"
  include_path="$(resolve_path "$skia_include")"
  lib_path="$(resolve_path "$skia_lib_dir")"
elif [[ "$skia_provider" == "source" ]]; then
  if [[ -n "$skia_include" || -n "$skia_lib_dir" ]]; then
    echo "--skia-provider source cannot be combined with --skia-include/--skia-lib-dir" >&2
    exit 2
  fi
  smoke_mode="source-built Skia"
  include_path="$resolved_work_dir/skia"
  lib_path="$resolved_work_dir/skia/out/moonbit-smoke"
  source_build_args=(--work-dir "$resolved_work_dir" --skia-rev "$skia_rev")
  if [[ -n "$extra_gn_args" ]]; then
    source_build_args+=(--extra-gn-args "$extra_gn_args")
  fi
  if [[ $sync_deps -eq 0 ]]; then
    source_build_args+=(--no-sync-deps)
  fi
  if [[ $fetch_repo -eq 0 ]]; then
    source_build_args+=(--no-fetch)
  fi
else
  if [[ -n "$skia_include" || -n "$skia_lib_dir" ]]; then
    echo "--skia-provider jetbrains cannot be combined with --skia-include/--skia-lib-dir" >&2
    exit 2
  fi
  fetch_args=(
    --platform macos
    --arch auto
    --config "$jetbrains_config"
    --tag "$jetbrains_tag"
    --cache-dir "$resolved_jetbrains_cache_dir"
    --print-env
  )
  if [[ $dry_run_config -eq 1 ]]; then
    fetch_args+=(--dry-run-config)
  fi
  fetch_output="$(bash "$skia_repo/scripts/fetch-jetbrains-skia.sh" "${fetch_args[@]}")"
  smoke_mode="JetBrains Skia binary"
  include_path="$(get_assignment_value "$fetch_output" SKIA_MBT_SKIA_INCLUDE)"
  lib_path="$(get_assignment_value "$fetch_output" SKIA_MBT_SKIA_LIB_DIR)"
  skia_lib="$(get_assignment_value "$fetch_output" SKIA_MBT_SKIA_LIB)"
  jetbrains_tag="$(get_assignment_value "$fetch_output" SKIA_MBT_JETBRAINS_TAG)"
  jetbrains_commit="$(get_assignment_value "$fetch_output" SKIA_MBT_SKIA_COMMIT)"
  jetbrains_package="$(get_assignment_value "$fetch_output" SKIA_MBT_SKIA_PACKAGE)"
  jetbrains_package_sha256="$(get_assignment_value "$fetch_output" SKIA_MBT_SKIA_PACKAGE_SHA256)"
  if [[ $extra_cc_flags_explicit -eq 0 ]]; then
    extra_cc_flags="$(get_assignment_value "$fetch_output" SKIA_MBT_EXTRA_CC_FLAGS)"
  fi
  if [[ $extra_link_flags_explicit -eq 0 ]]; then
    extra_link_flags="$(get_assignment_value "$fetch_output" SKIA_MBT_EXTRA_LINK_FLAGS)"
  fi
fi

if [[ -z "$include_path" || -z "$lib_path" || -z "$skia_lib" ]]; then
  echo "Skia provider did not resolve a complete include/library configuration." >&2
  exit 1
fi

if [[ $dry_run_config -eq 0 ]]; then
  if [[ "$skia_provider" == "source" ]]; then
    if [[ -n "$build_log" ]]; then
      mkdir -p "$(dirname "$build_log")"
      : > "$build_log"
      set +e
      set -o pipefail
      bash "$skia_repo/scripts/macos-build-skia.sh" "${source_build_args[@]}" 2>&1 | tee "$build_log"
      build_status=${PIPESTATUS[0]}
      set +o pipefail
      set -e
      if [[ $build_status -ne 0 ]]; then
        exit "$build_status"
      fi
    else
      bash "$skia_repo/scripts/macos-build-skia.sh" "${source_build_args[@]}"
    fi
  fi

  include_path="$(resolve_existing_dir "Skia include path" "$include_path")"
  lib_path="$(resolve_existing_dir "Skia library path" "$lib_path")"
  if [[ ! -f "$include_path/include/core/SkSurface.h" ]]; then
    echo "Skia include path does not look like a Skia checkout/root: $include_path" >&2
    exit 1
  fi

  if [[ ! -f "$lib_path/lib$skia_lib.a" && ! -f "$lib_path/lib$skia_lib.dylib" ]]; then
    echo "Skia library lib$skia_lib.a or lib$skia_lib.dylib was not found in $lib_path" >&2
    exit 1
  fi
fi

cc_flags="-DSKIA_MBT_HAS_SKIA -std=c++17 -I$include_path"
if [[ -n "$extra_cc_flags" ]]; then
  cc_flags="$cc_flags $extra_cc_flags"
fi

skia_link_flags="-L$lib_path -l$skia_lib -lc++ -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework ImageIO -framework ApplicationServices"
if [[ -n "$extra_link_flags" ]]; then
  skia_link_flags="$skia_link_flags $extra_link_flags"
fi
showcase_link_flags="-framework AppKit -framework QuartzCore -framework UniformTypeIdentifiers -lz $skia_link_flags"

echo "MoUI macOS Skia renderer smoke environment:"
echo "  moon=$(moon version 2>/dev/null | head -n 1 || true)"
echo "  cxx=$(${CXX:-c++} --version 2>/dev/null | head -n 1 || true)"
echo "  skia_provider=$skia_provider"
echo "  skia_mode=$smoke_mode"
if [[ "$skia_provider" == "jetbrains" ]]; then
  echo "  jetbrains_tag=$jetbrains_tag"
  echo "  skia_commit=$jetbrains_commit"
  echo "  skia_package=$jetbrains_package"
  echo "  skia_package_sha256=$jetbrains_package_sha256"
elif [[ "$skia_provider" == "source" ]]; then
  echo "  work_dir=$resolved_work_dir"
  echo "  skia_rev=$skia_rev"
  echo "  sync_deps=$sync_deps"
  echo "  fetch_repo=$fetch_repo"
  if [[ -n "$extra_gn_args" ]]; then
    echo "  extra_gn_args=$extra_gn_args"
  fi
  if [[ -n "$build_log" ]]; then
    echo "  build_log=$build_log"
  fi
else
  if [[ -n "$extra_gn_args" ]]; then
    echo "  note: extra_gn_args is ignored unless --skia-provider source is selected"
  fi
fi
echo "  skia_include=$include_path"
echo "  skia_lib_dir=$lib_path"
echo "  skia_lib=$skia_lib"
echo "  skia_stub_cc_flags=$cc_flags"
echo "  skia_link_flags=$skia_link_flags"
echo "  showcase_link_flags=$showcase_link_flags"
if [[ -n "$smoke_log" ]]; then
  echo "  smoke_log=$smoke_log"
fi
if [[ -n "$showcase_log" ]]; then
  echo "  showcase_log=$showcase_log"
fi
echo "  skip_showcase_build=$skip_showcase_build"
echo "  run_showcase_smoke=$run_showcase_smoke"
if [[ $run_showcase_smoke -eq 1 ]]; then
  echo "  showcase_timeout=$showcase_timeout"
fi

if [[ $dry_run_config -eq 1 ]]; then
  if [[ "$skia_provider" == "source" ]]; then
    bash "$skia_repo/scripts/macos-build-skia.sh" --dry-run-config "${source_build_args[@]}"
  fi
  echo "Dry run complete; package files were not modified and no build was run."
  exit 0
fi

restore_packages() {
  if [[ $smoke_log_is_temporary -eq 1 && -n "${smoke_log:-}" && -f "$smoke_log" ]]; then
    rm -f "$smoke_log"
  fi
  if [[ $showcase_log_is_temporary -eq 1 && -n "${showcase_log:-}" && -f "$showcase_log" ]]; then
    rm -f "$showcase_log"
  fi
  if [[ -f "$native_pkg_backup" ]]; then
    cp "$native_pkg_backup" "$native_pkg"
    rm -f "$native_pkg_backup"
    echo "Restored skia_mbt/native/moon.pkg after MoUI Skia renderer smoke."
  fi
  if [[ -f "$renderer_pkg_backup" ]]; then
    cp "$renderer_pkg_backup" "$renderer_pkg"
    rm -f "$renderer_pkg_backup"
    echo "Restored moui/tests/skia_renderer_smoke/native/moon.pkg after MoUI Skia renderer smoke."
  fi
  if [[ -f "$showcase_pkg_backup" ]]; then
    cp "$showcase_pkg_backup" "$showcase_pkg"
    rm -f "$showcase_pkg_backup"
    echo "Restored examples/showcase/macos_skia/moon.pkg after MoUI Skia renderer smoke."
  fi
}
trap restore_packages EXIT

cp "$native_pkg" "$native_pkg_backup"
cp "$renderer_pkg" "$renderer_pkg_backup"
cp "$showcase_pkg" "$showcase_pkg_backup"

bash "$skia_repo/scripts/configure-macos-native-pkg.sh" \
  --skia-include "$include_path" \
  --skia-lib-dir "$lib_path" \
  --skia-lib "$skia_lib" \
  --extra-cc-flags "$extra_cc_flags" \
  --extra-link-flags "$extra_link_flags" \
  --output "$native_pkg" \
  --write >/dev/null
echo "Wrote temporary skia_mbt/native/moon.pkg with macOS Skia link flags."

cat > "$renderer_pkg" <<EOF
import {
  "wzzc-dev/moui/core",
  "wzzc-dev/moui/render",
  "wzzc-dev/moui/render/skia" @skia_renderer,
}

supported_targets = "native"

options(
  "is-main": true,
  link: {
    "native": {
      "cc-link-flags": "$skia_link_flags",
    },
  },
  targets: { "main.mbt": [ "native" ] },
)
EOF
echo "Wrote temporary MoUI renderer smoke package link flags."

cat > "$showcase_pkg" <<EOF
import {
  "moonbitlang/core/env",
  "wzzc-dev/moui/backend/macos" @macos_backend,
  "wzzc-dev/moui/render",
  "examples/showcase/app",
}

supported_targets = "native"

options(
  "is-main": true,
  link: {
    "native": {
      "cc-link-flags": "$showcase_link_flags",
    },
  },
  targets: { "main.mbt": [ "native" ] },
)
EOF
echo "Wrote temporary macos_skia showcase package link flags."

cd "$repo_root"
moon build moui/tests/skia_renderer_smoke/native --target native
renderer_exe="$repo_root/_build/native/debug/build/wzzc-dev/moui/tests/skia_renderer_smoke/native/native.exe"
if [[ ! -x "$renderer_exe" ]]; then
  echo "MoUI Skia renderer smoke executable was not produced at $renderer_exe" >&2
  exit 1
fi

export DYLD_LIBRARY_PATH="$lib_path${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
echo "Running MoUI Skia renderer smoke executable: $renderer_exe"
if [[ -z "$smoke_log" ]]; then
  smoke_log="$(mktemp "${TMPDIR:-/tmp}/moui-skia-renderer-smoke.XXXXXX.log")"
  smoke_log_is_temporary=1
else
  mkdir -p "$(dirname "$smoke_log")"
  : > "$smoke_log"
fi

set +e
set -o pipefail
"$renderer_exe" 2>&1 | tee "$smoke_log"
renderer_status=${PIPESTATUS[0]}
set +o pipefail
set -e
if [[ $renderer_status -ne 0 ]]; then
  exit "$renderer_status"
fi
if ! grep -Fq "MoUI Skia renderer smoke passed" "$smoke_log"; then
  echo "MoUI Skia renderer smoke did not print the expected success marker" >&2
  exit 1
fi
echo "Verified MoUI Skia renderer smoke success marker."

if [[ $skip_showcase_build -eq 0 ]]; then
  moon build examples/showcase/macos_skia --target native
  showcase_exe="$repo_root/_build/native/debug/build/examples/showcase/macos_skia/macos_skia.exe"
  if [[ -x "$showcase_exe" ]]; then
    echo "Built macos_skia showcase executable: $showcase_exe"
  else
    echo "macos_skia showcase executable was not produced at $showcase_exe" >&2
    exit 1
  fi

  if [[ $run_showcase_smoke -eq 1 ]]; then
    echo "Running macos_skia first-frame smoke executable: $showcase_exe"
    if [[ -z "$showcase_log" ]]; then
      showcase_log="$(mktemp "${TMPDIR:-/tmp}/moui-macos-skia-showcase-smoke.XXXXXX.log")"
      showcase_log_is_temporary=1
    else
      mkdir -p "$(dirname "$showcase_log")"
      : > "$showcase_log"
    fi

    set +e
    MOUI_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT=1 "$showcase_exe" >"$showcase_log" 2>&1 &
    showcase_pid=$!
    (
      sleep "$showcase_timeout"
      if kill -0 "$showcase_pid" 2>/dev/null; then
        echo "macos_skia Showcase smoke timed out after ${showcase_timeout}s" >>"$showcase_log"
        kill "$showcase_pid" 2>/dev/null
      fi
    ) &
    watchdog_pid=$!
    wait "$showcase_pid"
    showcase_status=$?
    kill "$watchdog_pid" 2>/dev/null
    wait "$watchdog_pid" 2>/dev/null
    cat "$showcase_log"
    set -e
    if [[ $showcase_status -ne 0 ]]; then
      exit "$showcase_status"
    fi
    if ! grep -Fq "macOS renderer presented first frame; exiting by request" "$showcase_log"; then
      echo "macos_skia Showcase smoke did not print the expected first-frame marker" >&2
      exit 1
    fi
    echo "Verified macos_skia Showcase first-frame smoke marker."
  fi
fi

echo "MoUI macOS Skia renderer smoke passed."
