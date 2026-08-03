#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/windows-platform-evidence.sh [options]

Collects Windows platform runtime evidence by:
1. Configuring the repository for real Skia linking (release provider)
2. Building and running the Showcase windows_skia entrypoint with the
   first-frame auto-exit marker (MOUI_FIRST_FRAME_EXIT=1)
3. Building and running the Markdown Editor windows_skia entrypoint with its
   first-frame auto-exit marker
4. Collecting evidence logs under artifacts/platform-evidence/windows/

Options:
  --log-dir PATH          Output directory for evidence logs.
                          Default: artifacts/platform-evidence/windows.
  --skia-provider release|source|existing
                          Skia acquisition mode. Default: release.
  --link-mode static|dynamic|auto
                          Skia link mode. Default: static.
  --run-showcase-smoke    Run the Showcase first-frame smoke (default: on).
  --run-markdown-smoke    Run the Markdown Editor first-frame smoke (default: on).
  --dry-run-config        Print resolved paths and exit without building.
  -h, --help              Show this help.

Environment defaults:
  MOUI_SKIA_SKIA_PROVIDER, MOUI_SKIA_LINK_MODE are used when the matching
  command-line option is omitted.
EOF
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log_dir="$REPO_ROOT/artifacts/platform-evidence/windows"
skia_provider="${MOUI_SKIA_SKIA_PROVIDER:-release}"
skia_link_mode="${MOUI_SKIA_LINK_MODE:-static}"
run_showcase=1
run_markdown=1
dry_run_config=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --log-dir) log_dir="${2:-}"; shift 2 ;;
    --skia-provider) skia_provider="${2:-}"; shift 2 ;;
    --link-mode) skia_link_mode="${2:-}"; shift 2 ;;
    --run-showcase-smoke) run_showcase=1; shift ;;
    --no-showcase-smoke) run_showcase=0; shift ;;
    --run-markdown-smoke) run_markdown=1; shift ;;
    --no-markdown-smoke) run_markdown=0; shift ;;
    --dry-run-config) dry_run_config=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

skia_repo="$REPO_ROOT/moui_skia"
case "$log_dir" in
  /*) resolved_log_dir="$log_dir" ;;
  *) if [[ "$log_dir" =~ ^[A-Za-z]:[\\/].* ]]; then
       if command -v cygpath >/dev/null 2>&1; then
         resolved_log_dir="$(cygpath -u "$log_dir")"
       else
         resolved_log_dir="$log_dir"
       fi
     else
       resolved_log_dir="$REPO_ROOT/$log_dir"
     fi ;;
esac

showcase_log="$resolved_log_dir/showcase-windows-skia-first-frame.log"
markdown_log="$resolved_log_dir/markdown-editor-windows-skia-first-frame.log"
preflight_log="$resolved_log_dir/windows-platform-evidence-preflight.log"
summary_log="$resolved_log_dir/windows-platform-evidence-summary.log"

mkdir -p "$resolved_log_dir"

echo "Windows platform evidence run:
  log_dir=$resolved_log_dir
  skia_provider=$skia_provider
  skia_link_mode=$skia_link_mode
  run_showcase=$run_showcase
  run_markdown=$run_markdown
" | tee "$preflight_log"

if [[ $dry_run_config -eq 1 ]]; then
  echo "Dry run; no operations performed." | tee -a "$preflight_log"
  exit 0
fi

mkdir -p "$resolved_log_dir"

#
# Step 1: Fetch release Skia and configure moui_skia/native/moon.pkg
#
echo "=== Step 1: Fetch release Skia provider ===" | tee -a "$preflight_log"

# On Windows we delegate to PowerShell helpers that already know how to
# download the release archive and resolve MSVC paths.
env_lines="$(powershell -NoProfile -ExecutionPolicy Bypass -File \
  "$skia_repo/scripts/fetch-release-skia.ps1" \
  -Platform windows -Arch auto -Config Release \
  -LinkMode "$skia_link_mode" -PrintEnv 2>/dev/null || true)"

extract_env() {
  printf '%s\n' "$env_lines" | sed -n "s/^${1}=//p" | tail -n 1
}

skia_root="$(extract_env MOUI_SKIA_SKIA_ROOT)"
skia_include="$(extract_env MOUI_SKIA_SKIA_INCLUDE)"
skia_lib_dir="$(extract_env MOUI_SKIA_SKIA_LIB_DIR)"
skia_lib="$(extract_env MOUI_SKIA_SKIA_LIB)"
skia_commit="$(extract_env MOUI_SKIA_SKIA_COMMIT)"

echo "  skia_root=$skia_root
  skia_include=$skia_include
  skia_lib_dir=$skia_lib_dir
  skia_lib=$skia_lib
  skia_commit=$skia_commit" | tee -a "$preflight_log"

if [[ -z "$skia_root" || -z "$skia_include" || -z "$skia_lib_dir" ]]; then
  echo "Skia provider did not resolve complete paths" >&2
  echo "windows-platform-evidence.sh expects to be run inside moui_skia CI context" >&2
  echo "Use the moui-skia-provider-windows-real-skia-manual workflow for full provider setup." >&2
  exit 1
fi

#
# Step 2: Configure moui_skia/native/moon.pkg with release link flags
#
echo "=== Step 2: Configure moui_skia/native/moon.pkg ===" | tee -a "$preflight_log"

# Use the MSVC configurator so Skia headers are compiled with the required
# C++ standard and SkParagraph native/unavailable files are target-gated.
powershell -NoProfile -ExecutionPolicy Bypass -File \
  "$skia_repo/scripts/configure-windows-msvc-native-pkg.ps1" \
  -SkiaRoot "$skia_root" \
  -SkiaInclude "$skia_include" \
  -SkiaLibDir "$skia_lib_dir" \
  -SkiaLinkMode "$skia_link_mode" \
  -Write 2>&1 | tee -a "$preflight_log"

#
# Step 3: Compute stub-cc-flags / cc-link-flags for example packages
#
echo "=== Step 3: Resolve example link flags ===" | tee -a "$preflight_log"

generated_output="$(powershell -NoProfile -ExecutionPolicy Bypass -File \
  "$skia_repo/scripts/configure-windows-msvc-native-pkg.ps1" \
  -SkiaRoot "$skia_root" \
  -SkiaInclude "$skia_include" \
  -SkiaLibDir "$skia_lib_dir" \
  -SkiaLinkMode "$skia_link_mode" 2>/dev/null)"

windows_link_flags="$(printf '%s\n' "$generated_output" | sed -n 's/.*"cc-link-flags": "\(.*\)",/\1/p' | tr -d '\r')"
windows_stub_cc_flags="$(printf '%s\n' "$generated_output" | sed -n 's/.*"stub-cc-flags": "\(.*\)",/\1/p' | tr -d '\r')"

echo "  Skia link flags: $windows_link_flags
  Stub CC flags: $windows_stub_cc_flags" | tee -a "$preflight_log"

#
# Step 4: Configure example windows_skia moon.pkg
#
echo "=== Step 4: Configure example windows_skia moon.pkg ===" | tee -a "$preflight_log"

showcase_pkg="$REPO_ROOT/examples/showcase/windows_skia/moon.pkg"
showcase_backup="$showcase_pkg.moui-evidence.bak"
markdown_pkg="$REPO_ROOT/examples/markdown_editor/windows_skia/moon.pkg"
markdown_backup="$markdown_pkg.moui-evidence.bak"
cp "$showcase_pkg" "$showcase_backup"
if [[ -f "$markdown_pkg" ]]; then
  cp "$markdown_pkg" "$markdown_backup"
fi

write_example_pkg() {
  local pkg_path="$1"
  local app_import="$2"
  local app_alias="$3"
  local backend_alias="$4"
  local host_import="$5"

  cat > "$pkg_path" <<PKGEOF
import {
  "moonbitlang/core/env",
  "wzzc-dev/moui" @moui,
  "wzzc-dev/moui/runtime",
${host_import}
  "wzzc-dev/moui/backend/windows" @${backend_alias},
  "wzzc-dev/moui/render/skia" @render_skia,
  "${app_import}" @${app_alias},
}

supported_targets = "native"

options(
  "is-main": true,
  link: {
    "native": {
      "stub-cc-flags": "$windows_stub_cc_flags",
      "cc-link-flags": "$windows_link_flags",
    },
  },
  targets: { "main.mbt": [ "native" ] },
)
PKGEOF
}

write_example_pkg \
  "$showcase_pkg" \
  "examples/showcase/app" \
  "showcase_app" \
  "windows_backend" \
  ""
echo "  Wrote $showcase_pkg" | tee -a "$preflight_log"

if [[ -f "$markdown_pkg" ]]; then
  write_example_pkg \
    "$markdown_pkg" \
    "examples/markdown_editor/app" \
    "markdown_app" \
    "windows_host" \
    '  "wzzc-dev/moui/backend/host",'
  echo "  Wrote $markdown_pkg" | tee -a "$preflight_log"
fi

restore_example_pkgs() {
  if [[ -f "$showcase_backup" ]]; then
    cp "$showcase_backup" "$showcase_pkg"
    rm -f "$showcase_backup"
    echo "Restored $showcase_pkg"
  fi
  if [[ -f "$markdown_backup" ]]; then
    cp "$markdown_backup" "$markdown_pkg"
    rm -f "$markdown_backup"
    echo "Restored $markdown_pkg"
  fi
  cd "$REPO_ROOT"
  git checkout -- moui_skia/native/moon.pkg 2>/dev/null || true
}
trap restore_example_pkgs EXIT

#
# Step 5: Build showcase
#
echo "=== Step 5: Build showcase windows_skia ===" | tee -a "$preflight_log"

cd "$REPO_ROOT"
MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 \
  MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 \
  moon build examples/showcase/windows_skia --target native 2>&1 \
  | tee -a "$preflight_log"
echo "  Built examples/showcase/windows_skia" | tee -a "$preflight_log"

#
# Step 6: Run Showcase with first-frame auto-exit
#
showcase_status="skipped"
if [[ $run_showcase -eq 1 ]]; then
  echo "=== Step 6: Run Showcase first-frame smoke ===" | tee -a "$preflight_log"
  cd "$REPO_ROOT"
  MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 \
    MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 \
    MOUI_FIRST_FRAME_EXIT=1 \
    moon run examples/showcase/windows_skia --target native \
    > "$showcase_log" 2>&1 &
  showcase_pid=$!

  (
    sleep 60
    if kill -0 "$showcase_pid" 2>/dev/null; then
      echo "Showcase first-frame smoke timed out after 60s" >> "$showcase_log"
      kill "$showcase_pid" 2>/dev/null
    fi
  ) &
  watchdog_pid=$!
  wait "$showcase_pid"
  showcase_status=$?
  kill "$watchdog_pid" 2>/dev/null || true
  wait "$watchdog_pid" 2>/dev/null || true

  echo "  Showcase exit status: $showcase_status" | tee -a "$preflight_log"
  if grep -Fq "Windows renderer presented first frame; exiting by request; title=MoUI Showcase" "$showcase_log"; then
    echo "  Verified Showcase first-frame marker." | tee -a "$preflight_log"
  else
    echo "  WARNING: Showcase first-frame marker not found." | tee -a "$preflight_log"
  fi
fi

#
# Step 7: Optional Markdown Editor first-frame smoke
#
markdown_status="skipped"
if [[ $run_markdown -eq 1 ]]; then
  echo "=== Step 7: Run Markdown Editor first-frame smoke ===" | tee -a "$preflight_log"
  cd "$REPO_ROOT"
  if [[ -d "$REPO_ROOT/examples/markdown_editor/windows_skia" ]]; then
    MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 \
      MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 \
      MOUI_MARKDOWN_EDITOR_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT=1 \
      moon run examples/markdown_editor/windows_skia --target native \
      > "$markdown_log" 2>&1 &
    markdown_pid=$!

    (
      sleep 60
      if kill -0 "$markdown_pid" 2>/dev/null; then
        echo "Markdown Editor first-frame smoke timed out after 60s" >> "$markdown_log"
        kill "$markdown_pid" 2>/dev/null
      fi
    ) &
    markdown_watchdog=$!
    wait "$markdown_pid"
    markdown_status=$?
    kill "$markdown_watchdog" 2>/dev/null || true
    wait "$markdown_watchdog" 2>/dev/null || true

    echo "  Markdown Editor exit status: $markdown_status" | tee -a "$preflight_log"
    if grep -Fq "Windows renderer presented first frame; exiting by request; title=MoUI Markdown Editor" "$markdown_log"; then
      echo "  Verified Markdown Editor first-frame marker." | tee -a "$preflight_log"
    else
      echo "  WARNING: Markdown Editor first-frame marker not found." | tee -a "$preflight_log"
    fi
  else
    echo "  examples/markdown_editor/windows_skia not present; skipping." \
      | tee -a "$preflight_log"
    markdown_status="absent"
  fi
fi

#
# Step 8: Generate summary
#
echo "=== Step 8: Generate evidence summary ===" | tee -a "$preflight_log"
{
  echo "Windows platform evidence summary:"
  echo "  skia_commit=$skia_commit"
  echo "  showcase_first_frame_status=$(if grep -Fq "Windows renderer presented first frame; exiting by request; title=MoUI Showcase" "$showcase_log" 2>/dev/null; then echo "passed"; else echo "failed"; fi)"
  echo "  markdown_first_frame_status=$(if [[ "$markdown_status" == "passed" || "$markdown_status" == "skipped" || "$markdown_status" == "absent" ]]; then echo "$markdown_status"; elif grep -Fq "Windows renderer presented first frame; exiting by request; title=MoUI Markdown Editor" "$markdown_log" 2>/dev/null; then echo "passed"; else echo "failed"; fi)"
  echo "  preflight_log=$preflight_log"
  echo "  showcase_log=$showcase_log"
  echo "  markdown_log=$markdown_log"
  echo "  summary_log=$summary_log"
} | tee "$summary_log"

echo ""
echo "Windows platform evidence collected. Logs:"
echo "  Showcase:           $showcase_log"
echo "  Markdown Editor:    $markdown_log"
echo "  Summary:            $summary_log"
echo "  Preflight:          $preflight_log"
