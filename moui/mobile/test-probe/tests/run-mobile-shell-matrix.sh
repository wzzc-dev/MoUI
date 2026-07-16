#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: moui/mobile/test-probe/tests/run-mobile-shell-matrix.sh <android|ios|harmonyos> [options]

Options:
  --mode <name>       static, managed, plugin, ejected, legacy, or all. Default all.
  --fallback-skia     Build packaging fixtures without real Skia.
  --prepare-only      Prepare platform inputs without completing platform builds.
  -h, --help          Show this help.
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

mode="all"
build_args=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode) mode="${2:?missing value after --mode}"; shift 2 ;;
    --fallback-skia|--prepare-only) build_args+=("$1"); shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done
case "$mode" in
  static|managed|plugin|ejected|legacy|all) ;;
  *) echo "unknown matrix mode: $mode" >&2; exit 2 ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
artifact_root="${MOUI_MOBILE_SHELL_CI_ROOT:-$repo_root/artifacts/mobile-shell-ci}"
legacy_config="$repo_root/moui/mobile/legacy/fixtures/showcase.mobile.json"

run_static() {
  node --test "$repo_root/moui/scripts/mobile/plugin-manifest.test.mjs"
  node --test "$repo_root/moui/mobile/android/prepare-plugins.test.mjs"
  node --test "$repo_root/moui/mobile/test-probe/tests/validate-test-probe.mjs"
  case "$platform" in
    ios) "$repo_root/moui/mobile/ios/tests/run-ios-managed-shell-tests.sh" ;;
    harmonyos) "$repo_root/moui/mobile/harmonyos/tests/run-harmonyos-managed-shell-tests.sh" ;;
    android)
      node --test "$repo_root/moui/scripts/mobile/android-ndk.test.mjs"
      node --test "$repo_root/moui/mobile/android/resolve-managed-shell.test.mjs"
      node "$repo_root/scripts/check-mobile-app-config.mjs"
      ;;
  esac
}

run_managed() {
  case "$platform" in
    android)
      "$repo_root/moui/scripts/mobile/build-android-apk.sh" \
        --workspace-root "$repo_root" --moui-root "$repo_root/moui" \
        --skia-root "$repo_root/moui_skia" --app showcase \
        --app-config "$repo_root/examples/showcase/mobile.json" \
        --build-dir "$artifact_root/android/managed" \
        --output "$artifact_root/android/managed/MoUIShowcase.apk" \
        "${build_args[@]}"
      ;;
    ios)
      XCODE_XCCONFIG_FILE="${XCODE_XCCONFIG_FILE:-$repo_root/moui/mobile/test-probe/tests/NoCodeSign.xcconfig}" \
        "$repo_root/moui/scripts/mobile/build-ios-app.sh" \
        --workspace-root "$repo_root" --moui-root "$repo_root/moui" \
        --skia-root "$repo_root/moui_skia" --app showcase \
        --app-config "$repo_root/examples/showcase/mobile.json" \
        --build-dir "$artifact_root/ios/managed" \
        --output "$artifact_root/ios/managed/MoUIShowcase.app" \
        "${build_args[@]}"
      ;;
    harmonyos)
      "$repo_root/moui/scripts/mobile/build-harmonyos-hap.sh" \
        --workspace-root "$repo_root" --moui-root "$repo_root/moui" \
        --skia-root "$repo_root/moui_skia" --app showcase \
        --app-config "$repo_root/examples/showcase/mobile.json" \
        --build-dir "$artifact_root/harmonyos/managed" \
        --output "$artifact_root/harmonyos/managed/MoUIShowcase.hap" \
        "${build_args[@]}"
      ;;
  esac
}

run_plugin() {
  "$repo_root/moui/mobile/test-probe/tests/build-plugin-fixture.sh" \
    "$platform" "${build_args[@]}"
}

run_ejected() {
  "$repo_root/moui/mobile/test-probe/tests/build-clean-ejected-fixture.sh" \
    "$platform" "${build_args[@]}"
}

run_legacy() {
  case "$platform" in
    android)
      "$repo_root/moui/scripts/mobile/build-android-apk.sh" \
        --workspace-root "$repo_root" --moui-root "$repo_root/moui" \
        --skia-root "$repo_root/moui_skia" --app showcase \
        --app-config "$legacy_config" \
        --android-project "$repo_root/examples/showcase/android_app" \
        --legacy-java-shell --compile-sdk 35 \
        --build-dir "$artifact_root/android/legacy" \
        --output "$artifact_root/android/legacy/MoUIShowcase.apk" \
        "${build_args[@]}"
      ;;
    ios)
      XCODE_XCCONFIG_FILE="${XCODE_XCCONFIG_FILE:-$repo_root/moui/mobile/test-probe/tests/NoCodeSign.xcconfig}" \
        "$repo_root/moui/scripts/mobile/build-ios-app.sh" \
        --workspace-root "$repo_root" --moui-root "$repo_root/moui" \
        --skia-root "$repo_root/moui_skia" --app showcase \
        --app-config "$legacy_config" \
        --xcode-project "$repo_root/examples/showcase/ios_app/MoUIShowcase.xcodeproj" \
        --scheme MoUIShowcase --product-name MoUIShowcase \
        --legacy-uikit-shell \
        --build-dir "$artifact_root/ios/legacy" \
        --output "$artifact_root/ios/legacy/MoUIShowcase.app" \
        "${build_args[@]}"
      ;;
    harmonyos)
      MOUI_MOBILE_SHELL_CI_ROOT="$artifact_root" \
        "$repo_root/moui/mobile/harmonyos/tests/build-legacy-fixture.sh" \
        "${build_args[@]}"
      ;;
  esac
}

cd "$repo_root"
if [ "$mode" = "all" ]; then
  run_static
  run_managed
  run_plugin
  run_ejected
  run_legacy
else
  "run_$mode"
fi
