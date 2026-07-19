#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: moui_shell/test_probe/tests/build-plugin-fixture.sh <android|ios|harmonyos> [build options]

Build MoUI Showcase through the managed canonical shell with the
repository-only shell test-probe plugin. Additional options are forwarded to
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

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
artifact_root="${MOUI_EMBEDDING_SHELL_CI_ROOT:-$repo_root/artifacts/shell-ci}"
config="$repo_root/examples/showcase/.shell-test-probe-build-$$.json"

cleanup() {
  rm -f "$config"
}
trap cleanup EXIT

node "$repo_root/moui_shell/test_probe/tests/create-shell-fixture.mjs" \
  --kind plugin-config \
  --repo-root "$repo_root" \
  --output "$config"

case "$platform" in
  android)
    bash "$repo_root/moui_shell/scripts/build-android-apk.sh" \
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
    XCODE_XCCONFIG_FILE="${XCODE_XCCONFIG_FILE:-$repo_root/moui_shell/test_probe/tests/NoCodeSign.xcconfig}" \
      bash "$repo_root/moui_shell/scripts/build-ios-app.sh" \
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
    bash "$repo_root/moui_shell/scripts/build-harmonyos-hap.sh" \
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
