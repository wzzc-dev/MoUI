#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: moui_shell/test_probe/tests/run-shell-matrix.sh <android|ios|harmonyos> [options]

Options:
  --mode <name>       static, managed, plugin, ejected, or all. Default all.
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
  static|managed|plugin|ejected|all) ;;
  *) echo "unknown matrix mode: $mode" >&2; exit 2 ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
artifact_root="${MOUI_EMBEDDING_SHELL_CI_ROOT:-$repo_root/artifacts/shell-ci}"
export MOUI_EMBEDDING_SHELL_CI_ROOT="$artifact_root"

run_static() {
  node --test "$repo_root/moui_shell/scripts/plugin-manifest.test.mjs"
  node --test "$repo_root/moui_shell/android/embedder/prepare-plugins.test.mjs"
  node --test "$repo_root/moui_shell/test_probe/tests/validate-test-probe.mjs"
  case "$platform" in
    ios) node --test "$repo_root/moui_shell/ios/runner/resolve-shell.test.mjs" ;;
    harmonyos) node --test "$repo_root/moui_shell/harmonyos/runner/tests/validate-managed-shell.mjs" ;;
    android)
      node --test "$repo_root/moui_shell/scripts/android-ndk.test.mjs"
      node --test "$repo_root/moui_shell/android/runner/resolve-shell.test.mjs"
      node "$repo_root/scripts/check-shell-app-config.mjs"
      ;;
  esac
}

run_managed() {
  case "$platform" in
    android)
      bash "$repo_root/moui_shell/scripts/build-android-apk.sh" \
        --workspace-root "$repo_root" --moui-root "$repo_root/moui" \
        --skia-root "$repo_root/moui_skia" --app showcase \
        --app-config "$repo_root/examples/showcase/shell.json" \
        --build-dir "$artifact_root/android/managed" \
        --output "$artifact_root/android/managed/MoUIShowcase.apk" \
        "${build_args[@]}"
      ;;
    ios)
      XCODE_XCCONFIG_FILE="${XCODE_XCCONFIG_FILE:-$repo_root/moui_shell/test_probe/tests/NoCodeSign.xcconfig}" \
        bash "$repo_root/moui_shell/scripts/build-ios-app.sh" \
        --workspace-root "$repo_root" --moui-root "$repo_root/moui" \
        --skia-root "$repo_root/moui_skia" --app showcase \
        --app-config "$repo_root/examples/showcase/shell.json" \
        --build-dir "$artifact_root/ios/managed" \
        --output "$artifact_root/ios/managed/MoUIShowcase.app" \
        "${build_args[@]}"
      ;;
    harmonyos)
      bash "$repo_root/moui_shell/scripts/build-harmonyos-hap.sh" \
        --workspace-root "$repo_root" --moui-root "$repo_root/moui" \
        --skia-root "$repo_root/moui_skia" --app showcase \
        --app-config "$repo_root/examples/showcase/shell.json" \
        --build-dir "$artifact_root/harmonyos/managed" \
        --output "$artifact_root/harmonyos/managed/MoUIShowcase.hap" \
        "${build_args[@]}"
      ;;
  esac
}

run_plugin() {
  bash "$repo_root/moui_shell/test_probe/tests/build-plugin-fixture.sh" \
    "$platform" "${build_args[@]}"
}

run_ejected() {
  bash "$repo_root/moui_shell/test_probe/tests/build-clean-ejected-fixture.sh" \
    "$platform" "${build_args[@]}"
}

cd "$repo_root"
if [ "$mode" = "all" ]; then
  run_static
  run_managed
  run_plugin
  run_ejected
else
  "run_$mode"
fi
