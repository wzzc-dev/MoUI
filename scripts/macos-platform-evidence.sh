#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/macos-platform-evidence.sh [options]

Collects macOS platform runtime evidence by:
1. Configuring the repository for real Skia linking (release provider)
2. Building and running the Showcase macos_skia entrypoint with the
   first-frame auto-exit marker (MOUI_FIRST_FRAME_EXIT=1)
3. Building and running the Markdown Editor macos_skia entrypoint with its
   first-frame auto-exit marker
4. Collecting evidence logs under artifacts/platform-evidence/macos/

Options:
  --log-dir PATH          Output directory for evidence logs.
                          Default: artifacts/platform-evidence/macos.
  --skia-provider release|source|existing
                          Skia acquisition mode. Default: release.
  --link-mode static|dynamic|auto
                          Skia link mode. Default: static.
  --run-showcase-smoke    Run the Showcase first-frame smoke (default: on).
  --run-markdown-smoke    Run the Markdown Editor first-frame smoke (default: on).
  --run-ime-smoke         Run the Showcase native IME runtime smoke (default: on).
  --dry-run-config        Print resolved paths and exit without building.
  -h, --help              Show this help.

Environment defaults:
  MOUI_SKIA_SKIA_PROVIDER, MOUI_SKIA_LINK_MODE are used when the matching
  command-line option is omitted.
EOF
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log_dir="$REPO_ROOT/artifacts/platform-evidence/macos"
skia_provider="${MOUI_SKIA_SKIA_PROVIDER:-release}"
skia_link_mode="${MOUI_SKIA_LINK_MODE:-static}"
run_showcase=1
run_markdown=1
run_ime=1
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
    --run-ime-smoke) run_ime=1; shift ;;
    --no-ime-smoke) run_ime=0; shift ;;
    --dry-run-config) dry_run_config=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

skia_repo="$REPO_ROOT/moui_skia"
case "$log_dir" in
  /*|?:/*) resolved_log_dir="$log_dir" ;;
  *) resolved_log_dir="$REPO_ROOT/$log_dir" ;;
esac

showcase_log="$resolved_log_dir/showcase-macos-skia-first-frame.log"
markdown_log="$resolved_log_dir/markdown-editor-macos-skia-first-frame.log"
ime_log="$resolved_log_dir/ime-showcase-runtime.log"
preflight_log="$resolved_log_dir/macos-platform-evidence-preflight.log"
summary_log="$resolved_log_dir/macos-platform-evidence-summary.log"

mkdir -p "$resolved_log_dir"

echo "macOS platform evidence run:
  log_dir=$resolved_log_dir
  skia_provider=$skia_provider
  skia_link_mode=$skia_link_mode
  run_showcase=$run_showcase
  run_markdown=$run_markdown
  run_ime=$run_ime
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
fetch_args=(
  --platform macos
  --arch auto
  --config Release
  --link-mode "$skia_link_mode"
  --print-env
)
fetch_output="$(bash "$skia_repo/scripts/fetch-release-skia.sh" "${fetch_args[@]}")"

extract_env() {
  printf '%s\n' "$fetch_output" | sed -n "s/^${1}=//p" | tail -n 1
}

skia_include="$(extract_env MOUI_SKIA_SKIA_INCLUDE)"
skia_lib_dir="$(extract_env MOUI_SKIA_SKIA_LIB_DIR)"
skia_lib="$(extract_env MOUI_SKIA_SKIA_LIB)"
skia_commit="$(extract_env MOUI_SKIA_SKIA_COMMIT)"

echo "  skia_include=$skia_include
  skia_lib_dir=$skia_lib_dir
  skia_lib=$skia_lib
  skia_commit=$skia_commit" | tee -a "$preflight_log"

if [[ -z "$skia_include" || -z "$skia_lib_dir" || -z "$skia_lib" ]]; then
  echo "Skia provider did not resolve complete paths" >&2
  exit 1
fi

#
# Step 2: Configure moui_skia/native/moon.pkg
#
echo "=== Step 2: Configure moui_skia/native/moon.pkg ===" | tee -a "$preflight_log"
bash "$skia_repo/scripts/configure-macos-native-pkg.sh" \
  --skia-include "$skia_include" \
  --skia-lib-dir "$skia_lib_dir" \
  --skia-lib "$skia_lib" \
  --link-mode "$skia_link_mode" \
  --write >/dev/null

echo "  Configured moui_skia/native/moon.pkg" | tee -a "$preflight_log"

generated_output="$(bash "$skia_repo/scripts/configure-macos-native-pkg.sh" \
  --skia-include "$skia_include" \
  --skia-lib-dir "$skia_lib_dir" \
  --skia-lib "$skia_lib" \
  --link-mode "$skia_link_mode")"

macos_link_flags="$(printf '%s\n' "$generated_output" | sed -n 's/.*"cc-link-flags": "\(.*\)",/\1/p')"
macos_stub_cc_flags="$(printf '%s\n' "$generated_output" | sed -n 's/.*"stub-cc-flags": "\(.*\)",/\1/p')"

echo "  Skia link flags: $macos_link_flags
  Stub CC flags: $macos_stub_cc_flags" | tee -a "$preflight_log"

#
# Step 3: Configure example macos_skia moon.pkg
#
echo "=== Step 3: Configure example macos_skia moon.pkg ===" | tee -a "$preflight_log"

showcase_pkg="$REPO_ROOT/examples/showcase/macos_skia/moon.pkg"
showcase_backup="$showcase_pkg.moui-evidence.bak"
markdown_pkg="$REPO_ROOT/examples/markdown_editor/macos_skia/moon.pkg"
markdown_backup="$markdown_pkg.moui-evidence.bak"
cp "$showcase_pkg" "$showcase_backup"
if [[ -f "$markdown_pkg" ]]; then
  cp "$markdown_pkg" "$markdown_backup"
fi

cat > "$showcase_pkg" <<PKGEOF
import {
  "wzzc-dev/moui/runtime",
  "wzzc-dev/moui/backend/macos" @macos_backend,
  "wzzc-dev/moui_skia_renderer" @render_skia,
  "examples/showcase",
}

supported_targets = "native"

pkgtype(kind: "executable")

options(
  link: {
    "native": {
      "stub-cc-flags": "$macos_stub_cc_flags",
      "cc-link-flags": "$macos_link_flags",
    },
  },
  targets: { "main.mbt": [ "native" ] },
)
PKGEOF
echo "  Wrote $showcase_pkg" | tee -a "$preflight_log"

if [[ -f "$markdown_pkg" ]]; then
  cat > "$markdown_pkg" <<PKGEOF
import {
  "wzzc-dev/moui/runtime",
  "wzzc-dev/moui/backend/macos" @macos_host,
  "wzzc-dev/moui_skia_renderer" @render_skia,
  "wzzc-dev/window/dpi",
  "examples/markdown_editor",
}

supported_targets = "native"

pkgtype(kind: "executable")

options(
  link: {
    "native": {
      "stub-cc-flags": "$macos_stub_cc_flags",
      "cc-link-flags": "$macos_link_flags",
    },
  },
  targets: { "main.mbt": [ "native" ] },
)
PKGEOF
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
# Step 4: Build showcase
#
echo "=== Step 4: Build showcase macos_skia ===" | tee -a "$preflight_log"

cd "$REPO_ROOT"
MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 \
  MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 \
  moon build examples/showcase/macos_skia --target native 2>&1 | tee -a "$preflight_log"
echo "  Built examples/showcase/macos_skia" | tee -a "$preflight_log"

#
# Step 5: Run Showcase with first-frame auto-exit
#
showcase_status="skipped"
if [[ $run_showcase -eq 1 ]]; then
  echo "=== Step 5: Run Showcase first-frame smoke ===" | tee -a "$preflight_log"
  cd "$REPO_ROOT"
  MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 \
    MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 \
    MOUI_FIRST_FRAME_EXIT=1 \
    moon run examples/showcase/macos_skia --target native \
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
  if grep -Fq "macOS renderer presented first frame; exiting by request; title=MoUI Showcase" "$showcase_log"; then
    echo "  Verified Showcase first-frame marker." | tee -a "$preflight_log"
  else
    echo "  WARNING: Showcase first-frame marker not found." | tee -a "$preflight_log"
  fi
fi

#
# Step 6: Optional Markdown Editor first-frame smoke
#
markdown_status="skipped"
if [[ $run_markdown -eq 1 ]]; then
  echo "=== Step 6: Run Markdown Editor first-frame smoke ===" | tee -a "$preflight_log"
  cd "$REPO_ROOT"
  if [[ -d "$REPO_ROOT/examples/markdown_editor/macos_skia" ]]; then
    MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 \
      MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 \
      MOUI_MARKDOWN_EDITOR_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT=1 \
      moon run examples/markdown_editor/macos_skia --target native \
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
    if grep -Fq "macOS renderer presented first frame; exiting by request; title=MoUI Markdown Editor" "$markdown_log"; then
      echo "  Verified Markdown Editor first-frame marker." | tee -a "$preflight_log"
    else
      echo "  WARNING: Markdown Editor first-frame marker not found." | tee -a "$preflight_log"
    fi
  else
    echo "  examples/markdown_editor/macos_skia not present; skipping." \
      | tee -a "$preflight_log"
    markdown_status="absent"
  fi
fi

#
# Step 7: Optional Showcase native IME runtime smoke
#
ime_status="skipped"
if [[ $run_ime -eq 1 ]]; then
  echo "=== Step 7: Run Showcase native IME runtime smoke ===" | tee -a "$preflight_log"
  cd "$REPO_ROOT"
  MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 \
    MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 \
    MOUI_MACOS_NATIVE_IME_EVIDENCE=1 \
    moon run examples/showcase/macos_skia --target native \
    > "$ime_log" 2>&1 &
  ime_pid=$!

  (
    sleep 60
    if kill -0 "$ime_pid" 2>/dev/null; then
      echo "Showcase IME smoke timed out after 60s" >> "$ime_log"
      kill "$ime_pid" 2>/dev/null
    fi
  ) &
  ime_watchdog=$!
  wait "$ime_pid"
  ime_status=$?
  kill "$ime_watchdog" 2>/dev/null || true
  wait "$ime_watchdog" 2>/dev/null || true

  echo "  IME smoke exit status: $ime_status" | tee -a "$preflight_log"
  ime_markers=0
  if grep -q "NSTextInputClient" "$ime_log"; then ime_markers=$((ime_markers + 1)); fi
  if grep -q "appkit-setMarkedText" "$ime_log"; then ime_markers=$((ime_markers + 1)); fi
  if grep -q "appkit-firstRectForCharacterRange" "$ime_log"; then ime_markers=$((ime_markers + 1)); fi
  if grep -q "appkit-insertText" "$ime_log"; then ime_markers=$((ime_markers + 1)); fi
  echo "  Observed IME markers: $ime_markers/4" | tee -a "$preflight_log"
fi

#
# Step 8: Generate summary
#
echo "=== Step 8: Generate evidence summary ===" | tee -a "$preflight_log"
{
  echo "macOS platform evidence summary:"
  echo "  skia_commit=$skia_commit"
  echo "  showcase_first_frame_status=$(grep -Fq "macOS renderer presented first frame; exiting by request; title=MoUI Showcase" "$showcase_log" 2>/dev/null && echo "passed" || echo "failed")"
  echo "  markdown_first_frame_status=$(if [[ "$markdown_status" == "passed" || "$markdown_status" == "skipped" || "$markdown_status" == "absent" ]]; then echo "$markdown_status"; elif grep -Fq "macOS renderer presented first frame; exiting by request; title=MoUI Markdown Editor" "$markdown_log" 2>/dev/null; then echo "passed"; else echo "failed"; fi)"
  echo "  ime_runtime_markers=$(grep -q "NSTextInputClient" "$ime_log" 2>/dev/null && echo "present" || echo "missing")"
  echo "  preflight_log=$preflight_log"
  echo "  showcase_log=$showcase_log"
  echo "  markdown_log=$markdown_log"
  echo "  ime_log=$ime_log"
  echo "  summary_log=$summary_log"
} | tee "$summary_log"

echo ""
echo "macOS platform evidence collected. Logs:"
echo "  Showcase:           $showcase_log"
echo "  Markdown Editor:    $markdown_log"
echo "  IME runtime:        $ime_log"
echo "  Summary:            $summary_log"
echo "  Preflight:          $preflight_log"
