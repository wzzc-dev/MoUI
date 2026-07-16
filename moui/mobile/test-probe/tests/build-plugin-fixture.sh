#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: moui/mobile/test-probe/tests/build-plugin-fixture.sh <android|ios|harmonyos> [build options]

Build MoUI Showcase through the managed canonical shell with the
repository-only mobile test-probe plugin. Additional options are forwarded to
the platform build command; use --fallback-skia for packaging CI.
USAGE
}

if [ "$#" -lt 1 ]; then
  usage >&2
  exit 2
fi

platform="$1"
shift
case "$platform" in
  android|ios|harmonyos) ;;
  *) usage >&2; exit 2 ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
artifact_root="${MOUI_MOBILE_SHELL_CI_ROOT:-$repo_root/artifacts/mobile-shell-ci}"
config="$repo_root/examples/showcase/.mobile-test-probe-build-$$.json"

cleanup() {
  rm -f "$config"
}
trap cleanup EXIT

node "$repo_root/moui/mobile/test-probe/tests/create-mobile-shell-fixture.mjs" \
  --kind plugin-config \
  --repo-root "$repo_root" \
  --output "$config"

case "$platform" in
  android)
    "$repo_root/moui/scripts/mobile/build-android-apk.sh" \
      --workspace-root "$repo_root" \
      --moui-root "$repo_root/moui" \
      --skia-root "$repo_root/moui_skia" \
      --app showcase \
      --app-config "$config" \
      --build-dir "$artifact_root/android/plugin" \
      --output "$artifact_root/android/plugin/MoUIShowcase.apk" \
      "$@"
    ;;
  ios)
    XCODE_XCCONFIG_FILE="${XCODE_XCCONFIG_FILE:-$repo_root/moui/mobile/test-probe/tests/NoCodeSign.xcconfig}" \
      "$repo_root/moui/scripts/mobile/build-ios-app.sh" \
      --workspace-root "$repo_root" \
      --moui-root "$repo_root/moui" \
      --skia-root "$repo_root/moui_skia" \
      --app showcase \
      --app-config "$config" \
      --build-dir "$artifact_root/ios/plugin" \
      --output "$artifact_root/ios/plugin/MoUIShowcase.app" \
      "$@"
    ;;
  harmonyos)
    "$repo_root/moui/scripts/mobile/build-harmonyos-hap.sh" \
      --workspace-root "$repo_root" \
      --moui-root "$repo_root/moui" \
      --skia-root "$repo_root/moui_skia" \
      --app showcase \
      --app-config "$config" \
      --build-dir "$artifact_root/harmonyos/plugin" \
      --output "$artifact_root/harmonyos/plugin/MoUIShowcase.hap" \
      "$@"
    ;;
esac
