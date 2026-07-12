#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: moui/scripts/mobile/build-ios-app.sh --app <id> --xcode-project <path> --scheme <name> [options]

Build a MoUI iOS app through an app Xcode project.

Options:
  --app <id>                Mobile app id.
  --xcode-project <path>    Xcode project path.
  --scheme <name>           Xcode scheme.
  --product-name <name>     Product name. Defaults to scheme.
  --app-config <path>       App-owned mobile.json. Default examples/<app>/mobile.json or ./mobile.json.
  --contracts <path>        Native contract registry. Default <moui-root>/mobile/build-contracts.json.
  --workspace-root <dir>    App workspace root. Default current directory.
  --moui-root <dir>         MoUI package root. Default this script's package.
  --skia-root <dir>         moui_skia package root.
  --sdk <sdk>               Apple SDK, iphonesimulator or iphoneos. Default iphonesimulator.
  --arch <arch>             Target arch, default arm64.
  --deployment-target <ver> iOS deployment target. Default 15.0.
  --renderer <mode>         auto, skia-gpu, or skia-raster. Default auto.
  --build-dir <dir>         Working directory, default artifacts/ios/<app>.
  --output <app>            App bundle output path.
  --fallback-skia           Do not fetch/link real Skia; packaging smoke only.
  --prepare-only            Generate MoonBit/Skia inputs, then stop.
  -h, --help                Show this help.
USAGE
}

moui_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
workspace_root="${MOUI_MOBILE_WORKSPACE_ROOT:-$(pwd)}"
skia_root="${MOUI_SKIA_ROOT:-}"
app=""
xcode_project=""
scheme=""
product_name=""
app_config=""
contracts=""
sdk="iphonesimulator"
arch="arm64"
deployment_target="15.0"
renderer="auto"
build_dir=""
output_app=""
fallback_skia=0
prepare_only=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --app) app="${2:?missing app after --app}"; shift 2 ;;
    --xcode-project) xcode_project="${2:?missing project after --xcode-project}"; shift 2 ;;
    --scheme) scheme="${2:?missing scheme after --scheme}"; shift 2 ;;
    --product-name) product_name="${2:?missing product name after --product-name}"; shift 2 ;;
    --app-config) app_config="${2:?missing path after --app-config}"; shift 2 ;;
    --contracts) contracts="${2:?missing path after --contracts}"; shift 2 ;;
    --workspace-root) workspace_root="${2:?missing dir after --workspace-root}"; shift 2 ;;
    --moui-root) moui_root="${2:?missing dir after --moui-root}"; shift 2 ;;
    --skia-root) skia_root="${2:?missing dir after --skia-root}"; shift 2 ;;
    --sdk) sdk="${2:?missing SDK after --sdk}"; shift 2 ;;
    --arch) arch="${2:?missing arch after --arch}"; shift 2 ;;
    --deployment-target) deployment_target="${2:?missing version after --deployment-target}"; shift 2 ;;
    --renderer) renderer="${2:?missing mode after --renderer}"; shift 2 ;;
    --build-dir) build_dir="${2:?missing dir after --build-dir}"; shift 2 ;;
    --output) output_app="${2:?missing app path after --output}"; shift 2 ;;
    --fallback-skia) fallback_skia=1; shift ;;
    --prepare-only) prepare_only=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -z "$app" ] || [ -z "$xcode_project" ] || [ -z "$scheme" ]; then
  echo "--app, --xcode-project, and --scheme are required" >&2
  usage >&2
  exit 2
fi

[ -n "$product_name" ] || product_name="$scheme"
case "$workspace_root" in /*) ;; *) workspace_root="$(pwd)/$workspace_root" ;; esac
case "$moui_root" in /*) ;; *) moui_root="$workspace_root/$moui_root" ;; esac
if [ -n "$skia_root" ] && [ "${skia_root#/}" = "$skia_root" ]; then
  skia_root="$workspace_root/$skia_root"
fi
if [ "${xcode_project#/}" = "$xcode_project" ]; then
  xcode_project="$workspace_root/$xcode_project"
fi
if [ -z "$build_dir" ]; then
  build_dir="$workspace_root/artifacts/ios/$app"
elif [ "${build_dir#/}" = "$build_dir" ]; then
  build_dir="$workspace_root/$build_dir"
fi
if [ -z "$output_app" ]; then
  output_app="$build_dir/$product_name.app"
elif [ "${output_app#/}" = "$output_app" ]; then
  output_app="$workspace_root/$output_app"
fi

prepare_args=(--platform ios --app "$app" --workspace-root "$workspace_root" --moui-root "$moui_root" --sdk "$sdk" --arch "$arch" --renderer "$renderer" --build-dir "$build_dir")
[ -z "$skia_root" ] || prepare_args+=(--skia-root "$skia_root")
[ -z "$app_config" ] || prepare_args+=(--app-config "$app_config")
[ -z "$contracts" ] || prepare_args+=(--contracts "$contracts")
if [ "$fallback_skia" -eq 1 ]; then
  prepare_args+=(--fallback-skia)
fi
if [ "$prepare_only" -eq 1 ]; then
  node "$moui_root/scripts/mobile/prepare-native-build.mjs" "${prepare_args[@]}"
  echo "[moui-mobile-ios] Prepared iOS build inputs in $build_dir"
  exit 0
fi

fallback_value=0
if [ "$fallback_skia" -eq 1 ]; then
  fallback_value=1
fi

MOUI_MOBILE_APP="$app" \
MOUI_MOBILE_WORKSPACE_ROOT="$workspace_root" \
MOUI_PACKAGE_ROOT="$moui_root" \
MOUI_SKIA_ROOT="$skia_root" \
MOUI_MOBILE_APP_CONFIG="$app_config" \
MOUI_MOBILE_CONTRACTS="$contracts" \
MOUI_MOBILE_BUILD_DIR="$build_dir" \
MOUI_MOBILE_OUTPUT_APP="$output_app" \
MOUI_MOBILE_ARCH="$arch" \
MOUI_MOBILE_DEPLOYMENT_TARGET="$deployment_target" \
MOUI_MOBILE_SDK="$sdk" \
MOUI_MOBILE_RENDERER="$renderer" \
MOUI_MOBILE_FALLBACK_SKIA="$fallback_value" \
  xcodebuild \
    -project "$xcode_project" \
    -scheme "$scheme" \
    -configuration Debug \
    -sdk "$sdk" \
    ARCHS="$arch" \
    IPHONEOS_DEPLOYMENT_TARGET="$deployment_target" \
    build

if [ ! -d "$output_app" ]; then
  echo "iOS app bundle was not produced: $output_app" >&2
  exit 1
fi
echo "[moui-mobile-ios] Wrote $output_app"
