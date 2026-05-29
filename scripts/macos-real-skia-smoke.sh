#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/macos-real-skia-smoke.sh [options]

Options:
  --work-dir PATH       Directory for depot_tools, Skia checkout, and build output.
                        Default: .skia-cache/macos.
  --skia-include PATH   Existing Skia checkout/include root. When supplied with
                        --skia-lib-dir, selects existing provider.
  --skia-lib-dir PATH   Existing directory containing libskia.a or libskia.dylib.
  --skia-lib NAME       Library name without lib prefix, default: skia.
  --skia-provider source|existing|jetbrains
                        Skia acquisition mode. Default: jetbrains unless
                        --skia-include/--skia-lib-dir select existing.
  --skia-rev REV        Skia git revision, branch, or tag to checkout.
                        Default: first non-comment line of skia-revision.txt.
  --jetbrains-tag TAG   JetBrains/skia release tag. Default: m148-8967a2e80c.
  --jetbrains-config Release|Debug
                        JetBrains/skia package configuration. Default: Release.
  --jetbrains-cache-dir PATH
                        JetBrains/skia cache root. Default: .skia-cache/jetbrains.
  --extra-gn-args STR   Extra GN args appended to the source-built Skia build.
  --extra-cc-flags STR  Extra C/C++ flags appended when linking the MoonBit stub.
  --extra-link-flags STR
                        Extra linker flags appended when linking the smoke binary.
  --build-log PATH      Write source-built Skia build output to PATH.
                        Relative paths are resolved from the repository root.
  --smoke-log PATH      Write the native smoke executable output to PATH.
                        Relative paths are resolved from the repository root.
  --no-sync-deps        Skip python3 tools/git-sync-deps for source provider.
  --no-fetch            Reuse an existing Skia checkout for source provider.
  --dry-run-config      Print selected mode and effective smoke arguments,
                        then exit without fetching/building Skia or rewriting package files.
  -h, --help            Show this help.

This wrapper mirrors scripts/linux-real-skia-smoke.sh for macOS. It consumes
JetBrains provider output and delegates final native/moon.pkg generation to
scripts/macos-skia-smoke.sh.
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
build_log=""
smoke_log=""
sync_deps=1
fetch_repo=1
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
      build_log="${2:-}"
      shift 2
      ;;
    --smoke-log)
      smoke_log="${2:-}"
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
if [[ $skia_rev_explicit -eq 0 && -f "$repo_root/skia-revision.txt" ]]; then
  pinned_skia_rev="$(grep -v '^[[:space:]]*#' "$repo_root/skia-revision.txt" | grep -v '^[[:space:]]*$' | head -n 1 || true)"
  if [[ -n "$pinned_skia_rev" ]]; then
    skia_rev="$pinned_skia_rev"
  fi
fi
case "$work_dir" in
  /*) resolved_work_dir="$work_dir" ;;
  *) resolved_work_dir="$repo_root/$work_dir" ;;
esac

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

jetbrains_package=""
jetbrains_package_sha256=""
jetbrains_commit=""

if [[ "$skia_provider" == "existing" ]]; then
  if [[ -z "$skia_include" || -z "$skia_lib_dir" ]]; then
    echo "--skia-include and --skia-lib-dir must be supplied together for --skia-provider existing" >&2
    exit 2
  fi
  smoke_mode="existing Skia build"
  smoke_include="$skia_include"
  smoke_lib_dir="$skia_lib_dir"
elif [[ "$skia_provider" == "source" ]]; then
  if [[ -n "$skia_include" || -n "$skia_lib_dir" ]]; then
    echo "--skia-provider source cannot be combined with --skia-include/--skia-lib-dir" >&2
    exit 2
  fi
  smoke_mode="source-built Skia"
  smoke_include="$resolved_work_dir/skia"
  smoke_lib_dir="$resolved_work_dir/skia/out/moonbit-smoke"
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
    --cache-dir "$jetbrains_cache_dir"
    --print-env
  )
  if [[ $dry_run_config -eq 1 ]]; then
    fetch_args+=(--dry-run-config)
  fi
  fetch_output="$(bash "$repo_root/scripts/fetch-jetbrains-skia.sh" "${fetch_args[@]}")"
  get_fetch_value() {
    local key="$1"
    printf '%s\n' "$fetch_output" | sed -n "s/^${key}=//p" | tail -n 1
  }
  smoke_mode="JetBrains Skia binary"
  smoke_include="$(get_fetch_value SKIA_MBT_SKIA_INCLUDE)"
  smoke_lib_dir="$(get_fetch_value SKIA_MBT_SKIA_LIB_DIR)"
  skia_lib="$(get_fetch_value SKIA_MBT_SKIA_LIB)"
  jetbrains_tag="$(get_fetch_value SKIA_MBT_JETBRAINS_TAG)"
  jetbrains_commit="$(get_fetch_value SKIA_MBT_SKIA_COMMIT)"
  jetbrains_package="$(get_fetch_value SKIA_MBT_SKIA_PACKAGE)"
  jetbrains_package_sha256="$(get_fetch_value SKIA_MBT_SKIA_PACKAGE_SHA256)"
  if [[ $extra_cc_flags_explicit -eq 0 ]]; then
    extra_cc_flags="$(get_fetch_value SKIA_MBT_EXTRA_CC_FLAGS)"
  fi
  if [[ $extra_link_flags_explicit -eq 0 ]]; then
    extra_link_flags="$(get_fetch_value SKIA_MBT_EXTRA_LINK_FLAGS)"
  fi
fi

echo "macOS real Skia smoke mode: $smoke_mode"
echo "  skia_provider=$skia_provider"
if [[ "$skia_provider" == "jetbrains" ]]; then
  echo "  jetbrains_tag=$jetbrains_tag"
  echo "  skia_commit=$jetbrains_commit"
  echo "  skia_package=$jetbrains_package"
  echo "  skia_package_sha256=$jetbrains_package_sha256"
fi
if [[ "$skia_provider" == "existing" || "$skia_provider" == "jetbrains" ]]; then
  if [[ -n "$extra_gn_args" ]]; then
    echo "  note: extra_gn_args is ignored unless --skia-provider source is selected"
  fi
else
  echo "  work_dir=$resolved_work_dir"
  echo "  skia_rev=$skia_rev"
fi

resolved_build_log=""
if [[ -n "$build_log" ]]; then
  case "$build_log" in
    /*) resolved_build_log="$build_log" ;;
    *) resolved_build_log="$repo_root/$build_log" ;;
  esac
fi

if [[ "$skia_provider" == "source" ]]; then
  build_args=(--work-dir "$resolved_work_dir" --skia-rev "$skia_rev")
  if [[ -n "$extra_gn_args" ]]; then
    build_args+=(--extra-gn-args "$extra_gn_args")
  fi
  if [[ $sync_deps -eq 0 ]]; then
    build_args+=(--no-sync-deps)
  fi
  if [[ $fetch_repo -eq 0 ]]; then
    build_args+=(--no-fetch)
  fi
  if [[ $dry_run_config -eq 0 ]]; then
    if [[ -n "$resolved_build_log" ]]; then
      mkdir -p "$(dirname "$resolved_build_log")"
      : > "$resolved_build_log"
      set +e
      set -o pipefail
      bash "$repo_root/scripts/macos-build-skia.sh" "${build_args[@]}" 2>&1 | tee "$resolved_build_log"
      build_status=${PIPESTATUS[0]}
      set +o pipefail
      set -e
      if [[ $build_status -ne 0 ]]; then
        exit "$build_status"
      fi
    else
      bash "$repo_root/scripts/macos-build-skia.sh" "${build_args[@]}"
    fi
  fi
else
  build_args=()
fi

echo "  skia_include=$smoke_include"
echo "  skia_lib_dir=$smoke_lib_dir"
echo "  skia_lib=$skia_lib"
if [[ -n "$extra_gn_args" ]]; then
  echo "  extra_gn_args=$extra_gn_args"
fi
if [[ -n "$extra_cc_flags" ]]; then
  echo "  extra_cc_flags=$extra_cc_flags"
fi
if [[ -n "$extra_link_flags" ]]; then
  echo "  extra_link_flags=$extra_link_flags"
fi
if [[ -n "$build_log" ]]; then
  echo "  build_log=$build_log"
fi
if [[ -n "$smoke_log" ]]; then
  echo "  smoke_log=$smoke_log"
fi

smoke_args=(
  --skia-include "$smoke_include"
  --skia-lib-dir "$smoke_lib_dir"
  --skia-lib "$skia_lib"
  --skia-provider "$skia_provider"
)
if [[ "$skia_provider" == "jetbrains" ]]; then
  smoke_args+=(
    --jetbrains-tag "$jetbrains_tag"
    --skia-commit "$jetbrains_commit"
    --skia-package "$jetbrains_package"
    --skia-package-sha256 "$jetbrains_package_sha256"
  )
fi
if [[ -n "$extra_cc_flags" ]]; then
  smoke_args+=(--extra-cc-flags "$extra_cc_flags")
fi
if [[ -n "$extra_link_flags" ]]; then
  smoke_args+=(--extra-link-flags "$extra_link_flags")
fi
if [[ -n "$smoke_log" ]]; then
  smoke_args+=(--smoke-log "$smoke_log")
fi

if [[ $dry_run_config -eq 1 ]]; then
  if [[ ${#build_args[@]} -gt 0 ]]; then
    printf "  build_arg: %q\n" "${build_args[@]}"
  fi
  if [[ "$skia_provider" == "source" ]]; then
    bash "$repo_root/scripts/macos-build-skia.sh" --dry-run-config "${build_args[@]}"
  fi
  if [[ "$skia_provider" == "existing" ]]; then
    bash "$repo_root/scripts/macos-skia-smoke.sh" --dry-run-config "${smoke_args[@]}"
  fi
  echo "Dry run complete; package files were not modified and no build was run."
  printf "  smoke_arg: %q\n" "${smoke_args[@]}"
  exit 0
fi

bash "$repo_root/scripts/macos-skia-smoke.sh" "${smoke_args[@]}"
