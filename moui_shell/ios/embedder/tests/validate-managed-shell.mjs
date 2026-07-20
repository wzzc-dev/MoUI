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

const shellPath = "moui_shell/ios/embedder/Sources/MoUIMobileShell/MoUIMobileShell.swift";
const adaptersPath = "moui_shell/ios/embedder/Sources/MoUIMobileShell/MoUIMobileHostAdapters.swift";
const capabilitiesPath = "moui_shell/ios/embedder/Sources/MoUIMobileShell/MoUIMobileCapabilities.swift";
const pluginsPath = "moui_shell/ios/embedder/Sources/MoUIMobileShell/MoUIMobilePlugins.swift";
const bridgePath = "moui_shell/ios/embedder/bridge/MoUIMobileRuntimeBridge.mm";
const bridgeHeaderPath = "moui_shell/ios/embedder/bridge/include/MoUIMobileRuntimeBridge.h";
const bridgeModulePath = "moui_shell/ios/embedder/bridge/include/module.modulemap";
const appPath = "moui_shell/ios/runner/template/Sources/MoUIMobileApp.swift";
const packagePath = "moui_shell/ios/Package.swift";
const resolverPath = "moui_shell/ios/runner/resolve-shell.mjs";
const plistWriterPath = "moui_shell/ios/apply-managed-info-plist.mjs";
const builderPath = "moui_cli/build_ios.mbt";
const coreBuilderPath = "moui_cli/build_ios_core.mbt";

const shell = read(shellPath);
const adapters = read(adaptersPath);
const capabilities = read(capabilitiesPath);
const plugins = read(pluginsPath);
const bridge = read(bridgePath);
const bridgeHeader = read(bridgeHeaderPath);
const bridgeModule = read(bridgeModulePath);
const app = read(appPath);
const packageManifest = read(packagePath);
const resolver = read(resolverPath);
const plistWriter = read(plistWriterPath);
const builder = read(builderPath);
const coreBuilder = read(coreBuilderPath);

contains(app, "@main", appPath);
assert.match(app, /struct\s+\w+\s*:\s*App\b/, `${appPath}: expected a SwiftUI App entrypoint`);
contains(shell, "UIViewRepresentable", shellPath);
contains(shell, "CAMetalLayer.self", shellPath);
contains(shell, "CADisplayLink", shellPath);
contains(shell, "MOUIPassthroughOverlayView", shellPath);
contains(shell, "MOUIShellSceneLease", shellPath);
contains(shell, "unsupported: Int32 = -1001", shellPath);
contains(shell, "UIApplicationDelegate", shellPath);
contains(shell, "MOUIShellStatusBarMode", shellPath);
contains(shell, "MOUIShellOrientation", shellPath);
contains(shell, ".statusBarHidden", shellPath);

contains(packageManifest, "// swift-tools-version: 5.9", packagePath);
contains(packageManifest, "platforms: [.iOS(.v15)]", packagePath);
contains(packageManifest, "MoUIShellRuntimeBridge", packagePath);
contains(packageManifest, "MoUIShellShell", packagePath);
contains(packageManifest, 'path: "embedder/bridge"', packagePath);
contains(packageManifest, 'path: "embedder/Sources/MoUIMobileShell"', packagePath);

contains(bridge, "moui_embedding_get_api_v1()", bridgePath);
contains(bridge, '#import "MoUIMobileRuntimeBridge.h"', bridgePath);
contains(bridgeModule, 'umbrella header "MoUIMobileRuntimeBridge.h"', bridgeModulePath);
contains(bridge, "moui_embedding_api_v1_is_compatible", bridgePath);
contains(bridge, "take_host_update_envelope_json", bridgePath);
contains(bridge, "dispatch_host_response_envelope", bridgePath);
contains(bridge, "complete_clipboard", bridgePath);
contains(bridge, "destroy_application", bridgePath);
contains(bridge, "static const moui_embedding_api_v1 *const api", bridgePath);
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
contains(capabilities, 'values["moui.shell.testProbe"] = enabled', capabilitiesPath);
contains(capabilities, "public final class MOUIShellRuntimeInputDispatcher", capabilitiesPath);
contains(capabilities, "sessionGeneration: Int", capabilitiesPath);
contains(capabilities, "private let epoch: UInt64", capabilitiesPath);
contains(capabilities, "generation = nil", capabilitiesPath);
contains(capabilities, "epoch &+= 1", capabilitiesPath);
contains(capabilities, "guard Thread.isMainThread else { return false }", capabilitiesPath);
contains(adapters, "pluginCapabilities.publishSemantics", adaptersPath);
contains(plugins, "MOUIEmbedderHostChannelResponse", pluginsPath);
contains(plugins, "MOUIEmbedderHostChannelRequest", pluginsPath);
contains(plugins, "disposePlatformView", pluginsPath);
contains(plugins, "MOUIShellPlatformViewEventSink", pluginsPath);
contains(plugins, "MOUIEmbedderHostChannelCompletion", pluginsPath);
contains(plugins, "MOUIEmbedderHostChannelTask", pluginsPath);
contains(plugins, "private struct ViewKey: Hashable", pluginsPath);
contains(plugins, "placement.clip?.intersection", pluginsPath);
contains(plugins, "bringSubviewToFront", pluginsPath);
contains(plugins, '"kind": "platform-view"', pluginsPath);
contains(plugins, '"revision": revision', pluginsPath);
contains(plugins, '"viewKind": viewKind', pluginsPath);
contains(plugins, '"sessionGeneration": sessionGeneration', pluginsPath);

contains(resolver, '["managed", "ejected"].includes(options.runnerMode)', resolverPath);
contains(resolver, "app.ios.runnerMode !== options.runnerMode", resolverPath);
contains(resolver, "swiftSources", resolverPath);
contains(resolver, "objcxxSources", resolverPath);
contains(resolver, "resources", resolverPath);
contains(resolver, "app.shell.resources", resolverPath);
contains(resolver, "fullscreen:", resolverPath);
contains(resolver, "statusBar:", resolverPath);
contains(resolver, "orientation:", resolverPath);
contains(resolver, "app.ios.deploymentTarget", resolverPath);
contains(resolver, "permissionUsageDescriptions", resolverPath);
contains(resolver, "NSCameraUsageDescription", resolverPath);
contains(resolver, "NSPhotoLibraryUsageDescription", resolverPath);
contains(resolver, "eject the iOS shell", resolverPath);
contains(plistWriter, "validatePermissionUsageDescriptions", plistWriterPath);
contains(plistWriter, 'spawnSync("plutil"', plistWriterPath);

contains(builder, '"ejected"', builderPath);
contains(builder, '"managed"', builderPath);
contains(builder, "--ejected-shell requires --xcode-project", builderPath);
contains(builder, "ios-project/MoUIShellApp.xcodeproj", builderPath);
contains(builder, "requires Xcode 15.4 or newer", builderPath);
contains(builder, 'MOUI_EMBEDDING_IOS_SHELL', builderPath);
contains(builder, "ios/runner/template", builderPath);
contains(builder, ".moui-managed-ios-stage", builderPath);
contains(builder, "refusing to replace an unowned iOS project", builderPath);
contains(builder, "Staged canonical iOS shell", builderPath);
contains(coreBuilder, "-swift-version", coreBuilderPath);
contains(coreBuilder, "requires deployment target 15.0 or newer", coreBuilderPath);
contains(coreBuilder, "MoUIMobileRuntimeBridge.mm", coreBuilderPath);
contains(coreBuilder, "moui_embedding_moonbit_generated_main", coreBuilderPath);
contains(coreBuilder, "module-name", coreBuilderPath);
contains(coreBuilder, 'shell_mode == "ejected"', coreBuilderPath);
excludes(coreBuilder, "MOUI_EMBEDDING_API_ATTACH_SURFACE", coreBuilderPath);
excludes(coreBuilder, "MOUI_EMBEDDING_API_DESTROY_APPLICATION", coreBuilderPath);

const projects = [
  ["moui_shell/ios/runner/template/MoUIShellApp.xcodeproj/project.pbxproj", false],
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
  "moui_shell/ios/runner/template/MoUIShellApp.xcodeproj/xcshareddata/xcschemes/MoUIMobileApp.xcscheme",
]) {
  const scheme = read(schemePath);
  contains(scheme, 'LastUpgradeVersion="1540"', schemePath);
  assert.match(scheme, /BuildableName="[^"]+\.app"/, `${schemePath}: expected an app product`);
}

for (const plistPath of [
  "moui_shell/ios/runner/template/Info.plist",
]) {
  const plist = read(plistPath);
  contains(plist, "UIApplicationSupportsMultipleScenes", plistPath);
  contains(plist, "MOUIShellMode", plistPath);
  contains(plist, "$(MOUI_EMBEDDING_IOS_SHELL)", plistPath);
  assert.match(
    plist,
    /<key>UIApplicationSupportsMultipleScenes<\/key>\s*<false\/>/,
    `${plistPath}: ABI v1 must explicitly disable concurrent scenes`,
  );
}

const smokePattern = /MOUI_EMBEDDING_[A-Z0-9_]*SMOKE|smoke probe|service smoke/i;
for (const productionPath of [shellPath, adaptersPath, pluginsPath, bridgePath, bridgeHeaderPath, appPath]) {
  assert.ok(!smokePattern.test(read(productionPath)), `${productionPath}: production shell contains a smoke probe`);
}

console.log("MoUI iOS managed shell static audit passed");
