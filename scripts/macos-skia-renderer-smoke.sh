#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/macos-skia-renderer-smoke.sh [options]

Temporarily configures the local moui_skia native package plus MoUI's Skia
renderer smoke, examples/showcase/macos_skia, and
examples/markdown_editor/macos_skia entrypoints, plus the Mo Workbench macOS
Skia entrypoint for local direct runs. It runs the renderer pixel smoke, builds
examples/showcase/macos_skia, optionally runs Showcase and Markdown Editor
first-frame smokes, then restores all package files.
Use --write-local-config when you want to keep the resolved local link flags so
direct moon run/build commands can use the native Skia packages afterwards.

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
  --link-mode auto|dynamic|static
                         Select Skia library link mode. Default: auto.
                         auto uses dynamic for --write-local-config, and
                         static for temporary smoke/build
                         setup when libskia.a exists.
  --skia-rev REV         Skia git revision, branch, or tag for source provider.
                         Default: moui_skia/skia-revision.txt.
  --jetbrains-tag TAG    JetBrains/skia release tag. Default: m148-8967a2e80c.
  --jetbrains-config Release|Debug
                         JetBrains/skia package configuration. Default: Release.
  --jetbrains-cache-dir PATH
                         JetBrains/skia cache root. Default: .skia-cache/jetbrains.
  --extra-gn-args STR    Extra GN args appended to the source-built Skia build.
  --enable-skshaper      Enable the optional moui_skia SkShaper boundary.
                         Requires libskshaper and its dependent module
                         libraries in --skia-lib-dir.
  --enable-skparagraph   Enable the optional moui_skia SkParagraph boundary.
                         Requires libskparagraph, libskshaper, and SkUnicode
                         libraries in --skia-lib-dir.
  --require-skparagraph  Enable SkParagraph and fail when required headers or
                         libraries are missing.
  --extra-cc-flags STR   Extra C/C++ flags appended to moui_skia stub flags.
  --extra-link-flags STR Extra linker flags appended to executable link flags.
  --build-log PATH       Write source-built Skia build output to PATH. Relative
                         paths are resolved from the repository root.
  --smoke-log PATH       Write MoUI renderer smoke output to PATH. Relative
                         paths are resolved from the repository root.
  --text-emoji-log PATH  Write MoUI Skia text/emoji proof smoke output to
                         PATH. Relative paths are resolved from the repository
                         root. Used with --run-text-emoji-smoke.
  --showcase-log PATH    Write macos_skia Showcase smoke output to PATH.
                         Relative paths are resolved from the repository root.
  --markdown-log PATH    Write markdown_editor/macos_skia smoke output to PATH.
                         Relative paths are resolved from the repository root.
  --record-platform-evidence PATH
                         After a successful renderer, Showcase, and Markdown
                         smoke, update the macOS skiaEvidence block in the
                         platform runtime evidence manifest at PATH. Requires
                         --smoke-log, --showcase-log, and --markdown-log under
                         artifacts/platform-evidence/macos/.
  --no-sync-deps         Skip python3 tools/git-sync-deps for source provider.
  --no-fetch             Reuse an existing Skia checkout for source provider.
  --skip-showcase-build  Only run the renderer pixel smoke.
  --run-showcase-smoke   After building macos_skia, run it with a first-frame
                         exit flag and verify the renderer-present marker.
  --run-text-emoji-smoke After the renderer smoke, build and run
                         moui/tests/skia_text_emoji_smoke/native with the same
                         real-Skia link flags and verify the text/emoji proof
                         success marker.
  --run-markdown-smoke   Build and run markdown_editor/macos_skia with a
                         first-frame exit flag and verify the marker.
  --run-gpu-smoke        Also run the opt-in macOS Metal/Ganesh Skia GPU route
                         smoke. This adds MOUI_SKIA_ENABLE_GPU_METAL and the
                         Metal-related frameworks for the temporary build,
                         and selects MOUI_MACOS_SKIA_SURFACE_ROUTE=metal-gpu
                         for Showcase/Markdown first-frame runs.
  --showcase-timeout SECONDS
                         Seconds to wait for --run-showcase-smoke. Default: 20.
  --markdown-timeout SECONDS
                         Seconds to wait for --run-markdown-smoke. Default: 20.
  --dry-run-config       Print resolved paths and flags, then exit without
                         rewriting package files or building executables.
  --write-local-config   Persistently write resolved link flags into the local
                         moui_skia native, renderer smoke, Showcase macos_skia,
                         Markdown Editor macos_skia, and Mo Workbench
                         macos_skia package files, then exit. Leaves
                         machine-local moon.pkg edits; do not commit those
                         path-specific package files.
  -h, --help             Show this help.

Environment defaults:
  MOUI_SKIA_SKIA_PROVIDER, MOUI_SKIA_PROVIDER, MOUI_SKIA_SKIA_INCLUDE,
  MOUI_SKIA_SKIA_LIB_DIR, MOUI_SKIA_SKIA_LIB, MOUI_SKIA_SKIA_REV,
  MOUI_SKIA_JETBRAINS_TAG, MOUI_SKIA_JETBRAINS_CONFIG,
  MOUI_SKIA_JETBRAINS_CACHE_DIR, MOUI_SKIA_EXTRA_GN_ARGS,
  MOUI_SKIA_LINK_MODE, MOUI_SKIA_ENABLE_SKPARAGRAPH,
  MOUI_SKIA_REQUIRE_SKPARAGRAPH, MOUI_SKIA_EXTRA_CC_FLAGS, and
  MOUI_SKIA_EXTRA_LINK_FLAGS are used when the matching command-line option is
  omitted. Explicit command-line options still override environment defaults.
EOF
}

normalize_bool() {
  local name="$1"
  local value="$2"
  case "$value" in
    1|true|TRUE|yes|YES|on|ON) printf '1\n' ;;
    ""|0|false|FALSE|no|NO|off|OFF) printf '0\n' ;;
    *)
      echo "unsupported boolean value for $name: $value" >&2
      exit 2
      ;;
  esac
}

reject_legacy_link_mode_env() {
  if [[ -n "${MOUI_SKIA_SKIA_LINK_MODE+x}" || -n "${MOUI_SKIA_MACOS_LINK_MODE+x}" ]]; then
    echo "MOUI_SKIA_SKIA_LINK_MODE and MOUI_SKIA_MACOS_LINK_MODE are no longer supported; use MOUI_SKIA_LINK_MODE=dynamic|static|auto." >&2
    exit 2
  fi
}

reject_legacy_link_mode_env

work_dir=".skia-cache/macos"
skia_include="${MOUI_SKIA_SKIA_INCLUDE:-}"
skia_lib_dir="${MOUI_SKIA_SKIA_LIB_DIR:-}"
skia_lib="${MOUI_SKIA_SKIA_LIB:-skia}"
macos_link_mode="${MOUI_SKIA_LINK_MODE:-auto}"
skia_provider="${MOUI_SKIA_SKIA_PROVIDER:-${MOUI_SKIA_PROVIDER:-}}"
skia_provider_explicit=0
if [[ -n "${MOUI_SKIA_SKIA_PROVIDER:-}${MOUI_SKIA_PROVIDER:-}" ]]; then
  skia_provider_explicit=1
fi
skia_rev="${MOUI_SKIA_SKIA_REV:-main}"
skia_rev_explicit=0
if [[ -n "${MOUI_SKIA_SKIA_REV:-}" ]]; then
  skia_rev_explicit=1
fi
jetbrains_tag="${MOUI_SKIA_JETBRAINS_TAG:-m148-8967a2e80c}"
jetbrains_config="${MOUI_SKIA_JETBRAINS_CONFIG:-Release}"
jetbrains_cache_dir="${MOUI_SKIA_JETBRAINS_CACHE_DIR:-.skia-cache/jetbrains}"
extra_gn_args="${MOUI_SKIA_EXTRA_GN_ARGS:-}"
extra_cc_flags="${MOUI_SKIA_EXTRA_CC_FLAGS:-}"
extra_link_flags="${MOUI_SKIA_EXTRA_LINK_FLAGS:-}"
enable_skshaper=0
enable_skparagraph="${MOUI_SKIA_ENABLE_SKPARAGRAPH:-0}"
require_skparagraph="${MOUI_SKIA_REQUIRE_SKPARAGRAPH:-0}"
extra_cc_flags_explicit=0
extra_link_flags_explicit=0
if [[ -n "${MOUI_SKIA_EXTRA_CC_FLAGS:-}" ]]; then
  extra_cc_flags_explicit=1
fi
if [[ -n "${MOUI_SKIA_EXTRA_LINK_FLAGS:-}" ]]; then
  extra_link_flags_explicit=1
fi
requested_build_log=""
requested_smoke_log=""
requested_text_emoji_log=""
requested_showcase_log=""
requested_markdown_log=""
requested_platform_evidence_manifest=""
sync_deps=1
fetch_repo=1
skip_showcase_build=0
run_showcase_smoke=0
run_text_emoji_smoke=0
run_markdown_smoke=0
run_gpu_smoke=0
showcase_timeout=20
markdown_timeout=20
dry_run_config=0
write_local_config=0

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
    --link-mode)
      macos_link_mode="${2:-}"
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
    --enable-skshaper)
      enable_skshaper=1
      shift
      ;;
    --enable-skparagraph)
      enable_skparagraph=1
      shift
      ;;
    --require-skparagraph)
      require_skparagraph=1
      shift
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
    --text-emoji-log)
      requested_text_emoji_log="${2:-}"
      shift 2
      ;;
    --showcase-log)
      requested_showcase_log="${2:-}"
      shift 2
      ;;
    --markdown-log)
      requested_markdown_log="${2:-}"
      shift 2
      ;;
    --record-platform-evidence)
      requested_platform_evidence_manifest="${2:-}"
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
    --run-text-emoji-smoke)
      run_text_emoji_smoke=1
      shift
      ;;
    --run-markdown-smoke)
      run_markdown_smoke=1
      shift
      ;;
    --run-gpu-smoke)
      run_gpu_smoke=1
      shift
      ;;
    --showcase-timeout)
      showcase_timeout="${2:-}"
      shift 2
      ;;
    --markdown-timeout)
      markdown_timeout="${2:-}"
      shift 2
      ;;
    --dry-run-config)
      dry_run_config=1
      shift
      ;;
    --write-local-config)
      write_local_config=1
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

enable_skparagraph="$(normalize_bool MOUI_SKIA_ENABLE_SKPARAGRAPH "$enable_skparagraph")"
require_skparagraph="$(normalize_bool MOUI_SKIA_REQUIRE_SKPARAGRAPH "$require_skparagraph")"
if [[ $require_skparagraph -eq 1 ]]; then
  enable_skparagraph=1
fi
if [[ $run_text_emoji_smoke -eq 1 && $enable_skparagraph -eq 0 ]]; then
  echo "--run-text-emoji-smoke requires --enable-skparagraph or --require-skparagraph." >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skia_repo="$repo_root/moui_skia"
native_pkg="$skia_repo/native/moon.pkg"
native_pkg_backup="$native_pkg.moui-smoke.bak"
renderer_pkg="$repo_root/moui/tests/skia_renderer_smoke/native/moon.pkg"
renderer_pkg_backup="$renderer_pkg.moui-smoke.bak"
text_emoji_pkg="$repo_root/moui/tests/skia_text_emoji_smoke/native/moon.pkg"
text_emoji_pkg_backup="$text_emoji_pkg.moui-smoke.bak"
showcase_pkg="$repo_root/examples/showcase/macos_skia/moon.pkg"
showcase_pkg_backup="$showcase_pkg.moui-smoke.bak"
markdown_pkg="$repo_root/examples/markdown_editor/macos_skia/moon.pkg"
markdown_pkg_backup="$markdown_pkg.moui-smoke.bak"
workbench_pkg="$repo_root/examples/mo_workbench/macos_skia/moon.pkg"
workbench_pkg_backup="$workbench_pkg.moui-smoke.bak"
build_log=""
smoke_log=""
text_emoji_log=""
showcase_log=""
markdown_log=""
platform_evidence_manifest=""
smoke_log_is_temporary=0
text_emoji_log_is_temporary=0
showcase_log_is_temporary=0
markdown_log_is_temporary=0

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

relative_to_repo() {
  local path="$1"
  case "$path" in
    "$repo_root"/*) printf '%s\n' "${path#"$repo_root"/}" ;;
    *)
      echo "path is outside repository root: $path" >&2
      exit 2
      ;;
  esac
}

get_assignment_value() {
  local input="$1"
  local key="$2"
  printf '%s\n' "$input" | sed -n "s/^${key}=//p" | tail -n 1
}

check_package_backups() {
  for backup in "$native_pkg_backup" "$renderer_pkg_backup" "$text_emoji_pkg_backup" "$showcase_pkg_backup" "$markdown_pkg_backup" "$workbench_pkg_backup"; do
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

if [[ -n "$requested_text_emoji_log" ]]; then
  text_emoji_log="$(resolve_path "$requested_text_emoji_log")"
fi

if [[ -n "$requested_showcase_log" ]]; then
  showcase_log="$(resolve_path "$requested_showcase_log")"
fi

if [[ -n "$requested_markdown_log" ]]; then
  markdown_log="$(resolve_path "$requested_markdown_log")"
fi

if [[ -n "$requested_platform_evidence_manifest" ]]; then
  platform_evidence_manifest="$(resolve_path "$requested_platform_evidence_manifest")"
fi

ensure_platform_evidence_log_path() {
  local label="$1"
  local path="$2"
  if [[ -z "$path" ]]; then
    echo "--record-platform-evidence requires --${label}-log" >&2
    exit 2
  fi
  case "$path" in
    "$repo_root"/artifacts/platform-evidence/macos/*) ;;
    *)
      echo "--record-platform-evidence requires --${label}-log under artifacts/platform-evidence/macos/: $path" >&2
      exit 2
      ;;
  esac
}

if [[ -n "$platform_evidence_manifest" ]]; then
  if [[ $run_showcase_smoke -ne 1 || $run_markdown_smoke -ne 1 ]]; then
    echo "--record-platform-evidence requires --run-showcase-smoke and --run-markdown-smoke" >&2
    exit 2
  fi
  ensure_platform_evidence_log_path "smoke" "$smoke_log"
  ensure_platform_evidence_log_path "showcase" "$showcase_log"
  ensure_platform_evidence_log_path "markdown" "$markdown_log"
fi

if [[ $run_showcase_smoke -eq 1 && $skip_showcase_build -eq 1 ]]; then
  echo "--run-showcase-smoke cannot be combined with --skip-showcase-build" >&2
  exit 2
fi

if [[ $dry_run_config -eq 1 && $write_local_config -eq 1 ]]; then
  echo "--dry-run-config and --write-local-config cannot be combined" >&2
  exit 2
fi
case "$macos_link_mode" in
  auto|dynamic|static) ;;
  *) echo "unsupported --link-mode: $macos_link_mode" >&2; exit 2 ;;
esac

if [[ $run_showcase_smoke -eq 1 && $write_local_config -eq 1 ]]; then
  echo "--write-local-config writes package files and exits; run the showcase smoke afterwards" >&2
  exit 2
fi

if [[ $run_markdown_smoke -eq 1 && $write_local_config -eq 1 ]]; then
  echo "--write-local-config writes package files and exits; run the Markdown Editor smoke afterwards" >&2
  exit 2
fi

if [[ $run_gpu_smoke -eq 1 && $write_local_config -eq 1 ]]; then
  echo "--write-local-config writes package files and exits; run the GPU smoke afterwards" >&2
  exit 2
fi

if ! [[ "$showcase_timeout" =~ ^[0-9]+$ ]] || [[ "$showcase_timeout" -lt 1 ]]; then
  echo "--showcase-timeout must be a positive integer number of seconds" >&2
  exit 2
fi

if ! [[ "$markdown_timeout" =~ ^[0-9]+$ ]] || [[ "$markdown_timeout" -lt 1 ]]; then
  echo "--markdown-timeout must be a positive integer number of seconds" >&2
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
  if [[ $enable_skparagraph -eq 1 ]]; then
    source_build_args+=(--enable-skparagraph)
  fi
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
  fetch_link_mode="$macos_link_mode"
  if [[ "$fetch_link_mode" == "auto" ]]; then
    if [[ $write_local_config -eq 1 ]]; then
      fetch_link_mode="dynamic"
    else
      fetch_link_mode="static"
    fi
  fi
  fetch_args=(
    --platform macos
    --arch auto
    --config "$jetbrains_config"
    --link-mode "$fetch_link_mode"
    --tag "$jetbrains_tag"
    --cache-dir "$resolved_jetbrains_cache_dir"
    --print-env
  )
  if [[ $dry_run_config -eq 1 ]]; then
    fetch_args+=(--dry-run-config)
  fi
  fetch_output="$(bash "$skia_repo/scripts/fetch-jetbrains-skia.sh" "${fetch_args[@]}")"
  smoke_mode="JetBrains Skia binary"
  include_path="$(get_assignment_value "$fetch_output" MOUI_SKIA_SKIA_INCLUDE)"
  lib_path="$(get_assignment_value "$fetch_output" MOUI_SKIA_SKIA_LIB_DIR)"
  skia_lib="$(get_assignment_value "$fetch_output" MOUI_SKIA_SKIA_LIB)"
  jetbrains_tag="$(get_assignment_value "$fetch_output" MOUI_SKIA_JETBRAINS_TAG)"
  jetbrains_commit="$(get_assignment_value "$fetch_output" MOUI_SKIA_SKIA_COMMIT)"
  jetbrains_package="$(get_assignment_value "$fetch_output" MOUI_SKIA_SKIA_PACKAGE)"
  jetbrains_package_sha256="$(get_assignment_value "$fetch_output" MOUI_SKIA_SKIA_PACKAGE_SHA256)"
  if [[ $extra_cc_flags_explicit -eq 0 ]]; then
    extra_cc_flags="$(get_assignment_value "$fetch_output" MOUI_SKIA_EXTRA_CC_FLAGS)"
  fi
  if [[ $extra_link_flags_explicit -eq 0 ]]; then
    extra_link_flags="$(get_assignment_value "$fetch_output" MOUI_SKIA_EXTRA_LINK_FLAGS)"
  fi
fi

if [[ -z "$include_path" || -z "$lib_path" || -z "$skia_lib" ]]; then
  echo "Skia provider did not resolve a complete include/library configuration." >&2
  exit 1
fi

static_lib="$lib_path/lib$skia_lib.a"
dynamic_lib="$lib_path/lib$skia_lib.dylib"
ganesh_ext_static_lib="$lib_path/libskia_ganesh_ext.a"

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
  static_lib="$lib_path/lib$skia_lib.a"
  dynamic_lib="$lib_path/lib$skia_lib.dylib"
  ganesh_ext_static_lib="$lib_path/libskia_ganesh_ext.a"
  if [[ ! -f "$include_path/include/core/SkSurface.h" ]]; then
    echo "Skia include path does not look like a Skia checkout/root: $include_path" >&2
    exit 1
  fi

  if [[ ! -f "$static_lib" && ! -f "$dynamic_lib" ]]; then
    echo "Skia library lib$skia_lib.a or lib$skia_lib.dylib was not found in $lib_path" >&2
    exit 1
  fi
  if [[ $enable_skshaper -eq 1 ]]; then
    if [[ ! -f "$include_path/modules/skshaper/include/SkShaper.h" ]]; then
      echo "SkShaper header was not found under $include_path/modules/skshaper/include" >&2
      exit 1
    fi
    for shaper_lib in skshaper skunicode_core skunicode_icu harfbuzz icu; do
      if [[ ! -f "$lib_path/lib$shaper_lib.a" && ! -f "$lib_path/lib$shaper_lib.dylib" ]]; then
        echo "SkShaper dependency lib$shaper_lib.a or lib$shaper_lib.dylib was not found in $lib_path" >&2
        exit 1
      fi
    done
  fi
fi

paragraph_headers=(
  "$include_path/modules/skparagraph/include/Paragraph.h"
  "$include_path/modules/skparagraph/include/ParagraphBuilder.h"
  "$include_path/modules/skparagraph/include/ParagraphStyle.h"
  "$include_path/modules/skparagraph/include/TextStyle.h"
  "$include_path/modules/skparagraph/include/FontCollection.h"
)
paragraph_libs=(skparagraph skshaper skunicode_core skunicode_icu harfbuzz icu)
paragraph_headers_status="unchecked"
paragraph_libraries_status="unchecked"
if [[ $enable_skparagraph -eq 1 ]]; then
  paragraph_headers_status="available"
  for paragraph_header in "${paragraph_headers[@]}"; do
    if [[ ! -f "$paragraph_header" ]]; then
      paragraph_headers_status="missing"
    fi
  done
  paragraph_libraries_status="available"
  for paragraph_lib in "${paragraph_libs[@]}"; do
    if [[ ! -f "$lib_path/lib$paragraph_lib.a" && ! -f "$lib_path/lib$paragraph_lib.dylib" ]]; then
      paragraph_libraries_status="missing"
    fi
  done
  if [[ $require_skparagraph -eq 1 && "$paragraph_headers_status" != "available" ]]; then
    echo "MOUI_SKIA_REQUIRE_SKPARAGRAPH requested, but one or more SkParagraph headers are missing under $include_path/modules/skparagraph/include" >&2
    exit 1
  fi
  if [[ $require_skparagraph -eq 1 && "$paragraph_libraries_status" != "available" ]]; then
    echo "MOUI_SKIA_REQUIRE_SKPARAGRAPH requested, but one or more SkParagraph libraries are missing in $lib_path" >&2
    exit 1
  fi
fi

resolved_link_mode="$macos_link_mode"
if [[ "$resolved_link_mode" == "auto" ]]; then
  if [[ $write_local_config -eq 1 ]]; then
    if [[ -f "$dynamic_lib" || $dry_run_config -eq 1 ]]; then
      resolved_link_mode="dynamic"
    else
      resolved_link_mode="static"
    fi
  else
    if [[ -f "$static_lib" || $dry_run_config -eq 1 ]]; then
      resolved_link_mode="static"
    else
      resolved_link_mode="dynamic"
    fi
  fi
fi

case "$resolved_link_mode" in
  dynamic)
    if [[ $dry_run_config -eq 0 && ! -f "$dynamic_lib" ]]; then
      echo "Requested dynamic Skia link mode, but $dynamic_lib was not found" >&2
      exit 1
    fi
    skia_library_link_flag="$dynamic_lib"
    skia_runtime_link_flags="-Wl,-rpath,$lib_path"
    ;;
  static)
    if [[ $dry_run_config -eq 0 && ! -f "$static_lib" ]]; then
      echo "Requested static Skia link mode, but $static_lib was not found" >&2
      exit 1
    fi
    skia_library_link_flag="$static_lib"
    skia_runtime_link_flags=""
    ;;
esac

ganesh_link_flags=""
if [[ $run_gpu_smoke -eq 1 && "$resolved_link_mode" == "static" ]]; then
  if [[ $dry_run_config -eq 0 && ! -f "$ganesh_ext_static_lib" ]]; then
    echo "Requested Metal GPU Skia smoke, but $ganesh_ext_static_lib was not found" >&2
    exit 1
  fi
  ganesh_link_flags="$ganesh_ext_static_lib"
fi

native_extra_cc_flags="$extra_cc_flags"
native_extra_link_flags="$extra_link_flags"
if [[ $enable_skshaper -eq 1 ]]; then
  native_extra_cc_flags="-DMOUI_SKIA_HAS_SKSHAPER${native_extra_cc_flags:+ $native_extra_cc_flags}"
  shaper_link_flags=""
  for shaper_lib in skshaper skunicode_core skunicode_icu harfbuzz icu; do
    shaper_static_lib="$lib_path/lib$shaper_lib.a"
    shaper_dynamic_lib="$lib_path/lib$shaper_lib.dylib"
    case "$resolved_link_mode" in
      dynamic)
        if [[ $dry_run_config -eq 0 && ! -f "$shaper_dynamic_lib" ]]; then
          echo "Requested dynamic SkShaper link mode, but $shaper_dynamic_lib was not found" >&2
          exit 1
        fi
        shaper_link_flags="$shaper_link_flags $shaper_dynamic_lib"
        ;;
      static)
        if [[ $dry_run_config -eq 0 && ! -f "$shaper_static_lib" ]]; then
          echo "Requested static SkShaper link mode, but $shaper_static_lib was not found" >&2
          exit 1
        fi
        shaper_link_flags="$shaper_link_flags $shaper_static_lib"
        ;;
    esac
  done
  native_extra_link_flags="${shaper_link_flags# }${native_extra_link_flags:+ $native_extra_link_flags}"
fi
paragraph_link_flags=""
if [[ $enable_skparagraph -eq 1 ]]; then
  for paragraph_lib in "${paragraph_libs[@]}"; do
    paragraph_static_lib="$lib_path/lib$paragraph_lib.a"
    paragraph_dynamic_lib="$lib_path/lib$paragraph_lib.dylib"
    case "$resolved_link_mode" in
      dynamic)
        if [[ $dry_run_config -eq 0 && ! -f "$paragraph_dynamic_lib" ]]; then
          echo "Requested dynamic SkParagraph link mode, but $paragraph_dynamic_lib was not found" >&2
          exit 1
        fi
        paragraph_link_flags="$paragraph_link_flags $paragraph_dynamic_lib"
        ;;
      static)
        if [[ $dry_run_config -eq 0 && ! -f "$paragraph_static_lib" ]]; then
          echo "Requested static SkParagraph link mode, but $paragraph_static_lib was not found" >&2
          exit 1
        fi
        paragraph_link_flags="$paragraph_link_flags $paragraph_static_lib"
        ;;
    esac
  done
fi
if [[ $run_gpu_smoke -eq 1 ]]; then
  native_extra_cc_flags="-DMOUI_SKIA_ENABLE_GPU_METAL${native_extra_cc_flags:+ $native_extra_cc_flags}"
  if [[ -n "$ganesh_link_flags" ]]; then
    native_extra_link_flags="$ganesh_link_flags $static_lib${native_extra_link_flags:+ $native_extra_link_flags}"
  fi
  native_extra_link_flags="-framework Metal -framework QuartzCore -framework CoreVideo -framework IOSurface -framework AppKit -lobjc${native_extra_link_flags:+ $native_extra_link_flags}"
fi

cc_flags="-DMOUI_SKIA_HAS_SKIA -std=c++17 -I$include_path"
if [[ $enable_skshaper -eq 1 ]]; then
  cc_flags="$cc_flags -DMOUI_SKIA_HAS_SKSHAPER"
fi
if [[ $enable_skparagraph -eq 1 ]]; then
  cc_flags="$cc_flags -DMOUI_SKIA_HAS_SKPARAGRAPH -DMOUI_SKIA_HAS_SKSHAPER"
fi
if [[ $run_gpu_smoke -eq 1 ]]; then
  cc_flags="$cc_flags -DMOUI_SKIA_ENABLE_GPU_METAL"
fi
if [[ -n "$extra_cc_flags" ]]; then
  cc_flags="$cc_flags $extra_cc_flags"
fi

skia_link_flags="$skia_library_link_flag -lc++ -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework ImageIO -framework ApplicationServices"
if [[ -n "$ganesh_link_flags" ]]; then
  skia_link_flags="$ganesh_link_flags $skia_link_flags"
fi
if [[ $run_gpu_smoke -eq 1 ]]; then
  skia_link_flags="$skia_link_flags -framework Metal -framework QuartzCore -framework CoreVideo -framework IOSurface -framework AppKit"
fi
if [[ $enable_skshaper -eq 1 ]]; then
  skia_link_flags="$skia_link_flags $shaper_link_flags"
fi
if [[ $enable_skparagraph -eq 1 ]]; then
  skia_link_flags="$skia_link_flags $paragraph_link_flags"
fi
if [[ -n "$skia_runtime_link_flags" ]]; then
  skia_link_flags="$skia_link_flags $skia_runtime_link_flags"
fi
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
echo "  requested_link_mode=$macos_link_mode"
echo "  resolved_link_mode=$resolved_link_mode"
if [[ $enable_skshaper -eq 1 ]]; then
  echo "  skshaper=enabled"
fi
if [[ $require_skparagraph -eq 1 ]]; then
  echo "  skparagraph=required"
elif [[ $enable_skparagraph -eq 1 ]]; then
  echo "  skparagraph=enabled"
else
  echo "  skparagraph=disabled"
fi
if [[ $enable_skparagraph -eq 1 ]]; then
  echo "  skparagraph_headers=$paragraph_headers_status"
  echo "  skparagraph_libraries=$paragraph_libraries_status"
fi
echo "  skia_stub_cc_flags=$cc_flags"
echo "  skia_link_flags=$skia_link_flags"
echo "  showcase_link_flags=$showcase_link_flags"
if [[ -n "$smoke_log" ]]; then
  echo "  smoke_log=$smoke_log"
fi
if [[ -n "$text_emoji_log" ]]; then
  echo "  text_emoji_log=$text_emoji_log"
fi
if [[ -n "$showcase_log" ]]; then
  echo "  showcase_log=$showcase_log"
fi
if [[ -n "$markdown_log" ]]; then
  echo "  markdown_log=$markdown_log"
fi
if [[ -n "$platform_evidence_manifest" ]]; then
  echo "  platform_evidence_manifest=$platform_evidence_manifest"
fi
echo "  skip_showcase_build=$skip_showcase_build"
echo "  run_showcase_smoke=$run_showcase_smoke"
echo "  run_text_emoji_smoke=$run_text_emoji_smoke"
echo "  run_markdown_smoke=$run_markdown_smoke"
echo "  run_gpu_smoke=$run_gpu_smoke"
echo "  write_local_config=$write_local_config"
if [[ $run_showcase_smoke -eq 1 ]]; then
  echo "  showcase_timeout=$showcase_timeout"
fi
if [[ $run_markdown_smoke -eq 1 ]]; then
  echo "  markdown_timeout=$markdown_timeout"
fi

if [[ $dry_run_config -eq 1 ]]; then
  if [[ "$skia_provider" == "source" ]]; then
    bash "$skia_repo/scripts/macos-build-skia.sh" --dry-run-config "${source_build_args[@]}"
  fi
  echo "Dry run complete; package files were not modified and no build was run."
  exit 0
fi

write_native_pkg_config() {
  configure_args=(
    --skia-include "$include_path" \
    --skia-lib-dir "$lib_path" \
    --skia-lib "$skia_lib" \
    --link-mode "$resolved_link_mode" \
    --extra-cc-flags "$native_extra_cc_flags" \
    --extra-link-flags "$native_extra_link_flags" \
    --output "$native_pkg" \
    --write
  )
  if [[ $enable_skparagraph -eq 1 ]]; then
    configure_args+=(--enable-skparagraph)
  fi
  if [[ $require_skparagraph -eq 1 ]]; then
    configure_args+=(--require-skparagraph)
  fi
  bash "$skia_repo/scripts/configure-macos-native-pkg.sh" "${configure_args[@]}" >/dev/null
}

write_renderer_smoke_pkg_config() {
  cat > "$renderer_pkg" <<EOF
import {
  "moonbitlang/core/encoding/base64",
  "moonbitlang/core/env",
  "moonbitlang/x/fs",
  "wzzc-dev/moui_skia/native" @skia_native,
  "wzzc-dev/moui/backend/host",
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
}

write_text_emoji_pkg_config() {
  cat > "$text_emoji_pkg" <<EOF
import {
  "wzzc-dev/moui_skia/native" @skia_native,
  "wzzc-dev/moui/backend/host",
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
}

write_showcase_pkg_config() {
  cat > "$showcase_pkg" <<EOF
import {
  "moonbitlang/core/env",
  "wzzc-dev/moui/backend/macos" @macos_backend,
  "wzzc-dev/moui/backend/macos/skia" @macos_skia_backend,
  "wzzc-dev/moui/render/skia" @skia_renderer,
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
}

write_markdown_pkg_config() {
  cat > "$markdown_pkg" <<EOF
import {
  "moonbitlang/core/env",
  "wzzc-dev/moui/backend/host",
  "wzzc-dev/moui/backend/macos" @macos_host,
  "wzzc-dev/moui/backend/macos/skia" @macos_skia_backend,
  "wzzc-dev/moui/render/skia" @skia_renderer,
  "examples/markdown_editor/app",
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
}

write_workbench_pkg_config() {
  cat > "$workbench_pkg" <<EOF
import {
  "moonbitlang/async",
  "moonbitlang/core/env",
  "wzzc-dev/moui/backend/macos/skia" @macos_skia_backend,
  "wzzc-dev/moui/render/skia" @skia_renderer,
  "examples/mo_workbench/app",
  "examples/mo_workbench/native_transport",
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
}

if [[ $write_local_config -eq 1 ]]; then
  write_native_pkg_config
  echo "Wrote local moui_skia/native/moon.pkg with macOS Skia link flags."
  write_renderer_smoke_pkg_config
  echo "Wrote local MoUI renderer smoke package link flags."
  write_text_emoji_pkg_config
  echo "Wrote local MoUI text/emoji smoke package link flags."
  write_showcase_pkg_config
  echo "Wrote local macos_skia showcase package link flags."
  write_markdown_pkg_config
  echo "Wrote local markdown_editor/macos_skia package link flags."
  write_workbench_pkg_config
  echo "Wrote local mo_workbench/macos_skia package link flags."
  echo "Local macOS Skia configuration is ready. Direct run command:"
  echo "  moon run moui/tests/skia_text_emoji_smoke/native --target native"
  echo "  moon run examples/showcase/macos_skia --target native"
  echo "  moon run examples/markdown_editor/macos_skia --target native"
  echo "  moon run examples/mo_workbench/macos_skia --target native"
  echo "These package files contain machine-local paths; keep them out of commits."
  exit 0
fi

restore_packages() {
  if [[ $smoke_log_is_temporary -eq 1 && -n "${smoke_log:-}" && -f "$smoke_log" ]]; then
    rm -f "$smoke_log"
  fi
  if [[ $text_emoji_log_is_temporary -eq 1 && -n "${text_emoji_log:-}" && -f "$text_emoji_log" ]]; then
    rm -f "$text_emoji_log"
  fi
  if [[ $showcase_log_is_temporary -eq 1 && -n "${showcase_log:-}" && -f "$showcase_log" ]]; then
    rm -f "$showcase_log"
  fi
  if [[ $markdown_log_is_temporary -eq 1 && -n "${markdown_log:-}" && -f "$markdown_log" ]]; then
    rm -f "$markdown_log"
  fi
  if [[ -f "$native_pkg_backup" ]]; then
    cp "$native_pkg_backup" "$native_pkg"
    rm -f "$native_pkg_backup"
    echo "Restored moui_skia/native/moon.pkg after MoUI Skia renderer smoke."
  fi
  if [[ -f "$renderer_pkg_backup" ]]; then
    cp "$renderer_pkg_backup" "$renderer_pkg"
    rm -f "$renderer_pkg_backup"
    echo "Restored moui/tests/skia_renderer_smoke/native/moon.pkg after MoUI Skia renderer smoke."
  fi
  if [[ -f "$text_emoji_pkg_backup" ]]; then
    cp "$text_emoji_pkg_backup" "$text_emoji_pkg"
    rm -f "$text_emoji_pkg_backup"
    echo "Restored moui/tests/skia_text_emoji_smoke/native/moon.pkg after MoUI Skia renderer smoke."
  fi
  if [[ -f "$showcase_pkg_backup" ]]; then
    cp "$showcase_pkg_backup" "$showcase_pkg"
    rm -f "$showcase_pkg_backup"
    echo "Restored examples/showcase/macos_skia/moon.pkg after MoUI Skia renderer smoke."
  fi
  if [[ -f "$markdown_pkg_backup" ]]; then
    cp "$markdown_pkg_backup" "$markdown_pkg"
    rm -f "$markdown_pkg_backup"
    echo "Restored examples/markdown_editor/macos_skia/moon.pkg after MoUI Skia renderer smoke."
  fi
  if [[ -f "$workbench_pkg_backup" ]]; then
    cp "$workbench_pkg_backup" "$workbench_pkg"
    rm -f "$workbench_pkg_backup"
    echo "Restored examples/mo_workbench/macos_skia/moon.pkg after MoUI Skia renderer smoke."
  fi
}
trap restore_packages EXIT

cp "$native_pkg" "$native_pkg_backup"
cp "$renderer_pkg" "$renderer_pkg_backup"
cp "$text_emoji_pkg" "$text_emoji_pkg_backup"
cp "$showcase_pkg" "$showcase_pkg_backup"
cp "$markdown_pkg" "$markdown_pkg_backup"
cp "$workbench_pkg" "$workbench_pkg_backup"

write_native_pkg_config
echo "Wrote temporary moui_skia/native/moon.pkg with macOS Skia link flags."

write_renderer_smoke_pkg_config
echo "Wrote temporary MoUI renderer smoke package link flags."

write_text_emoji_pkg_config
echo "Wrote temporary MoUI text/emoji smoke package link flags."

write_showcase_pkg_config
echo "Wrote temporary macos_skia showcase package link flags."

write_markdown_pkg_config
echo "Wrote temporary markdown_editor/macos_skia package link flags."

write_workbench_pkg_config
echo "Wrote temporary mo_workbench/macos_skia package link flags."

cd "$repo_root"
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon build moui/tests/skia_renderer_smoke/native --target native
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
if [[ $run_gpu_smoke -eq 1 ]]; then
  MOUI_SKIA_RUN_GPU_METAL_SMOKE=1 "$renderer_exe" 2>&1 | tee "$smoke_log"
else
  "$renderer_exe" 2>&1 | tee "$smoke_log"
fi
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
if ! grep -Fq "MoUI Skia async image second-frame smoke passed" "$smoke_log"; then
  echo "MoUI Skia renderer smoke did not prove async image second-frame repaint" >&2
  exit 1
fi
echo "Verified MoUI Skia async image second-frame marker."
if [[ $run_gpu_smoke -eq 1 ]]; then
  if ! grep -Fq "MoUI Skia GPU Metal renderer smoke passed route=metal-gpu surface_gpu=true present_count=1 pixel-markers" "$smoke_log"; then
    echo "MoUI Skia renderer smoke did not prove the Metal GPU route" >&2
    exit 1
  fi
  echo "Verified MoUI Skia GPU Metal route marker."
fi
if [[ $enable_skshaper -eq 1 ]]; then
  if ! grep -Fq "MoUI Skia renderer smoke shaper available" "$smoke_log"; then
    echo "MoUI Skia renderer smoke did not prove the enabled SkShaper path" >&2
    exit 1
  fi
  echo "Verified MoUI Skia renderer SkShaper marker."
fi

if [[ $run_text_emoji_smoke -eq 1 ]]; then
  MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon build moui/tests/skia_text_emoji_smoke/native --target native
  text_emoji_exe="$repo_root/_build/native/debug/build/wzzc-dev/moui/tests/skia_text_emoji_smoke/native/native.exe"
  if [[ ! -x "$text_emoji_exe" ]]; then
    echo "MoUI Skia text/emoji smoke executable was not produced at $text_emoji_exe" >&2
    exit 1
  fi

  echo "Running MoUI Skia text/emoji smoke executable: $text_emoji_exe"
  if [[ -z "$text_emoji_log" ]]; then
    text_emoji_log="$(mktemp "${TMPDIR:-/tmp}/moui-skia-text-emoji-smoke.XXXXXX.log")"
    text_emoji_log_is_temporary=1
  else
    mkdir -p "$(dirname "$text_emoji_log")"
    : > "$text_emoji_log"
  fi

  set +e
  set -o pipefail
  "$text_emoji_exe" 2>&1 | tee "$text_emoji_log"
  text_emoji_status=${PIPESTATUS[0]}
  set +o pipefail
  set -e
  if [[ $text_emoji_status -ne 0 ]]; then
    exit "$text_emoji_status"
  fi
  if ! grep -Fq "MoUI Skia text/emoji smoke passed" "$text_emoji_log"; then
    echo "MoUI Skia text/emoji smoke did not print the expected success marker" >&2
    exit 1
  fi
  echo "Verified MoUI Skia text/emoji smoke success marker."

  text_emoji_required_markers=(
    "MoUI renderer proof colorEmojiPixels passed high-saturation-pixels glyph-or-raster font-metadata glyph-metadata fallback-request emoji-hint stable-glyph-key"
    "MoUI renderer proof zwjGrapheme passed single-grapheme-cluster no-interior-caret"
    "MoUI renderer proof paragraphWrapping passed engine=skparagraph native_paragraph_ready=true line-metrics later-line-pixels"
    "MoUI renderer proof bidiLayout passed engine=skparagraph bidi_visual_order_ready=true visual-order"
    "MoUI renderer proof selectionRects passed engine=skparagraph selection-rects line-range hit-test"
    "MoUI renderer proof graphemeEditing passed grapheme-boundaries edit-actions"
    "MoUI renderer proof imeCandidateAnchor passed candidate-anchor surrounding-text"
    "MoUI renderer proof imeCompositionVisual passed composition-range preedit-pixels"
  )
  for marker in "${text_emoji_required_markers[@]}"; do
    if ! grep -Fq "$marker" "$text_emoji_log"; then
      echo "MoUI Skia text/emoji smoke did not print renderer-proof marker: $marker" >&2
      exit 1
    fi
  done
  echo "Verified MoUI Skia text/emoji renderer-proof markers."
fi

if [[ $skip_showcase_build -eq 0 ]]; then
  MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon build examples/showcase/macos_skia --target native
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
    if [[ $run_gpu_smoke -eq 1 ]]; then
      MOUI_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT=1 \
        MOUI_MACOS_SKIA_SURFACE_ROUTE=metal-gpu \
        "$showcase_exe" >"$showcase_log" 2>&1 &
    else
      MOUI_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT=1 "$showcase_exe" >"$showcase_log" 2>&1 &
    fi
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
    if [[ $run_gpu_smoke -eq 1 ]]; then
      if ! grep -Fq "macOS Skia renderer route diagnostics: surface_route=metal-gpu; surface_gpu=true" "$showcase_log"; then
        echo "macos_skia Showcase smoke did not prove the Metal GPU route" >&2
        exit 1
      fi
      echo "Verified macos_skia Showcase GPU route marker."
    fi
    echo "Verified macos_skia Showcase first-frame smoke marker."
  fi
fi

if [[ $run_markdown_smoke -eq 1 ]]; then
  MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon build examples/markdown_editor/macos_skia --target native
  markdown_exe="$repo_root/_build/native/debug/build/examples/markdown_editor/macos_skia/macos_skia.exe"
  if [[ -x "$markdown_exe" ]]; then
    echo "Built markdown_editor/macos_skia executable: $markdown_exe"
  else
    echo "markdown_editor/macos_skia executable was not produced at $markdown_exe" >&2
    exit 1
  fi

  echo "Running markdown_editor/macos_skia first-frame smoke executable: $markdown_exe"
  if [[ -z "$markdown_log" ]]; then
    markdown_log="$(mktemp "${TMPDIR:-/tmp}/moui-macos-skia-markdown-smoke.XXXXXX.log")"
    markdown_log_is_temporary=1
  else
    mkdir -p "$(dirname "$markdown_log")"
    : > "$markdown_log"
  fi

  set +e
  if [[ $run_gpu_smoke -eq 1 ]]; then
    MOUI_MARKDOWN_EDITOR_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT=1 \
      MOUI_MACOS_SKIA_SURFACE_ROUTE=metal-gpu \
      "$markdown_exe" >"$markdown_log" 2>&1 &
  else
    MOUI_MARKDOWN_EDITOR_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT=1 "$markdown_exe" >"$markdown_log" 2>&1 &
  fi
  markdown_pid=$!
  (
    sleep "$markdown_timeout"
    if kill -0 "$markdown_pid" 2>/dev/null; then
      echo "markdown_editor/macos_skia smoke timed out after ${markdown_timeout}s" >>"$markdown_log"
      kill "$markdown_pid" 2>/dev/null
    fi
  ) &
  markdown_watchdog_pid=$!
  wait "$markdown_pid"
  markdown_status=$?
  kill "$markdown_watchdog_pid" 2>/dev/null
  wait "$markdown_watchdog_pid" 2>/dev/null
  cat "$markdown_log"
  set -e
  if [[ $markdown_status -ne 0 ]]; then
    exit "$markdown_status"
  fi
  if ! grep -Fq "macOS renderer presented first frame; exiting by request" "$markdown_log"; then
    echo "markdown_editor/macos_skia smoke did not print the expected first-frame marker" >&2
    exit 1
  fi
  if [[ $run_gpu_smoke -eq 1 ]]; then
    if ! grep -Fq "macOS Skia renderer route diagnostics: surface_route=metal-gpu; surface_gpu=true" "$markdown_log"; then
      echo "markdown_editor/macos_skia smoke did not prove the Metal GPU route" >&2
      exit 1
    fi
    echo "Verified markdown_editor/macos_skia GPU route marker."
  fi
  echo "Verified markdown_editor/macos_skia first-frame smoke marker."
fi

if [[ -n "$platform_evidence_manifest" ]]; then
  record_host="$(uname -s 2>/dev/null || echo Darwin) $(uname -m 2>/dev/null || true) local Skia smoke"
  record_args=(
    "$(relative_to_repo "$platform_evidence_manifest")" \
    macos \
    --host "$record_host" \
    --renderer-smoke-log "$(relative_to_repo "$smoke_log")" \
    --async-image-log "$(relative_to_repo "$smoke_log")" \
    --showcase-log "$(relative_to_repo "$showcase_log")" \
    --markdown-log "$(relative_to_repo "$markdown_log")" \
    --note "macOS real-Skia renderer, async image second-frame, and Showcase/Markdown Editor first-frame markers passed on the local Darwin host; provider preflight and fallback-unavailable observations require their own artifacts before Skia route evidence is passed."
  )
  if [[ $run_gpu_smoke -eq 1 ]]; then
    record_args+=(--gpu-renderer-smoke-log "$(relative_to_repo "$smoke_log")")
    record_args+=(--gpu-showcase-log "$(relative_to_repo "$showcase_log")")
    record_args+=(--gpu-markdown-log "$(relative_to_repo "$markdown_log")")
  fi
  node scripts/record-native-skia-evidence.mjs "${record_args[@]}"
fi

echo "MoUI macOS Skia renderer smoke passed."
