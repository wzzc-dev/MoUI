#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
WINDOW_VERSION="0.5.1-fork.3"
WINDOW_PACKAGE="wzzc-dev/window@$WINDOW_VERSION"
MOUI_SKIA_DIR="$ROOT_DIR/moui_skia"
MOUI_SKIA_VERSION="0.1.2"

fail() {
  printf 'dependency check failed: %s\n' "$1" >&2
  exit 1
}

warn() {
  printf 'dependency check warning: %s\n' "$1" >&2
}

require_text() {
  path="$1"
  text="$2"
  grep -F -q -- "$text" "$path" ||
    fail "$path must contain expected text: $text"
}

require_zip_entry() {
  zip_path="$1"
  entry="$2"
  unzip -l "$zip_path" "$entry" >/dev/null ||
    fail "$WINDOW_PACKAGE package cache is missing $entry"
}

require_text "$ROOT_DIR/moui/moon.mod" "\"$WINDOW_PACKAGE\""
require_text "$ROOT_DIR/moui_skia/moon.mod" "\"$WINDOW_PACKAGE\""

if grep -Eq '"(\./)?\.local_repos/window"' "$ROOT_DIR/moon.work"; then
  fail "moon.work must not include .local_repos/window; window resolves from $WINDOW_PACKAGE"
fi

grep -Eq '"(\./)?moui_skia"' "$ROOT_DIR/moon.work" ||
  fail "moon.work must include moui_skia"

require_text "$ROOT_DIR/moui/moon.mod" "\"wzzc-dev/moui_skia@$MOUI_SKIA_VERSION\""

window_zip="${MOUI_WINDOW_PACKAGE_ZIP:-$HOME/.moon/registry/cache/wzzc-dev/window/$WINDOW_VERSION.zip}"
if [ -f "$window_zip" ]; then
  for entry in \
    moon.mod \
    core/moon.pkg \
    dpi/moon.pkg \
    web/moon.pkg \
    windows/moon.pkg \
    linux/moon.pkg \
    macos/moon.pkg \
    linux/generated/xdg-decoration-protocol.c \
    linux/generated/xdg-shell-protocol.c \
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
    scripts/smoke_runtime.sh \
    examples/window_web/index.html \
    examples/moui_web_smoke/index.html
  do
    require_zip_entry "$window_zip" "$entry"
  done
else
  warn "$WINDOW_PACKAGE is not present in the local MoonBit registry cache; run moon update before package-level window smoke checks"
fi

[ -d "$MOUI_SKIA_DIR" ] || fail "missing moui_skia workspace member; update the main checkout"

require_text "$MOUI_SKIA_DIR/moon.mod" 'name = "wzzc-dev/moui_skia"'
require_text "$MOUI_SKIA_DIR/moon.mod" "version = \"$MOUI_SKIA_VERSION\""

for pkg_file in \
  moon.pkg \
  pkg.generated.mbti \
  native/moon.pkg \
  native/pkg.generated.mbti \
  native/capabilities.json \
  native/ownership.json \
  scripts/native_smoke/main.mbt
do
  [ -f "$MOUI_SKIA_DIR/$pkg_file" ] || fail "missing moui_skia/$pkg_file"
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
  [ -f "$MOUI_SKIA_DIR/$skia_evidence_file" ] || fail "missing moui_skia/$skia_evidence_file"
done

bash "$MOUI_SKIA_DIR/scripts/verify-platform-status.sh" ||
  fail "moui_skia platform status evidence did not validate"

bash "$MOUI_SKIA_DIR/scripts/verify-native-capability-contract.sh" ||
  fail "moui_skia native capability contract did not validate"

printf 'Dependency check passed.\n'
