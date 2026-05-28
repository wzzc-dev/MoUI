#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/linux-real-skia-smoke.sh [options]

Options:
  --work-dir PATH       Directory for depot_tools, Skia checkout, and build output.
                        Default: .skia-cache/linux.
  --skia-include PATH   Existing Skia checkout/include root. When supplied with
                        --skia-lib-dir, skips building Skia from source.
  --skia-lib-dir PATH   Existing directory containing libskia.a or libskia.so.
  --skia-lib NAME       Library name without lib prefix, default: skia.
  --skia-rev REV        Skia git revision, branch, or tag to checkout.
                        Default: first non-comment line of skia-revision.txt.
  --extra-gn-args STR   Extra GN args appended to the smoke-test Skia build.
  --extra-cc-flags STR  Extra C/C++ flags appended when linking the MoonBit stub.
  --extra-link-flags STR
                        Extra linker flags appended when linking the smoke binary.
                        Default: -lpthread -ldl -lm.
  --build-log PATH      Write source-built Skia build output to PATH.
                        Relative paths are resolved from the repository root.
  --smoke-log PATH      Write the native smoke executable output to PATH.
                        Relative paths are resolved from the repository root.
  --no-sync-deps        Skip python3 tools/git-sync-deps.
  --no-fetch            Reuse an existing Skia checkout instead of cloning/fetching.
  --dry-run-config      Print the selected mode and effective smoke arguments,
                        then exit without fetching/building Skia or rewriting native/moon.pkg.
  -h, --help            Show this help.

Builds a small CPU-only Skia from source unless --skia-include/--skia-lib-dir
are provided, temporarily links native/moon.pkg against it, and runs
scripts/native_smoke as a real Skia backend check.

Environment defaults:
  SKIA_MBT_SKIA_INCLUDE, SKIA_MBT_SKIA_LIB_DIR, SKIA_MBT_SKIA_LIB,
  SKIA_MBT_SKIA_REV, SKIA_MBT_EXTRA_GN_ARGS, SKIA_MBT_EXTRA_CC_FLAGS,
  and SKIA_MBT_EXTRA_LINK_FLAGS are used when the matching command-line option
  is omitted.
EOF
}

work_dir=".skia-cache/linux"
skia_include="${SKIA_MBT_SKIA_INCLUDE:-}"
skia_lib_dir="${SKIA_MBT_SKIA_LIB_DIR:-}"
skia_lib="${SKIA_MBT_SKIA_LIB:-skia}"
skia_rev="${SKIA_MBT_SKIA_REV:-main}"
skia_rev_explicit=0
if [[ -n "${SKIA_MBT_SKIA_REV:-}" ]]; then
  skia_rev_explicit=1
fi
extra_gn_args="${SKIA_MBT_EXTRA_GN_ARGS:-}"
extra_cc_flags="${SKIA_MBT_EXTRA_CC_FLAGS:-}"
extra_link_flags="${SKIA_MBT_EXTRA_LINK_FLAGS:--lpthread -ldl -lm}"
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
    --skia-rev)
      skia_rev="${2:-}"
      skia_rev_explicit=1
      shift 2
      ;;
    --extra-gn-args)
      extra_gn_args="${2:-}"
      shift 2
      ;;
    --extra-cc-flags)
      extra_cc_flags="${2:-}"
      shift 2
      ;;
    --extra-link-flags)
      extra_link_flags="${2:-}"
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

if [[ -n "$skia_include" || -n "$skia_lib_dir" ]]; then
  if [[ -z "$skia_include" || -z "$skia_lib_dir" ]]; then
    echo "--skia-include and --skia-lib-dir must be supplied together" >&2
    exit 2
  fi
  smoke_mode="existing Skia build"
  smoke_include="$skia_include"
  smoke_lib_dir="$skia_lib_dir"
else
  smoke_mode="source-built Skia"
  smoke_include="$resolved_work_dir/skia"
  smoke_lib_dir="$resolved_work_dir/skia/out/moonbit-smoke"
fi

echo "Linux real Skia smoke mode: $smoke_mode"
if [[ "$smoke_mode" == "existing Skia build" ]]; then
  echo "  skia_include=$smoke_include"
  echo "  skia_lib_dir=$smoke_lib_dir"
  if [[ -n "$extra_gn_args" ]]; then
    echo "  note: extra_gn_args is ignored when using an existing Skia build"
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

if [[ "$smoke_mode" == "source-built Skia" ]]; then
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
      bash "$repo_root/scripts/linux-build-skia.sh" "${build_args[@]}" 2>&1 | tee "$resolved_build_log"
      build_status=${PIPESTATUS[0]}
      set +o pipefail
      set -e
      if [[ $build_status -ne 0 ]]; then
        exit "$build_status"
      fi
    else
      bash "$repo_root/scripts/linux-build-skia.sh" "${build_args[@]}"
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
)
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
  if [[ "$smoke_mode" == "source-built Skia" ]]; then
    bash "$repo_root/scripts/linux-build-skia.sh" --dry-run-config "${build_args[@]}"
  fi
  if [[ "$smoke_mode" == "existing Skia build" ]]; then
    bash "$repo_root/scripts/linux-skia-smoke.sh" --dry-run-config "${smoke_args[@]}"
  fi
  echo "Dry run complete; native/moon.pkg was not modified and no build was run."
  printf "  smoke_arg: %q\n" "${smoke_args[@]}"
  exit 0
fi

bash "$repo_root/scripts/linux-skia-smoke.sh" "${smoke_args[@]}"
