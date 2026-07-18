#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: moui/mobile/test-probe/tests/build-clean-ejected-fixture.sh <android|ios|harmonyos> [build options]

Create a clean versioned shell with `moui mobile eject`, then compile that
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

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
artifact_root="${MOUI_MOBILE_SHELL_CI_ROOT:-$repo_root/artifacts/mobile-shell-ci}"
project_root="$artifact_root/$platform/ejected/project"
build_root="$artifact_root/$platform/ejected/build"
config="$repo_root/examples/showcase/.mobile-ejected-build-$$.json"

cleanup() {
  rm -f "$config"
}
trap cleanup EXIT

node "$repo_root/moui/mobile/test-probe/tests/create-mobile-shell-fixture.mjs" \
  --kind eject-project \
  --platform "$platform" \
  --repo-root "$repo_root" \
  --output "$project_root"

moon run moui_cli/cmd/moui --target native -- mobile eject "$platform" \
  --project-root "$project_root" \
  --moui-root "$repo_root/moui"

shell_root="$project_root/${platform}_app"
test -s "$shell_root/.moui-shell.json"
cp "$project_root/mobile.json" "$config"

case "$platform" in
  android)
    "$repo_root/moui/scripts/mobile/build-android-apk.sh" \
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
    # moui mobile eject renames the template product from MoUIMobileApp using
    # product_name(manifest.id). For showcase that is "Showcase", not the
    # managed-shell product name MoUIShowcase from mobile.json.
    ios_product="Showcase"
    XCODE_XCCONFIG_FILE="${XCODE_XCCONFIG_FILE:-$repo_root/moui/mobile/test-probe/tests/NoCodeSign.xcconfig}" \
      "$repo_root/moui/scripts/mobile/build-ios-app.sh" \
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
    "$repo_root/moui/scripts/mobile/build-harmonyos-hap.sh" \
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
