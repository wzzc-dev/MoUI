#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/macos-skia-smoke.sh --skia-include PATH --skia-lib-dir PATH [options]

Options:
  --skia-include PATH    Skia checkout or include root containing Skia headers.
  --skia-lib-dir PATH    Directory containing libskia.a or libskia.dylib.
  --skia-lib NAME        Library name without lib prefix, default: skia.
  --link-mode MODE       static|dynamic|auto. Default: static.
  --skia-provider NAME   Provider label to record in logs, e.g. release.
  --release-owner OWNER  GitHub release owner to record when provider is release.
  --release-repo REPO    GitHub release repository to record when provider is release.
  --release-tag TAG      GitHub release tag to record when provider is release.
  --release-url URL      GitHub release URL to record when provider is release.
  --jetbrains-tag TAG    JetBrains/skia tag to record when provider is jetbrains.
  --skia-commit HASH     Full Skia commit to record in logs.
  --skia-package NAME    Skia binary package name to record in logs.
  --skia-package-sha256 SHA256
                         Skia binary package SHA256 to record in logs.
  --enable-skshaper      Enable the optional SkShaper FFI boundary. Requires
                         libskshaper and its dependent module libraries in
                         --skia-lib-dir.
  --enable-asan          Add AddressSanitizer compile/link flags to the native
                         smoke build. macOS disables leak detection by default
                         unless ASAN_OPTIONS is already set.
  --extra-cc-flags STR   Extra C/C++ flags appended to stub-cc-flags.
  --extra-link-flags STR Extra linker flags appended to cc-link-flags.
  --smoke-log PATH       Write the native smoke executable output to PATH.
                         Relative paths are resolved from the repository root.
  --dry-run-config       Print resolved paths and flags, then exit without
                         rewriting package files or building the smoke binary.
  -h, --help             Show this help.

The script temporarily rewrites native/moon.pkg and scripts/native_smoke/moon.pkg,
builds scripts/native_smoke with --target native, runs the produced executable
directly, then restores both package files.
The executable output must include the final smoke-test success marker so CI
proves the real backend path reached the end of the test.

Environment defaults:
  SKIA_MBT_SKIA_INCLUDE, SKIA_MBT_SKIA_LIB_DIR, SKIA_MBT_SKIA_LIB,
  SKIA_MBT_SKIA_LINK_MODE, SKIA_MBT_MACOS_LINK_MODE,
  SKIA_MBT_SKIA_PROVIDER, SKIA_MBT_RELEASE_OWNER, SKIA_MBT_RELEASE_REPO,
  SKIA_MBT_RELEASE_TAG, SKIA_MBT_RELEASE_URL, SKIA_MBT_JETBRAINS_TAG,
  SKIA_MBT_SKIA_COMMIT, SKIA_MBT_SKIA_PACKAGE, SKIA_MBT_SKIA_PACKAGE_SHA256,
  SKIA_MBT_ENABLE_ASAN, SKIA_MBT_EXTRA_CC_FLAGS, and
  SKIA_MBT_EXTRA_LINK_FLAGS are used when the matching command-line option is
  omitted.
EOF
}

normalize_bool() {
  case "$1" in
    1|true|TRUE|yes|YES|on|ON) printf '1\n' ;;
    ""|0|false|FALSE|no|NO|off|OFF) printf '0\n' ;;
    *)
      echo "unsupported boolean value for SKIA_MBT_ENABLE_ASAN: $1" >&2
      exit 2
      ;;
  esac
}

skia_include="${SKIA_MBT_SKIA_INCLUDE:-}"
skia_lib_dir="${SKIA_MBT_SKIA_LIB_DIR:-}"
skia_lib="${SKIA_MBT_SKIA_LIB:-skia}"
skia_link_mode="${SKIA_MBT_SKIA_LINK_MODE:-${SKIA_MBT_MACOS_LINK_MODE:-static}}"
skia_provider="${SKIA_MBT_SKIA_PROVIDER:-}"
release_owner="${SKIA_MBT_RELEASE_OWNER:-}"
release_repo="${SKIA_MBT_RELEASE_REPO:-}"
release_tag="${SKIA_MBT_RELEASE_TAG:-}"
release_url="${SKIA_MBT_RELEASE_URL:-}"
jetbrains_tag="${SKIA_MBT_JETBRAINS_TAG:-}"
skia_commit="${SKIA_MBT_SKIA_COMMIT:-}"
skia_package="${SKIA_MBT_SKIA_PACKAGE:-}"
skia_package_sha256="${SKIA_MBT_SKIA_PACKAGE_SHA256:-}"
extra_cc_flags="${SKIA_MBT_EXTRA_CC_FLAGS:-}"
extra_link_flags="${SKIA_MBT_EXTRA_LINK_FLAGS:-}"
enable_skshaper=0
enable_asan="${SKIA_MBT_ENABLE_ASAN:-0}"
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
    --link-mode)
      skia_link_mode="${2:-}"
      shift 2
      ;;
    --skia-provider)
      skia_provider="${2:-}"
      shift 2
      ;;
    --release-owner)
      release_owner="${2:-}"
      shift 2
      ;;
    --release-repo)
      release_repo="${2:-}"
      shift 2
      ;;
    --release-tag)
      release_tag="${2:-}"
      shift 2
      ;;
    --release-url)
      release_url="${2:-}"
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
    --enable-skshaper)
      enable_skshaper=1
      shift
      ;;
    --enable-asan)
      enable_asan=1
      shift
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

enable_asan="$(normalize_bool "$enable_asan")"
case "$skia_link_mode" in
  static|dynamic|auto) ;;
  *) echo "unsupported --link-mode: $skia_link_mode" >&2; usage >&2; exit 2 ;;
esac

if [[ -z "$skia_include" || -z "$skia_lib_dir" ]]; then
  usage >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
native_pkg="$repo_root/native/moon.pkg"
backup_pkg="$native_pkg.smoke.bak"
smoke_pkg="$repo_root/scripts/native_smoke/moon.pkg"
smoke_backup_pkg="$smoke_pkg.smoke.bak"
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

static_lib="$lib_path/lib$skia_lib.a"
dynamic_lib="$lib_path/lib$skia_lib.dylib"
if [[ ! -f "$static_lib" && ! -f "$dynamic_lib" ]]; then
  echo "Skia library lib$skia_lib.a or lib$skia_lib.dylib was not found in $lib_path" >&2
  exit 1
fi
resolved_link_mode="$skia_link_mode"
if [[ "$resolved_link_mode" == "auto" ]]; then
  if [[ -f "$dynamic_lib" ]]; then
    resolved_link_mode="dynamic"
  else
    resolved_link_mode="static"
  fi
fi
case "$resolved_link_mode" in
  dynamic)
    if [[ ! -f "$dynamic_lib" ]]; then
      echo "Requested dynamic Skia link mode, but $dynamic_lib was not found" >&2
      exit 1
    fi
    skia_library_link_flags="$dynamic_lib"
    skia_runtime_link_flags="-Wl,-rpath,$lib_path"
    ;;
  static)
    if [[ ! -f "$static_lib" ]]; then
      echo "Requested static Skia link mode, but $static_lib was not found" >&2
      exit 1
    fi
    skia_library_link_flags="$static_lib"
    skia_runtime_link_flags=""
    ;;
esac
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

if [[ -f "$backup_pkg" ]]; then
  echo "native/moon.pkg smoke backup already exists: $backup_pkg" >&2
  echo "Resolve the stale backup before running smoke." >&2
  exit 1
fi
if [[ -f "$smoke_backup_pkg" ]]; then
  echo "scripts/native_smoke/moon.pkg smoke backup already exists: $smoke_backup_pkg" >&2
  echo "Resolve the stale backup before running smoke." >&2
  exit 1
fi

echo "macOS Skia smoke environment:"
echo "  moon=$(moon version 2>/dev/null | head -n 1 || true)"
echo "  cxx=$(${CXX:-c++} --version 2>/dev/null | head -n 1 || true)"
echo "  skia_include=$include_path"
echo "  skia_lib_dir=$lib_path"
echo "  skia_lib=$skia_lib"
echo "  skia_link_mode=$resolved_link_mode"
if [[ -n "$skia_provider" ]]; then
  echo "  skia_provider=$skia_provider"
fi
if [[ -n "$release_owner" ]]; then
  echo "  release_owner=$release_owner"
fi
if [[ -n "$release_repo" ]]; then
  echo "  release_repo=$release_repo"
fi
if [[ -n "$release_tag" ]]; then
  echo "  release_tag=$release_tag"
fi
if [[ -n "$release_url" ]]; then
  echo "  release_url=$release_url"
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
if [[ $enable_skshaper -eq 1 ]]; then
  echo "  skshaper=enabled"
fi
if [[ $enable_asan -eq 1 ]]; then
  echo "  asan=enabled"
fi
find "$lib_path" -maxdepth 1 \( -name "lib$skia_lib.a" -o -name "lib$skia_lib.dylib" \) \
  -print | while IFS= read -r lib_file; do
    size="$(wc -c < "$lib_file" | tr -d '[:space:]')"
    echo "  library=$(basename "$lib_file") ${size} bytes"
  done

if [[ $enable_asan -eq 1 ]]; then
  asan_cc_flags="-g -fsanitize=address -fno-omit-frame-pointer"
  asan_link_flags="-fsanitize=address"
  extra_cc_flags="${extra_cc_flags:+$extra_cc_flags }$asan_cc_flags"
  extra_link_flags="${extra_link_flags:+$extra_link_flags }$asan_link_flags"
  if [[ -z "${ASAN_OPTIONS:-}" ]]; then
    export ASAN_OPTIONS="detect_leaks=0:fast_unwind_on_malloc=0"
  fi
  echo "  asan_options=$ASAN_OPTIONS"
fi

native_extra_cc_flags="$extra_cc_flags"
native_extra_link_flags="$extra_link_flags"
if [[ $enable_skshaper -eq 1 ]]; then
  native_extra_cc_flags="-DSKIA_MBT_HAS_SKSHAPER${native_extra_cc_flags:+ $native_extra_cc_flags}"
  native_extra_link_flags="-lskshaper -lskunicode_core -lskunicode_icu -lharfbuzz -licu${native_extra_link_flags:+ $native_extra_link_flags}"
fi

cc_flags="-DSKIA_MBT_HAS_SKIA -std=c++17 -I$include_path"
if [[ $enable_skshaper -eq 1 ]]; then
  cc_flags="$cc_flags -DSKIA_MBT_HAS_SKSHAPER"
fi
if [[ -n "$extra_cc_flags" ]]; then
  cc_flags="$cc_flags $extra_cc_flags"
fi

link_flags="$skia_library_link_flags -lc++ -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework ImageIO -framework ApplicationServices"
if [[ -n "$skia_runtime_link_flags" ]]; then
  link_flags="$link_flags $skia_runtime_link_flags"
fi
if [[ $enable_skshaper -eq 1 ]]; then
  link_flags="$link_flags -lskshaper -lskunicode_core -lskunicode_icu -lharfbuzz -licu"
fi
if [[ -n "$extra_link_flags" ]]; then
  link_flags="$link_flags $extra_link_flags"
fi

echo "  stub_cc_flags=$cc_flags"
echo "  cc_link_flags=$link_flags"
if [[ -n "$smoke_log" ]]; then
  echo "  smoke_log=$smoke_log"
fi

if [[ $dry_run_config -eq 1 ]]; then
  echo "Dry run complete; package files were not modified and no build was run."
  exit 0
fi

restore_native_pkg() {
  if [[ $smoke_log_is_temporary -eq 1 && -n "${smoke_log:-}" && -f "$smoke_log" ]]; then
    rm -f "$smoke_log"
  fi
  if [[ -f "$backup_pkg" ]]; then
    cp "$backup_pkg" "$native_pkg"
    rm -f "$backup_pkg"
    echo "Restored native/moon.pkg after macOS Skia smoke."
  else
    echo "No native/moon.pkg smoke backup found; nothing to restore."
  fi
  if [[ -f "$smoke_backup_pkg" ]]; then
    cp "$smoke_backup_pkg" "$smoke_pkg"
    rm -f "$smoke_backup_pkg"
    echo "Restored scripts/native_smoke/moon.pkg after macOS Skia smoke."
  else
    echo "No scripts/native_smoke/moon.pkg smoke backup found; nothing to restore."
  fi
}
trap restore_native_pkg EXIT

cp "$native_pkg" "$backup_pkg"
echo "Backed up native/moon.pkg to $backup_pkg."
cp "$smoke_pkg" "$smoke_backup_pkg"
echo "Backed up scripts/native_smoke/moon.pkg to $smoke_backup_pkg."

bash "$repo_root/scripts/configure-macos-native-pkg.sh" \
  --skia-include "$include_path" \
  --skia-lib-dir "$lib_path" \
  --skia-lib "$skia_lib" \
  --link-mode "$resolved_link_mode" \
  --extra-cc-flags "$native_extra_cc_flags" \
  --extra-link-flags "$native_extra_link_flags" \
  --output "$native_pkg" \
  --write >/dev/null
echo "Wrote temporary native/moon.pkg with macOS Skia link flags."

cat > "$smoke_pkg" <<EOF
import {
  "wzzc-dev/skia_mbt" @skia,
  "wzzc-dev/skia_mbt/native" @native,
}

options(
  "is-main": true,
  "native-stub": [ "smoke_debug.c" ],
  link: {
    "native": {
      "cc-link-flags": "$link_flags",
    },
  },
)
EOF
echo "Wrote temporary scripts/native_smoke/moon.pkg with macOS Skia executable link flags."

cd "$repo_root/scripts/native_smoke"
moon build --target native
smoke_exe="$PWD/_build/native/debug/build/skia_mbt_native_smoke"
if [[ ! -x "$smoke_exe" && -x "$smoke_exe.exe" ]]; then
  smoke_exe="$smoke_exe.exe"
fi
if [[ ! -x "$smoke_exe" ]]; then
  echo "native smoke executable was not produced at $smoke_exe" >&2
  exit 1
fi
export DYLD_LIBRARY_PATH="$lib_path${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
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
if [[ $enable_skshaper -eq 1 ]]; then
  if ! grep -Fq "native smoke shaped glyph count" "$smoke_log"; then
    echo "native smoke executable did not prove the enabled SkShaper path" >&2
    exit 1
  fi
  echo "Verified native SkShaper smoke marker."
fi
