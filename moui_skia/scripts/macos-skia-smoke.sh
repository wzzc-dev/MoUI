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
  --enable-skparagraph   Build SkParagraph (default: on). Requires
                          libskparagraph, libskshaper, and SkUnicode libraries
                          to be linkable from --skia-lib-dir.
  --require-skparagraph  Enable SkParagraph and fail immediately when required
                         headers/libraries are missing or the runtime marker is
                         absent from the smoke log.
  --enable-asan          Add AddressSanitizer compile/link flags to the native
                         smoke build. macOS disables leak detection by default
                         unless ASAN_OPTIONS is already set.
  --extra-cc-flags STR   Extra C/C++ flags appended to stub-cc-flags.
  --extra-link-flags STR Extra linker flags appended to cc-link-flags.
  --smoke-log PATH       Write the native smoke executable output to PATH.
                          Relative paths are resolved from the repository root.
  --run-renderer-smoke   Also build and run moui_tests/skia_renderer_smoke/native
                          after native smoke. Requires --skia-include/--skia-lib-dir.
  --run-text-emoji-smoke Also build and run moui_tests/skia_text_emoji_smoke/native
                          after native smoke. Requires --enable-skparagraph or
                          --require-skparagraph for SkParagraph bidi/emoji markers.
  --renderer-log PATH    Write the renderer smoke executable output to PATH.
                          Relative paths are resolved from the repository root.
  --text-emoji-log PATH  Write the text/emoji smoke executable output to PATH.
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
  MOUI_SKIA_SKIA_INCLUDE, MOUI_SKIA_SKIA_LIB_DIR, MOUI_SKIA_SKIA_LIB,
  MOUI_SKIA_LINK_MODE, MOUI_SKIA_SKIA_PROVIDER,
  MOUI_SKIA_RELEASE_OWNER, MOUI_SKIA_RELEASE_REPO,
  MOUI_SKIA_RELEASE_TAG, MOUI_SKIA_RELEASE_URL, MOUI_SKIA_JETBRAINS_TAG,
  MOUI_SKIA_SKIA_COMMIT, MOUI_SKIA_SKIA_PACKAGE, MOUI_SKIA_SKIA_PACKAGE_SHA256,
  MOUI_SKIA_ENABLE_SKPARAGRAPH, MOUI_SKIA_REQUIRE_SKPARAGRAPH,
  MOUI_SKIA_ENABLE_ASAN, MOUI_SKIA_EXTRA_CC_FLAGS, and MOUI_SKIA_EXTRA_LINK_FLAGS
  are used when the matching command-line option is omitted.
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

skia_include="${MOUI_SKIA_SKIA_INCLUDE:-}"
skia_lib_dir="${MOUI_SKIA_SKIA_LIB_DIR:-}"
skia_lib="${MOUI_SKIA_SKIA_LIB:-skia}"
skia_link_mode="${MOUI_SKIA_LINK_MODE:-static}"
skia_provider="${MOUI_SKIA_SKIA_PROVIDER:-}"
release_owner="${MOUI_SKIA_RELEASE_OWNER:-}"
release_repo="${MOUI_SKIA_RELEASE_REPO:-}"
release_tag="${MOUI_SKIA_RELEASE_TAG:-}"
release_url="${MOUI_SKIA_RELEASE_URL:-}"
jetbrains_tag="${MOUI_SKIA_JETBRAINS_TAG:-}"
skia_commit="${MOUI_SKIA_SKIA_COMMIT:-}"
skia_package="${MOUI_SKIA_SKIA_PACKAGE:-}"
skia_package_sha256="${MOUI_SKIA_SKIA_PACKAGE_SHA256:-}"
extra_cc_flags="${MOUI_SKIA_EXTRA_CC_FLAGS:-}"
extra_link_flags="${MOUI_SKIA_EXTRA_LINK_FLAGS:-}"
enable_skshaper=0
enable_skparagraph="${MOUI_SKIA_ENABLE_SKPARAGRAPH:-1}"
require_skparagraph="${MOUI_SKIA_REQUIRE_SKPARAGRAPH:-0}"
enable_asan="${MOUI_SKIA_ENABLE_ASAN:-0}"
requested_smoke_log=""
run_renderer_smoke=0
run_text_emoji_smoke=0
requested_renderer_log=""
requested_text_emoji_log=""
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
    --enable-skparagraph)
      enable_skparagraph=1
      shift
      ;;
    --require-skparagraph)
      require_skparagraph=1
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
    --run-renderer-smoke)
      run_renderer_smoke=1
      shift
      ;;
    --run-text-emoji-smoke)
      run_text_emoji_smoke=1
      shift
      ;;
    --renderer-log)
      requested_renderer_log="${2:-}"
      shift 2
      ;;
    --text-emoji-log)
      requested_text_emoji_log="${2:-}"
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

enable_asan="$(normalize_bool MOUI_SKIA_ENABLE_ASAN "$enable_asan")"
enable_skparagraph="$(normalize_bool MOUI_SKIA_ENABLE_SKPARAGRAPH "$enable_skparagraph")"
require_skparagraph="$(normalize_bool MOUI_SKIA_REQUIRE_SKPARAGRAPH "$require_skparagraph")"
if [[ $require_skparagraph -eq 1 ]]; then
  enable_skparagraph=1
fi
case "$skia_link_mode" in
  static|dynamic|auto) ;;
  *) echo "unsupported --link-mode: $skia_link_mode" >&2; usage >&2; exit 2 ;;
esac

if [[ -z "$skia_include" || -z "$skia_lib_dir" ]]; then
  usage >&2
  exit 2
fi

moui_skia_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_root="$(cd "$moui_skia_root/.." && pwd)"
native_pkg="$moui_skia_root/native/moon.pkg"
backup_pkg="$native_pkg.smoke.bak"
smoke_pkg="$moui_skia_root/scripts/native_smoke/moon.pkg"
smoke_backup_pkg="$smoke_pkg.smoke.bak"
renderer_pkg="$repo_root/moui_tests/skia_renderer_smoke/native/moon.pkg"
renderer_pkg_backup="$renderer_pkg.smoke.bak"
text_emoji_pkg="$repo_root/moui_tests/skia_text_emoji_smoke/native/moon.pkg"
text_emoji_pkg_backup="$text_emoji_pkg.smoke.bak"
smoke_log=""
smoke_log_is_temporary=0
renderer_log=""
renderer_log_is_temporary=0
text_emoji_log=""
text_emoji_log_is_temporary=0
include_path="$(cd "$skia_include" && pwd)"
lib_path="$(cd "$skia_lib_dir" && pwd)"
if [[ -n "$requested_smoke_log" ]]; then
  case "$requested_smoke_log" in
    /*) smoke_log="$requested_smoke_log" ;;
    *) smoke_log="$repo_root/$requested_smoke_log" ;;
  esac
fi
if [[ -n "$requested_renderer_log" ]]; then
  case "$requested_renderer_log" in
    /*) renderer_log="$requested_renderer_log" ;;
    *) renderer_log="$repo_root/$requested_renderer_log" ;;
  esac
fi
if [[ -n "$requested_text_emoji_log" ]]; then
  case "$requested_text_emoji_log" in
    /*) text_emoji_log="$requested_text_emoji_log" ;;
    *) text_emoji_log="$repo_root/$requested_text_emoji_log" ;;
  esac
fi

if [[ ! -f "$include_path/include/core/SkSurface.h" ]]; then
  echo "Skia include path does not look like a Skia checkout/root: $include_path" >&2
  exit 1
fi

paragraph_headers=(
  "$include_path/modules/skparagraph/include/Paragraph.h"
  "$include_path/modules/skparagraph/include/ParagraphBuilder.h"
  "$include_path/modules/skparagraph/include/ParagraphStyle.h"
  "$include_path/modules/skparagraph/include/TextStyle.h"
  "$include_path/modules/skparagraph/include/FontCollection.h"
)
paragraph_libs=(skparagraph skshaper skunicode_core skunicode_icu)
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
  if [[ $require_skparagraph -eq 0 && \
        ( "$paragraph_headers_status" != "available" || "$paragraph_libraries_status" != "available" ) ]]; then
    # The Skia bundle lacks SkParagraph headers or libraries (e.g. release
    # shared builds ship no libskparagraph.dylib). Emit no SKPARAGRAPH defines
    # and no -lskparagraph flags; use --require-skparagraph to fail instead.
    echo "SkParagraph headers/libraries missing in $lib_path; disabling SkParagraph (use --require-skparagraph to fail instead)" >&2
    enable_skparagraph=0
  fi
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
  native_extra_cc_flags="-DMOUI_SKIA_HAS_SKSHAPER${native_extra_cc_flags:+ $native_extra_cc_flags}"
  native_extra_link_flags="-lskshaper -lskunicode_core -lskunicode_icu -lharfbuzz -licu${native_extra_link_flags:+ $native_extra_link_flags}"
fi

cc_flags="-DMOUI_SKIA_HAS_SKIA -std=c++17 -I$include_path"
if [[ $enable_skshaper -eq 1 ]]; then
  cc_flags="$cc_flags -DMOUI_SKIA_HAS_SKSHAPER"
fi
if [[ $enable_skparagraph -eq 1 ]]; then
  cc_flags="$cc_flags -DMOUI_SKIA_HAS_SKPARAGRAPH -DMOUI_SKIA_HAS_SKSHAPER"
fi
if [[ -n "$extra_cc_flags" ]]; then
  cc_flags="$cc_flags $extra_cc_flags"
fi

link_flags="$skia_library_link_flags -lc++ -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework ImageIO -framework ApplicationServices -framework UniformTypeIdentifiers -lobjc"
if [[ -n "$skia_runtime_link_flags" ]]; then
  link_flags="$link_flags $skia_runtime_link_flags"
fi
if [[ $enable_skshaper -eq 1 ]]; then
  link_flags="$link_flags -lskshaper -lskunicode_core -lskunicode_icu -lharfbuzz -licu"
fi
if [[ $enable_skparagraph -eq 1 ]]; then
  link_flags="$link_flags -L$lib_path -lskparagraph -lskshaper -lskunicode_core -lskunicode_icu -lharfbuzz -licu"
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
  if [[ $renderer_log_is_temporary -eq 1 && -n "${renderer_log:-}" && -f "$renderer_log" ]]; then
    rm -f "$renderer_log"
  fi
  if [[ $text_emoji_log_is_temporary -eq 1 && -n "${text_emoji_log:-}" && -f "$text_emoji_log" ]]; then
    rm -f "$text_emoji_log"
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
  if [[ -f "$renderer_pkg_backup" ]]; then
    cp "$renderer_pkg_backup" "$renderer_pkg"
    rm -f "$renderer_pkg_backup"
    echo "Restored moui_tests/skia_renderer_smoke/native/moon.pkg after macOS Skia smoke."
  fi
  if [[ -f "$text_emoji_pkg_backup" ]]; then
    cp "$text_emoji_pkg_backup" "$text_emoji_pkg"
    rm -f "$text_emoji_pkg_backup"
    echo "Restored moui_tests/skia_text_emoji_smoke/native/moon.pkg after macOS Skia smoke."
  fi
}
trap restore_native_pkg EXIT

cp "$native_pkg" "$backup_pkg"
echo "Backed up native/moon.pkg to $backup_pkg."
cp "$smoke_pkg" "$smoke_backup_pkg"
echo "Backed up scripts/native_smoke/moon.pkg to $smoke_backup_pkg."

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
bash "$moui_skia_root/scripts/configure-macos-native-pkg.sh" "${configure_args[@]}" >/dev/null
echo "Wrote temporary native/moon.pkg with macOS Skia link flags."

cat > "$smoke_pkg" <<EOF
import {
  "wzzc-dev/moui_skia" @skia,
  "wzzc-dev/moui_skia/native" @native,
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

cd "$moui_skia_root/scripts/native_smoke"
moon build --target native
smoke_exe="$PWD/_build/native/debug/build/moui_skia_native_smoke"
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
  smoke_log="$(mktemp "${TMPDIR:-/tmp}/moui-skia-native-smoke.XXXXXX.log")"
  smoke_log_is_temporary=1
else
  mkdir -p "$(dirname "$smoke_log")"
  : > "$smoke_log"
fi
"$smoke_exe" 2>&1 | tee "$smoke_log"
if ! grep -Fq "moui_skia native smoke test passed" "$smoke_log"; then
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
if [[ $require_skparagraph -eq 1 ]]; then
  if ! grep -Fq "native smoke paragraph available" "$smoke_log"; then
    echo "native smoke executable did not prove the required SkParagraph path" >&2
    exit 1
  fi
  echo "Verified native SkParagraph smoke marker."
fi

if [[ $run_renderer_smoke -eq 1 ]]; then
  cp "$renderer_pkg" "$renderer_pkg_backup"
  echo "Backed up moui_tests/skia_renderer_smoke/native/moon.pkg to $renderer_pkg_backup."
  cat > "$renderer_pkg" <<EOF
import {
  "moonbitlang/core/encoding/base64",
  "moonbitlang/core/env",
  "moonbitlang/x/fs",
  "wzzc-dev/moui_skia/native" @skia_native,
  "wzzc-dev/moui/core",
  "wzzc-dev/moui/render",
  "wzzc-dev/moui/backend/common/image" @window_image,
  "wzzc-dev/moui/render/common" @render_common,
  "wzzc-dev/moui_skia_renderer" @skia_renderer,
}

supported_targets = "native"

options(
  "is-main": true,
  link: {
    "native": {
      "cc-link-flags": "$link_flags",
    },
  },
  targets: { "main.mbt": [ "native" ] },
)
EOF
  echo "Wrote temporary moui_tests/skia_renderer_smoke/native/moon.pkg with macOS Skia link flags."

  cd "$repo_root"
  MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 \
    MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 \
    moon build moui_tests/skia_renderer_smoke/native --target native
  renderer_exe="$repo_root/_build/native/debug/build/wzzc-dev/moui_tests/skia_renderer_smoke/native/native.exe"
  if [[ ! -x "$renderer_exe" ]]; then
    echo "MoUI Skia renderer smoke executable was not produced at $renderer_exe" >&2
    exit 1
  fi

  echo "Running MoUI Skia renderer smoke executable: $renderer_exe"
  if [[ -z "$renderer_log" ]]; then
    renderer_log="$(mktemp "${TMPDIR:-/tmp}/moui-skia-renderer-smoke.XXXXXX.log")"
    renderer_log_is_temporary=1
  else
    mkdir -p "$(dirname "$renderer_log")"
    : > "$renderer_log"
  fi

  set +e
  set -o pipefail
  "$renderer_exe" 2>&1 | tee "$renderer_log"
  renderer_status=${PIPESTATUS[0]}
  set +o pipefail
  set -e
  if [[ $renderer_status -ne 0 ]]; then
    exit "$renderer_status"
  fi
  if ! grep -Fq "MoUI Skia renderer smoke passed" "$renderer_log"; then
    echo "MoUI Skia renderer smoke did not print the expected success marker" >&2
    exit 1
  fi
  echo "Verified MoUI Skia renderer smoke success marker."
  if ! grep -Fq "MoUI Skia async image second-frame smoke passed" "$renderer_log"; then
    echo "MoUI Skia renderer smoke did not report async image second-frame repaint" >&2
    exit 1
  fi
  echo "Verified MoUI Skia async image second-frame marker."
  if ! grep -Fq "MoUI Skia async image deferred-completion smoke passed" "$renderer_log"; then
    echo "MoUI Skia renderer smoke did not report async image deferred-completion marker" >&2
    exit 1
  fi
  echo "Verified MoUI Skia async image deferred-completion marker."

  cp "$renderer_pkg_backup" "$renderer_pkg"
  rm -f "$renderer_pkg_backup"
  echo "Restored moui_tests/skia_renderer_smoke/native/moon.pkg after renderer smoke."
fi

if [[ $run_text_emoji_smoke -eq 1 ]]; then
  if [[ $enable_skparagraph -eq 0 && $require_skparagraph -eq 0 ]]; then
    echo "--run-text-emoji-smoke requires --enable-skparagraph or --require-skparagraph for SkParagraph bidi/emoji markers" >&2
    exit 2
  fi
  cp "$text_emoji_pkg" "$text_emoji_pkg_backup"
  echo "Backed up moui_tests/skia_text_emoji_smoke/native/moon.pkg to $text_emoji_pkg_backup."
  cat > "$text_emoji_pkg" <<EOF
import {
  "wzzc-dev/moui_skia/native" @skia_native,
  "wzzc-dev/moui/backend/common/input" @window_input,
  "wzzc-dev/moui/core",
  "wzzc-dev/moui/runtime",
  "wzzc-dev/moui_skia_renderer" @skia_renderer,
  "wzzc-dev/moui/views",
}

supported_targets = "native"

options(
  "is-main": true,
  link: {
    "native": {
      "cc-link-flags": "$link_flags",
    },
  },
  targets: { "main.mbt": [ "native" ] },
)
EOF
  echo "Wrote temporary moui_tests/skia_text_emoji_smoke/native/moon.pkg with macOS Skia link flags."

  cd "$repo_root"
  MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 \
    MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 \
    moon build moui_tests/skia_text_emoji_smoke/native --target native
  text_emoji_exe="$repo_root/_build/native/debug/build/wzzc-dev/moui_tests/skia_text_emoji_smoke/native/native.exe"
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
    "MoUI renderer smoke colorEmojiPixels passed high-saturation-pixels glyph-or-raster font-metadata glyph-metadata fallback-request emoji-hint stable-glyph-key"
    "MoUI renderer smoke zwjGrapheme passed single-grapheme-cluster no-interior-caret"
    "MoUI renderer smoke colorEmojiVariants passed keycap regional-indicator skin-tone-modifier glyph-metadata fallback-request"
    "MoUI renderer smoke paragraphWrapping passed engine=skparagraph native_paragraph_ready=true line-metrics later-line-pixels"
    "MoUI renderer smoke bidiLayout passed engine=skparagraph bidi_visual_order_ready=true visual-order"
    "MoUI renderer smoke bidiLayoutArabic passed engine=skparagraph bidi_visual_order_ready=true visual-order arabic"
    "MoUI renderer smoke bidiLayoutMixed passed engine=skparagraph bidi_visual_order_ready=true visual-order mixed-direction"
    "MoUI renderer smoke selectionRects passed engine=skparagraph selection-rects line-range rect-geometry hit-test"
    "MoUI renderer smoke graphemeEditing passed grapheme-boundaries edit-actions"
    "MoUI renderer smoke imeCandidateAnchor passed candidate-anchor surrounding-text grapheme-boundary utf8-offsets"
    "MoUI renderer smoke imeCompositionVisual passed composition-range composition-cursor preedit-pixels"
  )
  for marker in "${text_emoji_required_markers[@]}"; do
    if ! grep -Fq "$marker" "$text_emoji_log"; then
      echo "MoUI Skia text/emoji smoke did not print renderer capability marker: $marker" >&2
      exit 1
    fi
  done
  echo "Verified MoUI Skia text/emoji renderer capability markers."

  cp "$text_emoji_pkg_backup" "$text_emoji_pkg"
  rm -f "$text_emoji_pkg_backup"
  echo "Restored moui_tests/skia_text_emoji_smoke/native/moon.pkg after text/emoji smoke."
fi
