#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: moui_shell/scripts/build-ios-app.sh --app <id> [options]

Build a MoUI iOS app through the package-owned canonical shell.

Options:
  --app <id>                Shell app id.
  --xcode-project <path>    Explicit Xcode project for an ejected shell.
  --scheme <name>           Xcode scheme. Defaults to MoUIShellApp for the managed shell.
  --product-name <name>     Explicit app bundle product name.
  --app-config <path>       App-owned shell.json. Default examples/<app>/shell.json or ./shell.json.
  --workspace-root <dir>    App workspace root. Default current directory.
  --project-root <dir>      Ejected app project root. Default shell-project parent.
  --moui-root <dir>         MoUI package root. Default this script's package.
  --skia-root <dir>         moui_skia package root.
  --sdk <sdk>               Apple SDK, iphonesimulator or iphoneos. Default iphonesimulator.
  --arch <arch>             Target arch, default arm64.
  --deployment-target <ver> iOS deployment target. Managed builds default to shell.json.
  --renderer <mode>         auto, skia-gpu, or skia-raster. Default auto.
  --build-dir <dir>         Working directory, default artifacts/ios/<app>.
  --output <app>            App bundle output path.
  --fallback-skia           Do not fetch/link real Skia; packaging smoke only.
  --ejected-shell           Build a versioned ejected SwiftUI shell project.
  --prepare-only            Generate MoonBit/Skia inputs, then stop.
  -h, --help                Show this help.
USAGE
}

shell_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
moui_root="${MOUI_PACKAGE_ROOT:-}"
workspace_root="${MOUI_EMBEDDING_WORKSPACE_ROOT:-$(pwd)}"
skia_root="${MOUI_SKIA_ROOT:-}"
project_root="${MOUI_EMBEDDING_PROJECT_ROOT:-}"
app=""
xcode_project=""
scheme=""
product_name=""
app_config=""
sdk="iphonesimulator"
arch="arm64"
deployment_target=""
deployment_target_explicit=0
renderer="auto"
build_dir=""
output_app=""
fallback_skia=0
shell_mode="managed"
ejected_shell=0
prepare_only=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --app) app="${2:?missing app after --app}"; shift 2 ;;
    --xcode-project) xcode_project="${2:?missing project after --xcode-project}"; shift 2 ;;
    --scheme) scheme="${2:?missing scheme after --scheme}"; shift 2 ;;
    --product-name) product_name="${2:?missing product name after --product-name}"; shift 2 ;;
    --app-config) app_config="${2:?missing path after --app-config}"; shift 2 ;;
    --workspace-root) workspace_root="${2:?missing dir after --workspace-root}"; shift 2 ;;
    --project-root) project_root="${2:?missing dir after --project-root}"; shift 2 ;;
    --moui-root) moui_root="${2:?missing dir after --moui-root}"; shift 2 ;;
    --skia-root) skia_root="${2:?missing dir after --skia-root}"; shift 2 ;;
    --sdk) sdk="${2:?missing SDK after --sdk}"; shift 2 ;;
    --arch) arch="${2:?missing arch after --arch}"; shift 2 ;;
    --deployment-target) deployment_target="${2:?missing version after --deployment-target}"; deployment_target_explicit=1; shift 2 ;;
    --renderer) renderer="${2:?missing mode after --renderer}"; shift 2 ;;
    --build-dir) build_dir="${2:?missing dir after --build-dir}"; shift 2 ;;
    --output) output_app="${2:?missing app path after --output}"; shift 2 ;;
    --fallback-skia) fallback_skia=1; shift ;;
    --ejected-shell) shell_mode="ejected"; ejected_shell=1; shift ;;
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
xcode_version="$(xcodebuild -version | awk 'NR == 1 { print $2 }')"
if [ -z "$xcode_version" ] || ! awk -v value="$xcode_version" 'BEGIN {
  split(value, actual, ".");
  exit !((actual[1] + 0) > 15 || ((actual[1] + 0) == 15 && (actual[2] + 0) >= 4));
}'; then
  echo "MoUI iOS shell requires Xcode 15.4 or newer; found ${xcode_version:-unknown}" >&2
  exit 1
fi

case "$workspace_root" in /*) ;; *) workspace_root="$(pwd)/$workspace_root" ;; esac
if [ -z "$moui_root" ]; then
  if [ -d "$workspace_root/moui" ]; then moui_root="$workspace_root/moui"; else moui_root="$workspace_root/.mooncakes/wzzc-dev/moui"; fi
elif [ "${moui_root#/}" = "$moui_root" ]; then
  moui_root="$workspace_root/$moui_root"
fi
if [ -n "$skia_root" ] && [ "${skia_root#/}" = "$skia_root" ]; then
  skia_root="$workspace_root/$skia_root"
fi
if [ -z "$build_dir" ]; then
  build_dir="$workspace_root/artifacts/ios/$app"
elif [ "${build_dir#/}" = "$build_dir" ]; then
  build_dir="$workspace_root/$build_dir"
fi
if [ -n "$output_app" ] && [ "${output_app#/}" = "$output_app" ]; then
  output_app="$workspace_root/$output_app"
fi
if [ "$shell_mode" = "ejected" ] && [ -z "$xcode_project" ]; then
  echo "--ejected-shell requires --xcode-project" >&2
  exit 2
fi
if [ -z "$xcode_project" ]; then
  xcode_project="$build_dir/ios-project/MoUIShellApp.xcodeproj"
  stage_ios_project=1
else
  stage_ios_project=0
  if [ "${xcode_project#/}" = "$xcode_project" ]; then
    xcode_project="$workspace_root/$xcode_project"
  fi
fi
if [ "$shell_mode" = "managed" ] && [ "$stage_ios_project" -eq 0 ]; then
  echo "--xcode-project requires --ejected-shell" >&2
  exit 2
fi
if [ "$shell_mode" = "ejected" ]; then
  shell_lock="$(dirname "$xcode_project")/.moui-shell.json"
  if [ ! -f "$shell_lock" ]; then
    echo "--ejected-shell requires a versioned .moui-shell.json: $shell_lock" >&2
    exit 1
  fi
  if [ -z "$project_root" ]; then project_root="$(dirname "$(dirname "$xcode_project")")"; elif [ "${project_root#/}" = "$project_root" ]; then project_root="$workspace_root/$project_root"; fi
  node "$shell_root/scripts/validate-ejected-lock.mjs" \
    --lock "$shell_lock" --platform ios --moui-root "$moui_root" \
    --shell-root "$shell_root" --project-root "$project_root" --app-config "$app_config"
  echo "[moui-shell-ios] Using versioned ejected shell at $(dirname "$xcode_project")"
fi
if [ -z "$scheme" ] && [ "$shell_mode" = "ejected" ]; then
  scheme="$(basename "$xcode_project" .xcodeproj)"
fi
[ -n "$scheme" ] || scheme="MoUIShellApp"
[ -n "$product_name" ] || product_name="$scheme"

managed_preflight_swift=""
managed_preflight_manifest=""
if [ "$shell_mode" = "managed" ]; then
  managed_preflight_dir="$build_dir/managed-shell-preflight"
  managed_preflight_swift="$managed_preflight_dir/MOUIGeneratedConfiguration.swift"
  managed_preflight_manifest="$managed_preflight_dir/managed-shell.json"
  mkdir -p "$managed_preflight_dir"
  resolver_args=(
    --workspace-root "$workspace_root"
    --moui-root "$moui_root"
    --app "$app"
    --renderer "$renderer"
    --shell-mode managed
    --output-swift "$managed_preflight_swift"
    --output-manifest "$managed_preflight_manifest"
  )
  [ -z "$skia_root" ] || resolver_args+=(--skia-root "$skia_root")
  [ -z "$app_config" ] || resolver_args+=(--app-config "$app_config")
  node "$shell_root/ios/runner/resolve-shell.mjs" "${resolver_args[@]}"
  configured_deployment_target="$(node -e '
const fs = require("fs");
const manifest = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
if (typeof manifest.deploymentTarget !== "string") process.exit(1);
process.stdout.write(manifest.deploymentTarget);
' "$managed_preflight_manifest")"
  if [ "$deployment_target_explicit" -eq 0 ]; then
    deployment_target="$configured_deployment_target"
  elif ! node -e '
const version = /^\d+(?:\.\d+){0,2}$/;
const [actual, floor] = process.argv.slice(1);
if (!version.test(actual) || !version.test(floor)) process.exit(1);
const left = actual.split(".").map(Number);
const right = floor.split(".").map(Number);
for (let index = 0; index < Math.max(left.length, right.length); index += 1) {
  const difference = (left[index] || 0) - (right[index] || 0);
  if (difference !== 0) process.exit(difference > 0 ? 0 : 1);
}
' "$deployment_target" "$configured_deployment_target"; then
    echo "--deployment-target $deployment_target is below shell.json ios.deploymentTarget $configured_deployment_target" >&2
    exit 2
  fi
elif [ -z "$deployment_target" ]; then
  deployment_target="15.0"
fi

prepare_args=(--platform ios --app "$app" --workspace-root "$workspace_root" --moui-root "$moui_root" --sdk "$sdk" --arch "$arch" --renderer "$renderer" --build-dir "$build_dir")
[ -z "$skia_root" ] || prepare_args+=(--skia-root "$skia_root")
[ -z "$app_config" ] || prepare_args+=(--app-config "$app_config")
if [ "$fallback_skia" -eq 1 ]; then
  prepare_args+=(--fallback-skia)
fi
if [ "$prepare_only" -eq 1 ]; then
  node "$shell_root/scripts/prepare-native-build.mjs" "${prepare_args[@]}"
  echo "[moui-shell-ios] Prepared iOS build inputs in $build_dir"
  exit 0
fi

fallback_value=0
if [ "$fallback_skia" -eq 1 ]; then
  fallback_value=1
fi

if [ "$stage_ios_project" -eq 1 ]; then
  template_root="$shell_root/ios/runner/template"
  staged_root="$(dirname "$xcode_project")"
  stage_marker="$staged_root/.moui-managed-ios-stage"
  if [ ! -f "$template_root/MoUIShellApp.xcodeproj/project.pbxproj" ] || \
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
  if [ "$shell_mode" = "managed" ]; then
    node "$shell_root/ios/apply-managed-info-plist.mjs" \
      --manifest "$managed_preflight_manifest" \
      --plist "$staged_root/Info.plist" \
      --deployment-target "$deployment_target"
  fi
  echo "[moui-shell-ios] Staged canonical iOS shell in $staged_root"
fi

MOUI_EMBEDDING_APP="$app" \
MOUI_EMBEDDING_WORKSPACE_ROOT="$workspace_root" \
MOUI_EMBEDDING_PROJECT_ROOT="$project_root" \
MOUI_PACKAGE_ROOT="$moui_root" \
MOUI_SHELL_PACKAGE_ROOT="$shell_root" \
MOUI_SKIA_ROOT="$skia_root" \
MOUI_EMBEDDING_APP_CONFIG="$app_config" \
MOUI_EMBEDDING_BUILD_DIR="$build_dir" \
MOUI_EMBEDDING_OUTPUT_APP="$output_app" \
MOUI_EMBEDDING_ARCH="$arch" \
MOUI_EMBEDDING_DEPLOYMENT_TARGET="$deployment_target" \
MOUI_EMBEDDING_SDK="$sdk" \
MOUI_EMBEDDING_RENDERER="$renderer" \
MOUI_EMBEDDING_FALLBACK_SKIA="$fallback_value" \
MOUI_EMBEDDING_IOS_SHELL="$shell_mode" \
MOUI_EMBEDDING_IOS_RESOLVED_SWIFT="$managed_preflight_swift" \
MOUI_EMBEDDING_IOS_RESOLVED_MANIFEST="$managed_preflight_manifest" \
  xcodebuild \
    -project "$xcode_project" \
    -scheme "$scheme" \
    -configuration Debug \
    -sdk "$sdk" \
    ARCHS="$arch" \
    IPHONEOS_DEPLOYMENT_TARGET="$deployment_target" \
    MOUI_EMBEDDING_IOS_SHELL="$shell_mode" \
    build

if [ -z "$output_app" ]; then
  product_name="$(node -e '
const fs = require("fs");
const value = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
if (typeof value.productName !== "string" || value.productName.length === 0) process.exit(1);
process.stdout.write(value.productName);
' "$build_dir/shell-build.json")"
  output_app="$build_dir/$product_name.app"
fi
if [ ! -d "$output_app" ]; then
  echo "iOS app bundle was not produced: $output_app" >&2
  exit 1
fi
echo "[moui-shell-ios] Wrote $output_app"
