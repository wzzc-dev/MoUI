#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
WINDOW_DIR="$ROOT_DIR/.local_repos/window"
WINDOW_BRANCH="moui-support"
SKIA_MBT_DIR="$ROOT_DIR/skia_mbt"
SKIA_MBT_VERSION="0.1.2"

fail() {
  printf 'local dependency check failed: %s\n' "$1" >&2
  exit 1
}

require_text() {
  path="$1"
  text="$2"
  grep -F -q -- "$text" "$path" ||
    fail "$path must contain expected text: $text"
}

[ -d "$WINDOW_DIR/.git" ] || fail "missing .local_repos/window checkout; run sh scripts/setup-local-deps.sh"

case "$(git -C "$WINDOW_DIR" remote get-url origin 2>/dev/null || true)" in
  *wzzc-dev/window.git|*wzzc-dev/window)
    ;;
  *)
    fail ".local_repos/window origin must be the wzzc-dev/window fork over SSH or HTTPS"
    ;;
esac

case "$(git -C "$WINDOW_DIR" remote get-url upstream 2>/dev/null || true)" in
  *moonbit-community/window.git|*moonbit-community/window)
    ;;
  *)
    fail ".local_repos/window upstream remote must point at moonbit-community/window; run sh scripts/setup-local-deps.sh"
    ;;
esac

[ "$(git -C "$WINDOW_DIR" branch --show-current)" = "$WINDOW_BRANCH" ] ||
  fail ".local_repos/window must be on branch $WINDOW_BRANCH"

grep -q '"wzzc-dev/window@0.5.1"' "$ROOT_DIR/moui/moon.mod" ||
  fail "moui/moon.mod must import wzzc-dev/window@0.5.1"

if [ -f "$WINDOW_DIR/moon.mod" ]; then
  grep -q 'name = "wzzc-dev/window"' "$WINDOW_DIR/moon.mod" ||
    fail ".local_repos/window/moon.mod must declare name wzzc-dev/window"
elif [ -f "$WINDOW_DIR/moon.mod.json" ]; then
  grep -q '"name": "wzzc-dev/window"' "$WINDOW_DIR/moon.mod.json" ||
    fail ".local_repos/window/moon.mod.json must declare name wzzc-dev/window"
else
  fail ".local_repos/window must contain moon.mod or moon.mod.json"
fi

grep -q "\"wzzc-dev/skia_mbt@$SKIA_MBT_VERSION\"" "$ROOT_DIR/moui/moon.mod" ||
  fail "moui/moon.mod must import wzzc-dev/skia_mbt@$SKIA_MBT_VERSION"

grep -Eq '"(\./)?\.local_repos/window"' "$ROOT_DIR/moon.work" ||
  fail "moon.work must include .local_repos/window"

grep -Eq '"(\./)?skia_mbt"' "$ROOT_DIR/moon.work" ||
  fail "moon.work must include skia_mbt"

for pkg in core dpi web windows linux macos; do
  [ -f "$WINDOW_DIR/$pkg/moon.pkg" ] || fail "missing .local_repos/window/$pkg/moon.pkg"
done

for generated_file in \
  linux/generated/xdg-decoration-protocol.c \
  linux/generated/xdg-shell-protocol.c
do
  [ -f "$WINDOW_DIR/$generated_file" ] || fail "missing .local_repos/window/$generated_file"
done

for evidence_file in \
  docs/moui-integration-smoke.md \
  docs/platform-gaps.md \
  scripts/check_moui_readiness.sh \
  scripts/check_moui_evidence.sh \
  scripts/record_moui_evidence.sh \
  scripts/check_moui_macos_smoke.sh \
  scripts/check_moui_web_smoke.sh \
  scripts/check_moui_linux_smoke.sh \
  scripts/check_moui_windows_smoke.sh \
  scripts/check_web_assets.sh \
  scripts/smoke_runtime.sh
do
  [ -f "$WINDOW_DIR/$evidence_file" ] || fail "missing .local_repos/window/$evidence_file"
done

for evidence_file in \
  examples/window_web/index.html \
  examples/moui_web_smoke/index.html
do
  [ -f "$WINDOW_DIR/$evidence_file" ] || fail "missing .local_repos/window/$evidence_file"
done

require_text "$WINDOW_DIR/scripts/smoke_runtime.sh" \
  'run_or_print macOS scripts/check_moui_macos_smoke.sh --run'
require_text "$WINDOW_DIR/scripts/check_moui_macos_smoke.sh" \
  'moon run "$pkg" --target native'
require_text "$WINDOW_DIR/scripts/check_web_assets.sh" \
  'moon --target-dir "$ROOT/_build" build examples/window_web --target wasm-gc'
require_text "$WINDOW_DIR/scripts/check_web_assets.sh" \
  'wzzc-dev/window/examples/window_web/window_web.wasm'
require_text "$WINDOW_DIR/scripts/check_moui_web_smoke.sh" \
  'moon --target-dir "$ROOT/_build" build examples/moui_web_smoke --target wasm-gc'
require_text "$WINDOW_DIR/scripts/check_moui_web_smoke.sh" \
  'wzzc-dev/window/examples/moui_web_smoke/moui_web_smoke.wasm'
require_text "$WINDOW_DIR/examples/window_web/index.html" \
  'wzzc-dev/window/examples/window_web/window_web.wasm'
require_text "$WINDOW_DIR/examples/moui_web_smoke/index.html" \
  'wzzc-dev/window/examples/moui_web_smoke/moui_web_smoke.wasm'
require_text "$WINDOW_DIR/examples/moui_web_smoke/index.html" \
  'MOUISmoke: surface canvas_id=moui-web-smoke-canvas size=640x360'

[ -d "$SKIA_MBT_DIR" ] || fail "missing skia_mbt workspace member; update the main checkout"

grep -q 'name = "wzzc-dev/skia_mbt"' "$SKIA_MBT_DIR/moon.mod" ||
  fail "skia_mbt/moon.mod must declare name wzzc-dev/skia_mbt"
grep -q "version = \"$SKIA_MBT_VERSION\"" "$SKIA_MBT_DIR/moon.mod" ||
  fail "skia_mbt/moon.mod must declare version $SKIA_MBT_VERSION"

for pkg_file in \
  moon.pkg \
  pkg.generated.mbti \
  native/moon.pkg \
  native/pkg.generated.mbti \
  native/capabilities.json \
  native/ownership.json \
  scripts/native_smoke/main.mbt
do
  [ -f "$SKIA_MBT_DIR/$pkg_file" ] || fail "missing skia_mbt/$pkg_file"
done

for skia_evidence_file in \
  skia-platform-status.json \
  skia-provider-lock.json \
  SKIA_PLATFORM_STATUS.md \
  skia-revision.txt \
  scripts/verify-platform-status.sh \
  scripts/verify-platform-status.ps1 \
  scripts/verify-native-capability-contract.sh \
  scripts/verify-native-capability-contract.ps1 \
  scripts/verify-native-smoke-capabilities.sh \
  scripts/verify-native-smoke-capabilities.ps1 \
  scripts/verify-native-fallback-parity.sh \
  scripts/verify-native-fallback-parity.ps1 \
  scripts/verify-native-ownership.sh \
  scripts/verify-native-ownership.ps1 \
  scripts/verify-native-ffi-borrows.sh \
  scripts/verify-native-ffi-borrows.ps1 \
  scripts/verify-real-skia-artifact.sh \
  scripts/verify-real-skia-artifact.ps1 \
  scripts/verify-native-smoke-log.sh \
  scripts/verify-native-smoke-log.ps1
do
  [ -f "$SKIA_MBT_DIR/$skia_evidence_file" ] || fail "missing skia_mbt/$skia_evidence_file"
done

bash "$SKIA_MBT_DIR/scripts/verify-platform-status.sh" ||
  fail "skia_mbt platform status evidence did not validate"

bash "$SKIA_MBT_DIR/scripts/verify-native-capability-contract.sh" ||
  fail "skia_mbt native capability contract did not validate"

printf 'Local dependency check passed.\n'
