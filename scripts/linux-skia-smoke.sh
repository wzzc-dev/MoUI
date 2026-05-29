#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/linux-skia-smoke.sh --skia-include PATH --skia-lib-dir PATH [options]

Options:
  --skia-include PATH    Skia checkout or include root containing Skia headers.
  --skia-lib-dir PATH    Directory containing libskia.a or libskia.so.
  --skia-lib NAME        Library name without lib prefix, default: skia.
  --skia-provider NAME   Provider label to record in logs, e.g. jetbrains.
  --jetbrains-tag TAG    JetBrains/skia tag to record when provider is jetbrains.
  --skia-commit HASH     Full Skia commit to record in logs.
  --skia-package NAME    Skia binary package name to record in logs.
  --skia-package-sha256 SHA256
                         Skia binary package SHA256 to record in logs.
  --extra-cc-flags STR   Extra C/C++ flags appended to stub-cc-flags.
  --extra-link-flags STR Extra linker flags appended to cc-link-flags.
  --smoke-log PATH       Write the native smoke executable output to PATH.
                         Relative paths are resolved from the repository root.
  --dry-run-config       Print resolved paths and flags, then exit without
                         rewriting native/moon.pkg or building the smoke binary.
  -h, --help             Show this help.

The script temporarily rewrites native/moon.pkg, builds scripts/native_smoke
with --target native, runs the produced executable directly, then restores the
original package file. The executable output must include the final smoke-test
success marker so CI proves the real backend path reached the end of the test.

Environment defaults:
  SKIA_MBT_SKIA_INCLUDE, SKIA_MBT_SKIA_LIB_DIR, SKIA_MBT_SKIA_LIB,
  SKIA_MBT_SKIA_PROVIDER, SKIA_MBT_JETBRAINS_TAG, SKIA_MBT_SKIA_COMMIT,
  SKIA_MBT_SKIA_PACKAGE, SKIA_MBT_SKIA_PACKAGE_SHA256,
  SKIA_MBT_EXTRA_CC_FLAGS, and SKIA_MBT_EXTRA_LINK_FLAGS are used when the
  matching command-line option is omitted.
EOF
}

skia_include="${SKIA_MBT_SKIA_INCLUDE:-}"
skia_lib_dir="${SKIA_MBT_SKIA_LIB_DIR:-}"
skia_lib="${SKIA_MBT_SKIA_LIB:-skia}"
skia_provider="${SKIA_MBT_SKIA_PROVIDER:-}"
jetbrains_tag="${SKIA_MBT_JETBRAINS_TAG:-}"
skia_commit="${SKIA_MBT_SKIA_COMMIT:-}"
skia_package="${SKIA_MBT_SKIA_PACKAGE:-}"
skia_package_sha256="${SKIA_MBT_SKIA_PACKAGE_SHA256:-}"
extra_cc_flags="${SKIA_MBT_EXTRA_CC_FLAGS:-}"
extra_link_flags="${SKIA_MBT_EXTRA_LINK_FLAGS:-}"
requested_smoke_log=""
dry_run_config=0

while [[ $# -gt 0 ]]; do
  case "$1" in
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
      shift 2
      ;;
    --jetbrains-tag)
      jetbrains_tag="${2:-}"
      shift 2
      ;;
    --skia-commit)
      skia_commit="${2:-}"
      shift 2
      ;;
    --skia-package)
      skia_package="${2:-}"
      shift 2
      ;;
    --skia-package-sha256)
      skia_package_sha256="${2:-}"
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
    --smoke-log)
      requested_smoke_log="${2:-}"
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

if [[ -z "$skia_include" || -z "$skia_lib_dir" ]]; then
  usage >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
native_pkg="$repo_root/native/moon.pkg"
backup_pkg="$native_pkg.smoke.bak"
smoke_log=""
smoke_log_is_temporary=0
include_path="$(cd "$skia_include" && pwd)"
lib_path="$(cd "$skia_lib_dir" && pwd)"
if [[ -n "$requested_smoke_log" ]]; then
  case "$requested_smoke_log" in
    /*) smoke_log="$requested_smoke_log" ;;
    *) smoke_log="$repo_root/$requested_smoke_log" ;;
  esac
fi

if [[ ! -f "$include_path/include/core/SkSurface.h" ]]; then
  echo "Skia include path does not look like a Skia checkout/root: $include_path" >&2
  exit 1
fi

if [[ ! -f "$lib_path/lib$skia_lib.a" && ! -f "$lib_path/lib$skia_lib.so" ]]; then
  echo "Skia library lib$skia_lib.a or lib$skia_lib.so was not found in $lib_path" >&2
  exit 1
fi

echo "Linux Skia smoke environment:"
echo "  moon=$(moon version 2>/dev/null | head -n 1 || true)"
echo "  cxx=$(${CXX:-g++} --version 2>/dev/null | head -n 1 || true)"
echo "  skia_include=$include_path"
echo "  skia_lib_dir=$lib_path"
echo "  skia_lib=$skia_lib"
if [[ -n "$skia_provider" ]]; then
  echo "  skia_provider=$skia_provider"
fi
if [[ -n "$jetbrains_tag" ]]; then
  echo "  jetbrains_tag=$jetbrains_tag"
fi
if [[ -n "$skia_commit" ]]; then
  echo "  skia_commit=$skia_commit"
elif [[ -d "$include_path/.git" ]]; then
  echo "  skia_commit=$(git -C "$include_path" rev-parse HEAD)"
fi
if [[ -n "$skia_package" ]]; then
  echo "  skia_package=$skia_package"
fi
if [[ -n "$skia_package_sha256" ]]; then
  echo "  skia_package_sha256=$skia_package_sha256"
fi
find "$lib_path" -maxdepth 1 \( -name "lib$skia_lib.a" -o -name "lib$skia_lib.so" \) \
  -printf '  library=%f %s bytes\n'

cc_flags="-DSKIA_MBT_HAS_SKIA -std=c++17 -I$include_path"
if [[ -n "$extra_cc_flags" ]]; then
  cc_flags="$cc_flags $extra_cc_flags"
fi

link_flags="-L$lib_path -l$skia_lib -lstdc++"
if [[ -n "$extra_link_flags" ]]; then
  link_flags="$link_flags $extra_link_flags"
fi

echo "  stub_cc_flags=$cc_flags"
echo "  cc_link_flags=$link_flags"
if [[ -n "$smoke_log" ]]; then
  echo "  smoke_log=$smoke_log"
fi

if [[ $dry_run_config -eq 1 ]]; then
  echo "Dry run complete; native/moon.pkg was not modified and no build was run."
  exit 0
fi

restore_native_pkg() {
  if [[ $smoke_log_is_temporary -eq 1 && -n "${smoke_log:-}" && -f "$smoke_log" ]]; then
    rm -f "$smoke_log"
  fi
  if [[ -f "$backup_pkg" ]]; then
    cp "$backup_pkg" "$native_pkg"
    rm -f "$backup_pkg"
    echo "Restored native/moon.pkg after Linux Skia smoke."
  else
    echo "No native/moon.pkg smoke backup found; nothing to restore."
  fi
}
trap restore_native_pkg EXIT

cp "$native_pkg" "$backup_pkg"
echo "Backed up native/moon.pkg to $backup_pkg."

bash "$repo_root/scripts/configure-linux-native-pkg.sh" \
  --skia-include "$include_path" \
  --skia-lib-dir "$lib_path" \
  --skia-lib "$skia_lib" \
  --extra-cc-flags "$extra_cc_flags" \
  --extra-link-flags "$extra_link_flags" \
  --output "$native_pkg" \
  --write >/dev/null
echo "Wrote temporary native/moon.pkg with Linux Skia link flags."

cd "$repo_root/scripts/native_smoke"
moon build --target native
smoke_exe="$PWD/_build/native/debug/build/skia_mbt_native_smoke"
if [[ ! -x "$smoke_exe" ]]; then
  echo "native smoke executable was not produced at $smoke_exe" >&2
  exit 1
fi
export LD_LIBRARY_PATH="$lib_path${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
echo "Running native smoke executable: $smoke_exe"
if [[ -z "$smoke_log" ]]; then
  smoke_log="$(mktemp "${TMPDIR:-/tmp}/skia-mbt-native-smoke.XXXXXX.log")"
  smoke_log_is_temporary=1
else
  mkdir -p "$(dirname "$smoke_log")"
  : > "$smoke_log"
fi
"$smoke_exe" 2>&1 | tee "$smoke_log"
if ! grep -Fq "skia_mbt native smoke test passed" "$smoke_log"; then
  echo "native smoke executable did not print the expected success marker" >&2
  exit 1
fi
echo "Verified native smoke success marker."
