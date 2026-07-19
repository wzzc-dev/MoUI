#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: moui_shell/test_probe/tests/build-clean-ejected-fixture.sh <android|ios|harmonyos> [build options]

Create a clean versioned shell with `moui shell eject`, then compile that
exact shell. Additional options are forwarded to the platform build command.
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
project_root="$artifact_root/$platform/ejected/project"
build_root="$artifact_root/$platform/ejected/build"
config="$repo_root/examples/showcase/.shell-ejected-build-$$.json"

cleanup() {
  rm -f "$config"
}
trap cleanup EXIT

node "$repo_root/moui_shell/test_probe/tests/create-shell-fixture.mjs" \
  --kind eject-project \
  --platform "$platform" \
  --repo-root "$repo_root" \
  --output "$project_root"

MOUI_SHELL_PACKAGE_ROOT="$repo_root/moui_shell" \
  moon run moui_cli/cmd/moui --target native -- shell eject "$platform" \
  --project-root "$project_root" \
  --moui-root "$repo_root/moui"

shell_root="$project_root/${platform}_app"
test -s "$shell_root/.moui-shell.json"
cp "$project_root/shell.json" "$config"

case "$platform" in
  android)
    bash "$repo_root/moui_shell/scripts/build-android-apk.sh" \
      --workspace-root "$repo_root" \
      --moui-root "$repo_root/moui" \
      --skia-root "$repo_root/moui_skia" \
      --app showcase \
      --app-config "$config" \
      --android-project "$shell_root" \
      --ejected-shell \
      --build-dir "$build_root" \
      --output "$build_root/MoUIShowcase.apk" \
      "$@"
    ;;
  ios)
    # moui shell eject renames the template product from MoUIShellApp using
    # product_name(manifest.id). For showcase that is "Showcase", not the
    # managed-shell product name MoUIShowcase from shell.json.
    ios_product="Showcase"
    XCODE_XCCONFIG_FILE="${XCODE_XCCONFIG_FILE:-$repo_root/moui_shell/test_probe/tests/NoCodeSign.xcconfig}" \
      bash "$repo_root/moui_shell/scripts/build-ios-app.sh" \
      --workspace-root "$repo_root" \
      --moui-root "$repo_root/moui" \
      --skia-root "$repo_root/moui_skia" \
      --app showcase \
      --app-config "$config" \
      --xcode-project "$shell_root/${ios_product}.xcodeproj" \
      --scheme "$ios_product" \
      --product-name "$ios_product" \
      --ejected-shell \
      --build-dir "$build_root" \
      --output "$build_root/${ios_product}.app" \
      "$@"
    ;;
  harmonyos)
    bash "$repo_root/moui_shell/scripts/build-harmonyos-hap.sh" \
      --workspace-root "$repo_root" \
      --moui-root "$repo_root/moui" \
      --skia-root "$repo_root/moui_skia" \
      --app showcase \
      --app-config "$config" \
      --harmonyos-project "$shell_root" \
      --ejected-shell \
      --build-dir "$build_root" \
      --output "$build_root/MoUIShowcase.hap" \
      "$@"
    ;;
esac
