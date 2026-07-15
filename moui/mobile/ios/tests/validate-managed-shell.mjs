#!/usr/bin/env node

import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const root = resolve(scriptDir, "../../../..");
const path = value => resolve(root, value);
const read = value => readFileSync(path(value), "utf8");

const contains = (source, token, label) => {
  assert.ok(source.includes(token), `${label}: missing ${JSON.stringify(token)}`);
};

const excludes = (source, token, label) => {
  assert.ok(!source.includes(token), `${label}: must not contain ${JSON.stringify(token)}`);
};

const shellPath = "moui/mobile/ios/Sources/MoUIMobileShell/MoUIMobileShell.swift";
const adaptersPath = "moui/mobile/ios/Sources/MoUIMobileShell/MoUIMobileHostAdapters.swift";
const capabilitiesPath = "moui/mobile/ios/Sources/MoUIMobileShell/MoUIMobileCapabilities.swift";
const pluginsPath = "moui/mobile/ios/Sources/MoUIMobileShell/MoUIMobilePlugins.swift";
const bridgePath = "moui/mobile/ios/bridge/MoUIMobileRuntimeBridge.mm";
const bridgeHeaderPath = "moui/mobile/ios/bridge/include/MoUIMobileRuntimeBridge.h";
const appPath = "moui/mobile/ios/template/Sources/MoUIMobileApp.swift";
const packagePath = "moui/mobile/ios/Package.swift";
const resolverPath = "moui/mobile/ios/resolve-managed-shell.mjs";
const builderPath = "moui/scripts/mobile/build-ios-app.sh";
const repositoryBuilderPath = "scripts/build-mobile-ios-app.sh";
const coreBuilderPath = "moui/scripts/mobile/build-ios-app-core.sh";
const legacyPath = "moui/mobile/ios/legacy/moui_mobile_app.mm";

const shell = read(shellPath);
const adapters = read(adaptersPath);
const capabilities = read(capabilitiesPath);
const plugins = read(pluginsPath);
const bridge = read(bridgePath);
const bridgeHeader = read(bridgeHeaderPath);
const app = read(appPath);
const packageManifest = read(packagePath);
const resolver = read(resolverPath);
const builder = read(builderPath);
const repositoryBuilder = read(repositoryBuilderPath);
const coreBuilder = read(coreBuilderPath);

contains(app, "@main", appPath);
assert.match(app, /struct\s+\w+\s*:\s*App\b/, `${appPath}: expected a SwiftUI App entrypoint`);
contains(shell, "UIViewRepresentable", shellPath);
contains(shell, "CAMetalLayer.self", shellPath);
contains(shell, "CADisplayLink", shellPath);
contains(shell, "MOUIPassthroughOverlayView", shellPath);
contains(shell, "MOUIMobileSceneLease", shellPath);
contains(shell, "unsupported: Int32 = -1001", shellPath);
contains(shell, "UIApplicationDelegate", shellPath);
contains(shell, "MOUIMobileStatusBarMode", shellPath);
contains(shell, "MOUIMobileOrientation", shellPath);
contains(shell, ".statusBarHidden", shellPath);

contains(packageManifest, "// swift-tools-version: 5.9", packagePath);
contains(packageManifest, "platforms: [.iOS(.v15)]", packagePath);
contains(packageManifest, "MoUIMobileRuntimeBridge", packagePath);
contains(packageManifest, "MoUIMobileShell", packagePath);

contains(bridge, "moui_mobile_get_runtime_api_v1()", bridgePath);
contains(bridge, "moui_mobile_runtime_api_v1_is_compatible", bridgePath);
contains(bridge, "take_host_update_envelope_json", bridgePath);
contains(bridge, "dispatch_host_response_envelope", bridgePath);
contains(bridge, "complete_clipboard", bridgePath);
contains(bridge, "destroy_application", bridgePath);
contains(bridge, "static const moui_mobile_runtime_api_v1 *const api", bridgePath);
contains(bridge, "return configured;", bridgePath);
for (const token of ["UIApplicationDelegate", "UIViewController", "CADisplayLink", "activeSceneIdentifier", "acquireScene"]) {
  excludes(bridge + bridgeHeader, token, "ObjC++ ABI bridge");
}

contains(adapters, '(envelope["schemaVersion"] as? NSNumber)?.intValue == 1', adaptersPath);
contains(adapters, 'envelope["sessionGeneration"]', adaptersPath);
contains(adapters, "completeClipboardSessionGeneration", adaptersPath);
contains(adapters, '"requestId": key.requestID', adaptersPath);
contains(adapters, '"status": response.status.rawValue', adaptersPath);
contains(adapters, '"payload": response.payload', adaptersPath);
contains(adapters, "candidate_anchor", adaptersPath);
contains(adapters, "action: 4", adaptersPath);
contains(capabilities, 'values["moui.mobile.testProbe"] = enabled', capabilitiesPath);
contains(capabilities, "public final class MOUIMobileRuntimeInputDispatcher", capabilitiesPath);
contains(capabilities, "sessionGeneration: Int", capabilitiesPath);
contains(capabilities, "private let epoch: UInt64", capabilitiesPath);
contains(capabilities, "generation = nil", capabilitiesPath);
contains(capabilities, "epoch &+= 1", capabilitiesPath);
contains(capabilities, "guard Thread.isMainThread else { return false }", capabilitiesPath);
contains(adapters, "pluginCapabilities.publishSemantics", adaptersPath);
contains(plugins, "MOUIMobileHostChannelResponse", pluginsPath);
contains(plugins, "MOUIMobileHostChannelRequest", pluginsPath);
contains(plugins, "disposePlatformView", pluginsPath);
contains(plugins, "MOUIMobilePlatformViewEventSink", pluginsPath);
contains(plugins, "MOUIMobileHostChannelCompletion", pluginsPath);
contains(plugins, "MOUIMobileHostChannelTask", pluginsPath);
contains(plugins, "private struct ViewKey: Hashable", pluginsPath);
contains(plugins, "placement.clip?.intersection", pluginsPath);
contains(plugins, "bringSubviewToFront", pluginsPath);
contains(plugins, '"kind": "platform-view"', pluginsPath);
contains(plugins, '"revision": revision', pluginsPath);
contains(plugins, '"viewKind": viewKind', pluginsPath);
contains(plugins, '"sessionGeneration": sessionGeneration', pluginsPath);

contains(resolver, '["managed", "ejected"].includes(options.shellMode)', resolverPath);
contains(resolver, "app.ios.shellMode !== options.shellMode", resolverPath);
contains(resolver, "swiftSources", resolverPath);
contains(resolver, "objcxxSources", resolverPath);
contains(resolver, "resources", resolverPath);
contains(resolver, "app.mobile.resources", resolverPath);
contains(resolver, "fullscreen:", resolverPath);
contains(resolver, "statusBar:", resolverPath);
contains(resolver, "orientation:", resolverPath);

contains(builder, 'shell_mode="managed"', builderPath);
contains(builder, '--ejected-shell) shell_mode="ejected"', builderPath);
contains(builder, '--legacy-uikit-shell) shell_mode="legacy-uikit"', builderPath);
contains(builder, "--ejected-shell requires --xcode-project", builderPath);
contains(builder, "--ejected-shell requires a versioned .moui-shell.json", builderPath);
contains(builder, "--xcode-project requires --ejected-shell or --legacy-uikit-shell", builderPath);
contains(builder, "--legacy-uikit-shell requires an explicit schema v1 --app-config", builderPath);
contains(builder, "MOUI_MOBILE_ALLOW_LEGACY_CONFIG=1", builderPath);
contains(builder, '"code": "ios-uikit-shell"', builderPath);
contains(builder, 'scheme="$(basename "$xcode_project" .xcodeproj)"', builderPath);
contains(builder, "requires Xcode 15.4 or newer", builderPath);
contains(builder, 'MOUI_MOBILE_IOS_SHELL="$shell_mode"', builderPath);
contains(builder, 'xcode_project="$build_dir/ios-project/MoUIMobileApp.xcodeproj"', builderPath);
contains(builder, 'template_root="$moui_root/mobile/ios/template"', builderPath);
contains(builder, '.moui-managed-ios-stage', builderPath);
contains(builder, "Refusing to replace an unowned iOS project", builderPath);
contains(builder, "Staged canonical iOS shell", builderPath);
excludes(builder, 'xcode_project="$workspace_root/ios_app', builderPath);
contains(repositoryBuilder, 'legacy_uikit_shell=0', repositoryBuilderPath);
contains(repositoryBuilder, 'if [ "$legacy_uikit_shell" -eq 1 ]', repositoryBuilderPath);
contains(repositoryBuilder,
  '--app-config "$repo_root/moui/mobile/legacy/fixtures/$app.mobile.json"',
  repositoryBuilderPath);
contains(coreBuilder, "-swift-version 5", coreBuilderPath);
contains(coreBuilder, "requires deployment target 15.0 or newer", coreBuilderPath);
contains(coreBuilder, "mobile/ios/legacy/moui_mobile_app.mm", coreBuilderPath);
contains(coreBuilder, "mobile/ios/bridge/MoUIMobileRuntimeBridge.mm", coreBuilderPath);
contains(coreBuilder, 'xcode_product="$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"', coreBuilderPath);
contains(coreBuilder, 'compiled_main_alias="moui_mobile_moonbit_generated_main"', coreBuilderPath);
contains(coreBuilder, 'managed|ejected|legacy-uikit', coreBuilderPath);
contains(coreBuilder, '--shell-mode "$shell_mode"', coreBuilderPath);
excludes(coreBuilder, "-DMOUI_MOBILE_RUNTIME_ATTACH_SURFACE", coreBuilderPath);
excludes(coreBuilder, "-DMOUI_MOBILE_RUNTIME_DESTROY_APPLICATION", coreBuilderPath);

const projects = [
  ["moui/mobile/ios/template/MoUIMobileApp.xcodeproj/project.pbxproj", false],
  ["examples/counter/ios_app/MoUICounter.xcodeproj/project.pbxproj", true],
  ["examples/component_gallery/ios_app/ComponentGallery.xcodeproj/project.pbxproj", true],
];
for (const [projectPath, expectsLocalPackage] of projects) {
  const project = read(projectPath);
  contains(project, "PBXNativeTarget", projectPath);
  excludes(project, "PBXLegacyTarget", projectPath);
  contains(project, "LastUpgradeCheck = 1540", projectPath);
  contains(project, "CreatedOnToolsVersion = 15.4", projectPath);
  contains(project, "SWIFT_VERSION = 5.0", projectPath);
  contains(project, "IPHONEOS_DEPLOYMENT_TARGET = 15.0", projectPath);
  contains(project, "ALWAYS_SEARCH_USER_PATHS = NO", projectPath);
  if (expectsLocalPackage) contains(project, "XCLocalSwiftPackageReference", projectPath);
  else excludes(project, "XCLocalSwiftPackageReference", projectPath);
}

for (const schemePath of [
  "moui/mobile/ios/template/MoUIMobileApp.xcodeproj/xcshareddata/xcschemes/MoUIMobileApp.xcscheme",
  "examples/counter/ios_app/MoUICounter.xcodeproj/xcshareddata/xcschemes/MoUICounter.xcscheme",
  "examples/component_gallery/ios_app/ComponentGallery.xcodeproj/xcshareddata/xcschemes/ComponentGallery.xcscheme",
]) {
  const scheme = read(schemePath);
  contains(scheme, 'LastUpgradeVersion="1540"', schemePath);
  assert.match(scheme, /BuildableName="[^"]+\.app"/, `${schemePath}: expected an app product`);
}

for (const plistPath of [
  "moui/mobile/ios/template/Info.plist",
  "examples/counter/ios_app/Info.plist",
  "examples/component_gallery/ios_app/Info.plist",
]) {
  const plist = read(plistPath);
  contains(plist, "UIApplicationSupportsMultipleScenes", plistPath);
  contains(plist, "MOUIShellMode", plistPath);
  contains(plist, "$(MOUI_MOBILE_IOS_SHELL)", plistPath);
  assert.match(
    plist,
    /<key>UIApplicationSupportsMultipleScenes<\/key>\s*<false\/>/,
    `${plistPath}: ABI v1 must explicitly disable concurrent scenes`,
  );
}

assert.ok(existsSync(path(legacyPath)), `${legacyPath}: legacy fixture is missing`);
assert.ok(read(legacyPath).split("\n").length > 500, `${legacyPath}: expected the frozen monolith`);
assert.ok(
  !existsSync(path("moui/mobile/ios/moui_mobile_app.mm")),
  "legacy UIKit monolith must exist only under moui/mobile/ios/legacy",
);

const smokePattern = /MOUI_MOBILE_[A-Z0-9_]*SMOKE|smoke probe|service smoke/i;
for (const productionPath of [shellPath, adaptersPath, pluginsPath, bridgePath, bridgeHeaderPath, appPath]) {
  assert.ok(!smokePattern.test(read(productionPath)), `${productionPath}: production shell contains a smoke probe`);
}

console.log("MoUI iOS managed shell static audit passed");
