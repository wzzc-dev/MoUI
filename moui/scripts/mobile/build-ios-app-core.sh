#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: moui/scripts/mobile/build-ios-app-core.sh --app <id>

Internal builder used by Xcode native targets. Prefer
moui/scripts/mobile/build-ios-app.sh.
USAGE
}

moui_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
workspace_root="${MOUI_MOBILE_WORKSPACE_ROOT:-$(pwd)}"
if [ "${workspace_root#/}" = "$workspace_root" ]; then
  workspace_root="$(pwd)/$workspace_root"
fi
if [ -n "${MOUI_PACKAGE_ROOT:-}" ]; then
  moui_root="$MOUI_PACKAGE_ROOT"
  if [ "${moui_root#/}" = "$moui_root" ]; then
    moui_root="$workspace_root/$moui_root"
  fi
fi
skia_root="${MOUI_SKIA_ROOT:-}"
if [ -z "$skia_root" ]; then
  if [ -d "$workspace_root/moui_skia" ]; then
    skia_root="$workspace_root/moui_skia"
  elif [ -d "$workspace_root/.mooncakes/wzzc-dev/moui_skia" ]; then
    skia_root="$workspace_root/.mooncakes/wzzc-dev/moui_skia"
  else
    skia_root="$workspace_root/moui_skia"
  fi
elif [ "${skia_root#/}" = "$skia_root" ]; then
  skia_root="$workspace_root/$skia_root"
fi
app_config="${MOUI_MOBILE_APP_CONFIG:-}"
contracts="${MOUI_MOBILE_CONTRACTS:-}"
app="${MOUI_MOBILE_APP:-}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --app)
      app="${2:?missing app after --app}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$app" ]; then
  echo "--app or MOUI_MOBILE_APP is required" >&2
  exit 2
fi

sdk="${MOUI_MOBILE_SDK:-${SDK_NAME:-iphonesimulator}}"
case "$sdk" in
  iphonesimulator*|iphonesimulator)
    sdk="iphonesimulator"
    min_version_flag_name="mios-simulator-version-min"
    ;;
  iphoneos*|iphoneos)
    sdk="iphoneos"
    min_version_flag_name="miphoneos-version-min"
    ;;
  *)
    echo "unsupported SDK: $sdk" >&2
    exit 2
    ;;
esac

arch="${MOUI_MOBILE_ARCH:-${ARCHS:-arm64}}"
arch="${arch%% *}"
deployment_target="${MOUI_MOBILE_DEPLOYMENT_TARGET:-${IPHONEOS_DEPLOYMENT_TARGET:-15.0}}"
fallback_skia="${MOUI_MOBILE_FALLBACK_SKIA:-0}"
renderer="${MOUI_MOBILE_RENDERER:-auto}"
configuration="${CONFIGURATION:-Debug}"
shell_mode="${MOUI_MOBILE_IOS_SHELL:-managed}"
build_dir="${MOUI_MOBILE_BUILD_DIR:-$workspace_root/artifacts/ios/$app}"
if [ "${build_dir#/}" = "$build_dir" ]; then
  build_dir="$workspace_root/$build_dir"
fi

case "$shell_mode" in
  managed|ejected|legacy-uikit) ;;
  *) echo "unsupported iOS shell mode: $shell_mode" >&2; exit 2 ;;
esac
if [ "$shell_mode" = "legacy-uikit" ]; then
  if [ -z "$app_config" ]; then
    echo "legacy-uikit shell requires MOUI_MOBILE_APP_CONFIG with schemaVersion 1" >&2
    exit 2
  fi
  case "$app_config" in /*) legacy_config_path="$app_config" ;; *) legacy_config_path="$workspace_root/$app_config" ;; esac
  node -e '
const fs = require("fs");
const path = process.argv[1];
const config = JSON.parse(fs.readFileSync(path, "utf8"));
if (config.schemaVersion !== 1) {
  console.error(`legacy-uikit shell requires schemaVersion 1: ${path}`);
  process.exit(1);
}
' "$legacy_config_path"
  export MOUI_MOBILE_ALLOW_LEGACY_CONFIG=1
else
  unset MOUI_MOBILE_ALLOW_LEGACY_CONFIG
fi
if ! awk -v value="$deployment_target" 'BEGIN {
  split(value, actual, ".");
  exit !((actual[1] + 0) >= 15);
}'; then
  echo "MoUI iOS requires deployment target 15.0 or newer: $deployment_target" >&2
  exit 2
fi

prepare_args=(
  "--platform" "ios"
  "--app" "$app"
  "--workspace-root" "$workspace_root"
  "--moui-root" "$moui_root"
  "--skia-root" "$skia_root"
  "--sdk" "$sdk"
  "--arch" "$arch"
  "--renderer" "$renderer"
  "--build-dir" "$build_dir"
)
[ -z "$app_config" ] || prepare_args+=("--app-config" "$app_config")
[ -z "$contracts" ] || prepare_args+=("--contracts" "$contracts")
case "$fallback_skia" in
  1|true|TRUE|yes|YES|on|ON)
    prepare_args+=("--fallback-skia")
    ;;
esac

node "$moui_root/scripts/mobile/prepare-native-build.mjs" "${prepare_args[@]}"

json_get() {
  node -e '
const fs = require("fs");
const key = process.argv[1];
const value = key.split(".").reduce((acc, part) => acc && acc[part], JSON.parse(fs.readFileSync(process.argv[2], "utf8")));
if (Array.isArray(value)) process.stdout.write(value.join("\n"));
else if (typeof value === "boolean") process.stdout.write(value ? "1" : "0");
else if (value !== undefined && value !== null) process.stdout.write(String(value));
' "$1" "${2:-$build_dir/mobile-build.json}"
}

json_lines() {
  node -e '
const fs = require("fs");
const value = process.argv[1].split(".").reduce((acc, part) => acc && acc[part], JSON.parse(fs.readFileSync(process.argv[2], "utf8")));
if (Array.isArray(value)) process.stdout.write(value.join("\n"));
' "$1" "$2"
}

log() {
  printf '[moui-mobile-ios] %s\n' "$*"
}

sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"
cc="$(xcrun --sdk "$sdk" --find clang)"
cxx="$(xcrun --sdk "$sdk" --find clang++)"
swiftc="$(xcrun --sdk "$sdk" --find swiftc)"
moon_home="${MOON_HOME:-$HOME/.moon}"
fs_native="$workspace_root/.mooncakes/moonbitlang/x/fs/fs_native.c"

if [ ! -f "$moon_home/lib/runtime.c" ] || [ ! -f "$moon_home/include/moonbit.h" ]; then
  echo "MoonBit runtime headers not found under $moon_home. Set MOON_HOME if needed." >&2
  exit 1
fi
if [ ! -f "$fs_native" ]; then
  echo "MoonBit x/fs native stub was not found: $fs_native" >&2
  echo "Run moon update or moon check once to populate .mooncakes." >&2
  exit 1
fi

moonbit_c="$(json_get moonbitC)"
skia_cxx_rsp="$(json_get skiaCxxRsp)"
skia_link_rsp="$(json_get skiaLinkRsp)"
product_name="$(json_get productName)"
bundle_id="$(json_get bundleId)"
info_plist="$(json_get infoPlist)"
app_arg="$(json_get appArg)"
main_alias="$(json_get moonbitMainAlias)"
fullscreen="$(json_get fullscreen)"
supports_scroll="$(json_get supportsScroll)"
renderer_requested="$(json_get renderer.requested)"
renderer_selected="$(json_get renderer.selected)"
attach_view="$(json_get exports.attachView)"
resize_symbol="$(json_get exports.resize)"
dispatch_pointer="$(json_get exports.dispatchPointer)"
dispatch_scroll="$(json_get exports.dispatchScroll)"
frame_tick="$(json_get exports.frameTick)"
render_frame="$(json_get exports.renderFrame)"
detach_view="$(json_get exports.detachView)"
destroy_application="$(json_get exports.destroyApplication)"

output_app="${MOUI_MOBILE_OUTPUT_APP:-}"
if [ -z "$output_app" ]; then
  output_app="$build_dir/$product_name.app"
elif [ "${output_app#/}" = "$output_app" ]; then
  output_app="$workspace_root/$output_app"
fi

obj_dir="$build_dir/obj/$sdk-$arch-$configuration"
rm -rf "$obj_dir"
mkdir -p "$obj_dir"

managed_config=""
managed_manifest=""
if [ "$shell_mode" != "legacy-uikit" ]; then
  managed_config="$obj_dir/MOUIGeneratedConfiguration.swift"
  managed_manifest="$obj_dir/managed-shell.json"
  resolved_swift="${MOUI_MOBILE_IOS_RESOLVED_SWIFT:-}"
  resolved_manifest="${MOUI_MOBILE_IOS_RESOLVED_MANIFEST:-}"
  if [ -n "$resolved_swift" ] || [ -n "$resolved_manifest" ]; then
    if [ ! -f "$resolved_swift" ] || [ ! -f "$resolved_manifest" ]; then
      echo "managed iOS preflight must provide both generated Swift and manifest files" >&2
      exit 1
    fi
    cp "$resolved_swift" "$managed_config"
    cp "$resolved_manifest" "$managed_manifest"
  else
    resolver_args=(
      --workspace-root "$workspace_root"
      --moui-root "$moui_root"
      --app "$app"
      --renderer "$renderer_requested"
      --shell-mode "$shell_mode"
      --output-swift "$managed_config"
      --output-manifest "$managed_manifest"
    )
    [ -z "$skia_root" ] || resolver_args+=(--skia-root "$skia_root")
    [ -z "$app_config" ] || resolver_args+=(--app-config "$app_config")
    [ -z "$contracts" ] || resolver_args+=(--contracts "$contracts")
    node "$moui_root/mobile/ios/resolve-managed-shell.mjs" "${resolver_args[@]}"
  fi

  if [ "$shell_mode" = "managed" ]; then
    configured_deployment_target="$(json_get deploymentTarget "$managed_manifest")"
    if ! node -e '
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
      echo "iOS deployment target $deployment_target is below managed config floor $configured_deployment_target" >&2
      exit 2
    fi
  fi
fi

common_flags=(
  -arch "$arch"
  -isysroot "$sdk_path"
  "-$min_version_flag_name=$deployment_target"
)
if [ "$sdk" = "iphonesimulator" ]; then
  swift_target="$arch-apple-ios${deployment_target}-simulator"
else
  swift_target="$arch-apple-ios${deployment_target}"
fi
swift_flags=(
  -swift-version 5
  -target "$swift_target"
  -sdk "$sdk_path"
  -I "$moui_root/mobile/ios/bridge/include"
)
include_flags=(
  -I "$moui_root/mobile/include"
  -I "$moui_root/mobile/ios/include"
  -I "$moui_root/mobile/ios/bridge/include"
  -I "$moon_home/include"
  -I "$skia_root/native"
)

objects=()
compile_c() {
  local src="$1"
  local obj="$2"
  shift 2
  log "Compiling $(basename "$src")"
  "$cc" "${common_flags[@]}" "${include_flags[@]}" "$@" -c "$src" -o "$obj"
  objects+=("$obj")
}

compile_cxx() {
  local src="$1"
  local obj="$2"
  shift 2
  log "Compiling $(basename "$src")"
  if [ -s "$skia_cxx_rsp" ]; then
    "$cxx" "${common_flags[@]}" "${include_flags[@]}" "@$skia_cxx_rsp" \
      -std=c++17 "$@" -c "$src" -o "$obj"
  else
    "$cxx" "${common_flags[@]}" "${include_flags[@]}" \
      -std=c++17 "$@" -c "$src" -o "$obj"
  fi
  objects+=("$obj")
}

compile_objcxx() {
  local src="$1"
  local obj="$2"
  shift 2
  log "Compiling $(basename "$src")"
  "$cxx" "${common_flags[@]}" "${include_flags[@]}" -std=c++17 -fobjc-arc \
    "$@" -c "$src" -o "$obj"
  objects+=("$obj")
}

compile_swift_object() {
  local module_name="$1"
  local output="$2"
  shift 2
  log "Compiling Swift module $module_name"
  "$swiftc" "${swift_flags[@]}" \
    -parse-as-library \
    -whole-module-optimization \
    -module-name "$module_name" \
    -emit-object \
    "$@" \
    -o "$output"
  objects+=("$output")
}

compiled_main_alias="$main_alias"
if [ "$shell_mode" != "legacy-uikit" ]; then
  compiled_main_alias="moui_mobile_moonbit_generated_main"
fi
compile_c "$moonbit_c" "$obj_dir/moonbit.o" -Dmain="$compiled_main_alias"
compile_c "$moon_home/lib/runtime.c" "$obj_dir/runtime.o" -Dgetentropy=moui_ios_getentropy
compile_c "$fs_native" "$obj_dir/fs_native.o"
compile_c "$moui_root/mobile/ios/moui_ios_compat.c" "$obj_dir/moui_ios_compat.o"
if [ "$shell_mode" = "legacy-uikit" ]; then
  log "Building frozen Release N UIKit compatibility shell"
  compile_objcxx "$moui_root/mobile/ios/legacy/moui_mobile_app.mm" "$obj_dir/moui_mobile_app.o" \
    -DMOUI_MOBILE_APP_ARG="\"$app_arg\"" \
    -DMOUI_MOBILE_APP_ID="\"$app\"" \
    -DMOUI_MOBILE_RENDERER_REQUESTED="\"$renderer_requested\"" \
    -DMOUI_MOBILE_RENDERER_SELECTED="\"$renderer_selected\"" \
    -DMOUI_MOBILE_ENABLE_SCROLL="$supports_scroll" \
    -DMOUI_MOBILE_FULLSCREEN="$fullscreen" \
    -DMOUI_MOBILE_ATTACH_VIEW="$attach_view" \
    -DMOUI_MOBILE_RESIZE="$resize_symbol" \
    -DMOUI_MOBILE_DISPATCH_POINTER="$dispatch_pointer" \
    -DMOUI_MOBILE_DISPATCH_SCROLL="${dispatch_scroll:-moui_mobile_no_scroll}" \
    -DMOUI_MOBILE_FRAME_TICK="$frame_tick" \
    -DMOUI_MOBILE_RENDER_FRAME="$render_frame" \
    -DMOUI_MOBILE_DETACH_VIEW="$detach_view"
else
  # Managed ABI v1 binds only the fixed moui_mobile_* exports. App-specific
  # symbol maps remain confined to the explicit Release N legacy branch.
  compile_cxx "$moui_root/mobile/runtime/moui_mobile_runtime_v1.cpp" "$obj_dir/moui_mobile_runtime_v1.o"
  compile_objcxx "$moui_root/mobile/ios/bridge/MoUIMobileRuntimeBridge.mm" "$obj_dir/MoUIMobileRuntimeBridge.o"

  plugin_objcxx_index=0
  while IFS= read -r src || [ -n "$src" ]; do
    [ -n "$src" ] || continue
    plugin_objcxx_index=$((plugin_objcxx_index + 1))
    compile_objcxx "$src" "$obj_dir/plugin-$plugin_objcxx_index.o"
  done < <(json_lines objcxxSources "$managed_manifest")

  shell_swift_sources=("$moui_root/mobile/ios/Sources/MoUIMobileShell/"*.swift)
  log "Compiling Swift package module MoUIMobileShell"
  "$swiftc" "${swift_flags[@]}" \
    -parse-as-library \
    -whole-module-optimization \
    -module-name MoUIMobileShell \
    -emit-module \
    -emit-module-path "$obj_dir/MoUIMobileShell.swiftmodule" \
    -emit-object \
    "${shell_swift_sources[@]}" \
    -o "$obj_dir/MoUIMobileShell.o"
  objects+=("$obj_dir/MoUIMobileShell.o")

  app_swift_sources=(
    "$moui_root/mobile/ios/template/Sources/MoUIMobileApp.swift"
    "$managed_config"
  )
  while IFS= read -r src || [ -n "$src" ]; do
    [ -n "$src" ] || continue
    app_swift_sources+=("$src")
  done < <(json_lines swiftSources "$managed_manifest")
  swift_flags+=( -I "$obj_dir" )
  compile_swift_object MoUIMobileApp "$obj_dir/MoUIMobileApp.o" "${app_swift_sources[@]}"
fi
compile_objcxx "$moui_root/backend/ios/skia/ios_skia_presenter.mm" "$obj_dir/ios_skia_presenter.o"
compile_objcxx "$moui_root/backend/ios/skia/ios_skia_view_glue.mm" "$obj_dir/ios_skia_view_glue.o"

while IFS= read -r src || [ -n "$src" ]; do
  [ -n "$src" ] || continue
  compile_cxx "$src" "$obj_dir/$(basename "${src%.cpp}").o"
done < <(json_get skiaStubSources)

app_bundle="$output_app"
executable_path="$app_bundle/$product_name"
rm -rf "$app_bundle"
mkdir -p "$app_bundle"

ios_link_flags=(
  -framework UIKit
  -framework Foundation
  -framework CoreFoundation
  -framework CoreGraphics
  -framework CoreText
  -framework ImageIO
  -framework QuartzCore
  -framework Metal
  -lz
  -lobjc
  -lc++
)
if [ "$shell_mode" != "legacy-uikit" ]; then
  ios_link_flags+=( -framework SwiftUI )
fi
log "Linking $product_name"
if [ "$shell_mode" != "legacy-uikit" ]; then
  if [ -s "$skia_link_rsp" ]; then
    "$swiftc" "${swift_flags[@]}" -o "$executable_path" \
      "${objects[@]}" \
      "@$skia_link_rsp" \
      "${ios_link_flags[@]}"
  else
    "$swiftc" "${swift_flags[@]}" -o "$executable_path" \
      "${objects[@]}" \
      "${ios_link_flags[@]}"
  fi
elif [ -s "$skia_link_rsp" ]; then
  "$cxx" "${common_flags[@]}" -o "$executable_path" \
    "${objects[@]}" \
    "@$skia_link_rsp" \
    "${ios_link_flags[@]}"
else
  "$cxx" "${common_flags[@]}" -o "$executable_path" \
    "${objects[@]}" \
    "${ios_link_flags[@]}"
fi

cp "$info_plist" "$app_bundle/Info.plist"
if [ "$shell_mode" != "legacy-uikit" ]; then
  while IFS= read -r resource || [ -n "$resource" ]; do
    [ -n "$resource" ] || continue
    cp -R "$resource" "$app_bundle/"
  done < <(json_lines resources "$managed_manifest")
fi
if [ -x /usr/libexec/PlistBuddy ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $product_name" "$app_bundle/Info.plist" >/dev/null
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle_id" "$app_bundle/Info.plist" >/dev/null
  /usr/libexec/PlistBuddy -c "Set :MinimumOSVersion $deployment_target" "$app_bundle/Info.plist" >/dev/null
  /usr/libexec/PlistBuddy -c "Add :MOUIShellMode string $shell_mode" "$app_bundle/Info.plist" >/dev/null 2>&1 || \
    /usr/libexec/PlistBuddy -c "Set :MOUIShellMode $shell_mode" "$app_bundle/Info.plist" >/dev/null
  /usr/libexec/PlistBuddy -c "Add :UIApplicationSceneManifest dict" "$app_bundle/Info.plist" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :UIApplicationSceneManifest:UIApplicationSupportsMultipleScenes bool false" "$app_bundle/Info.plist" >/dev/null 2>&1 || \
    /usr/libexec/PlistBuddy -c "Set :UIApplicationSceneManifest:UIApplicationSupportsMultipleScenes false" "$app_bundle/Info.plist" >/dev/null
fi
if [ "$shell_mode" = "managed" ]; then
  node "$moui_root/mobile/ios/apply-managed-info-plist.mjs" \
    --manifest "$managed_manifest" \
    --plist "$app_bundle/Info.plist"
fi
printf 'APPL????' > "$app_bundle/PkgInfo"

if [ "$sdk" = "iphonesimulator" ] && command -v codesign >/dev/null 2>&1; then
  if codesign --force --sign - "$app_bundle" >/dev/null 2>&1; then
    log "Ad-hoc signed simulator app bundle"
  else
    log "Ad-hoc codesign failed; leaving unsigned simulator app bundle"
  fi
fi

if [ "$sdk" = "iphoneos" ]; then
  log "Built an unsigned iphoneos bundle; real-device install still requires provisioning/signing"
fi

if [ -n "${TARGET_BUILD_DIR:-}" ] && [ -n "${FULL_PRODUCT_NAME:-}" ]; then
  xcode_product="$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"
  if [ "$xcode_product" != "$app_bundle" ]; then
    rm -rf "$xcode_product"
    cp -R "$app_bundle" "$xcode_product"
    log "Staged native target product at $xcode_product"
  fi
fi

log "Wrote $app_bundle"
