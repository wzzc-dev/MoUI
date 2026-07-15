#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: moui/scripts/mobile/build-ios-app.sh --app <id> [options]

Build a MoUI iOS app through the package-owned canonical shell.

Options:
  --app <id>                Mobile app id.
  --xcode-project <path>    Explicit Xcode project override for a repository fixture or ejected shell.
  --scheme <name>           Xcode scheme. Defaults to MoUIMobileApp for the managed shell.
  --product-name <name>     Explicit app bundle product name.
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
  --ejected-shell           Build a versioned ejected SwiftUI shell project.
  --legacy-uikit-shell      Build the frozen Release N UIKit compatibility shell.
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
shell_mode="managed"
ejected_shell=0
legacy_uikit_shell=0
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
    --ejected-shell) shell_mode="ejected"; ejected_shell=1; shift ;;
    --legacy-uikit-shell) shell_mode="legacy-uikit"; legacy_uikit_shell=1; shift ;;
    --prepare-only) prepare_only=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -z "$app" ]; then
  echo "--app is required" >&2
  usage >&2
  exit 2
fi
if [ "$ejected_shell" -eq 1 ] && [ "$legacy_uikit_shell" -eq 1 ]; then
  echo "--ejected-shell and --legacy-uikit-shell are mutually exclusive" >&2
  exit 2
fi

if [ "$shell_mode" != "legacy-uikit" ]; then
  xcode_version="$(xcodebuild -version | awk 'NR == 1 { print $2 }')"
  if [ -z "$xcode_version" ] || ! awk -v value="$xcode_version" 'BEGIN {
    split(value, actual, ".");
    exit !((actual[1] + 0) > 15 || ((actual[1] + 0) == 15 && (actual[2] + 0) >= 4));
  }'; then
    echo "MoUI managed iOS shell requires Xcode 15.4 or newer; found ${xcode_version:-unknown}" >&2
    exit 1
  fi
fi

case "$workspace_root" in /*) ;; *) workspace_root="$(pwd)/$workspace_root" ;; esac
case "$moui_root" in /*) ;; *) moui_root="$workspace_root/$moui_root" ;; esac
if [ -n "$skia_root" ] && [ "${skia_root#/}" = "$skia_root" ]; then
  skia_root="$workspace_root/$skia_root"
fi
if [ -z "$build_dir" ]; then
  build_dir="$workspace_root/artifacts/ios/$app"
elif [ "${build_dir#/}" = "$build_dir" ]; then
  build_dir="$workspace_root/$build_dir"
fi
deprecation_path="$build_dir/mobile-deprecation.json"
if [ -n "$output_app" ] && [ "${output_app#/}" = "$output_app" ]; then
  output_app="$workspace_root/$output_app"
fi
if [ "$shell_mode" = "legacy-uikit" ] && { [ -z "$xcode_project" ] || [ -z "$scheme" ]; }; then
  echo "--legacy-uikit-shell requires --xcode-project and --scheme" >&2
  exit 2
fi
if [ "$shell_mode" = "legacy-uikit" ]; then
  if [ -z "$app_config" ]; then
    echo "--legacy-uikit-shell requires an explicit schema v1 --app-config" >&2
    exit 2
  fi
  case "$app_config" in /*) legacy_config_path="$app_config" ;; *) legacy_config_path="$workspace_root/$app_config" ;; esac
  node -e '
const fs = require("fs");
const path = process.argv[1];
const config = JSON.parse(fs.readFileSync(path, "utf8"));
if (config.schemaVersion !== 1) {
  console.error(`--legacy-uikit-shell requires schemaVersion 1: ${path}`);
  process.exit(1);
}
' "$legacy_config_path"
  export MOUI_MOBILE_ALLOW_LEGACY_CONFIG=1
else
  unset MOUI_MOBILE_ALLOW_LEGACY_CONFIG
fi
if [ "$shell_mode" = "ejected" ] && [ -z "$xcode_project" ]; then
  echo "--ejected-shell requires --xcode-project" >&2
  exit 2
fi
if [ -z "$xcode_project" ]; then
  xcode_project="$build_dir/ios-project/MoUIMobileApp.xcodeproj"
  stage_ios_project=1
else
  stage_ios_project=0
  if [ "${xcode_project#/}" = "$xcode_project" ]; then
    xcode_project="$workspace_root/$xcode_project"
  fi
fi
if [ "$shell_mode" = "managed" ] && [ "$stage_ios_project" -eq 0 ]; then
  echo "--xcode-project requires --ejected-shell or --legacy-uikit-shell" >&2
  exit 2
fi
if [ "$shell_mode" = "ejected" ]; then
  shell_lock="$(dirname "$xcode_project")/.moui-shell.json"
  if [ ! -f "$shell_lock" ]; then
    echo "--ejected-shell requires a versioned .moui-shell.json: $shell_lock" >&2
    exit 1
  fi
  node -e '
const fs = require("fs");
const path = process.argv[1];
const lock = JSON.parse(fs.readFileSync(path, "utf8"));
const expected = {
  schemaVersion: 1,
  mode: "ejected",
  platform: "ios",
  shellApiVersion: 1,
  runtimeAbiVersion: 1,
};
for (const [field, value] of Object.entries(expected)) {
  if (lock[field] !== value) {
    console.error(`${path}: ${field} must be ${JSON.stringify(value)}`);
    process.exit(1);
  }
}
' "$shell_lock"
  echo "[moui-mobile-ios] Using versioned ejected shell at $(dirname "$xcode_project")"
fi
if [ -z "$scheme" ] && [ "$shell_mode" = "ejected" ]; then
  scheme="$(basename "$xcode_project" .xcodeproj)"
fi
[ -n "$scheme" ] || scheme="MoUIMobileApp"
[ -n "$product_name" ] || product_name="$scheme"

prepare_args=(--platform ios --app "$app" --workspace-root "$workspace_root" --moui-root "$moui_root" --sdk "$sdk" --arch "$arch" --renderer "$renderer" --build-dir "$build_dir")
[ -z "$skia_root" ] || prepare_args+=(--skia-root "$skia_root")
[ -z "$app_config" ] || prepare_args+=(--app-config "$app_config")
[ -z "$contracts" ] || prepare_args+=(--contracts "$contracts")
if [ "$fallback_skia" -eq 1 ]; then
  prepare_args+=(--fallback-skia)
fi
update_deprecation_marker() {
  if [ "$shell_mode" != "legacy-uikit" ]; then
    rm -f "$deprecation_path"
    return
  fi
  mkdir -p "$build_dir"
  cat > "$deprecation_path" <<'JSON'
{
  "schemaVersion": 1,
  "code": "ios-uikit-shell",
  "deprecated": true,
  "removal": "Release N+1",
  "replacement": "schema v2 managed iOS shell"
}
JSON
}
if [ "$prepare_only" -eq 1 ]; then
  node "$moui_root/scripts/mobile/prepare-native-build.mjs" "${prepare_args[@]}"
  update_deprecation_marker
  echo "[moui-mobile-ios] Prepared iOS build inputs in $build_dir"
  exit 0
fi

fallback_value=0
if [ "$fallback_skia" -eq 1 ]; then
  fallback_value=1
fi

if [ "$stage_ios_project" -eq 1 ]; then
  template_root="$moui_root/mobile/ios/template"
  staged_root="$(dirname "$xcode_project")"
  stage_marker="$staged_root/.moui-managed-ios-stage"
  if [ ! -f "$template_root/MoUIMobileApp.xcodeproj/project.pbxproj" ] || \
      [ ! -f "$template_root/Info.plist" ]; then
    echo "MoUI iOS template is incomplete: $template_root" >&2
    exit 1
  fi
  if [ -e "$staged_root" ] && [ ! -f "$stage_marker" ]; then
    echo "Refusing to replace an unowned iOS project: $staged_root" >&2
    exit 1
  fi
  rm -rf "$staged_root"
  mkdir -p "$staged_root"
  touch "$stage_marker"
  cp -R "$template_root/." "$staged_root/"
  echo "[moui-mobile-ios] Staged canonical iOS shell in $staged_root"
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
MOUI_MOBILE_IOS_SHELL="$shell_mode" \
  xcodebuild \
    -project "$xcode_project" \
    -scheme "$scheme" \
    -configuration Debug \
    -sdk "$sdk" \
    ARCHS="$arch" \
    IPHONEOS_DEPLOYMENT_TARGET="$deployment_target" \
    MOUI_MOBILE_IOS_SHELL="$shell_mode" \
    build

update_deprecation_marker

if [ -z "$output_app" ]; then
  product_name="$(node -e '
const fs = require("fs");
const value = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
if (typeof value.productName !== "string" || value.productName.length === 0) process.exit(1);
process.stdout.write(value.productName);
' "$build_dir/mobile-build.json")"
  output_app="$build_dir/$product_name.app"
fi
if [ ! -d "$output_app" ]; then
  echo "iOS app bundle was not produced: $output_app" >&2
  exit 1
fi
echo "[moui-mobile-ios] Wrote $output_app"
