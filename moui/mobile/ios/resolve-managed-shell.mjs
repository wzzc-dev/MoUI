#!/usr/bin/env node
import { existsSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { dirname, extname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { readMobileApp } from "../../scripts/mobile/app-config.mjs";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const defaultMouiRoot = resolve(scriptDir, "../..");
const options = {
  workspaceRoot: process.cwd(),
  mouiRoot: defaultMouiRoot,
  skiaRoot: "",
  app: "",
  appConfig: "",
  contracts: "",
  renderer: "auto",
  shellMode: "managed",
  outputSwift: "",
  outputManifest: "",
};

for (let index = 2; index < process.argv.length; index += 1) {
  const key = process.argv[index];
  const value = process.argv[index + 1];
  if (!value || !key.startsWith("--")) throw new Error(`missing value after ${key}`);
  index += 1;
  switch (key) {
    case "--workspace-root": options.workspaceRoot = value; break;
    case "--moui-root": options.mouiRoot = value; break;
    case "--skia-root": options.skiaRoot = value; break;
    case "--app": options.app = value; break;
    case "--app-config": options.appConfig = value; break;
    case "--contracts": options.contracts = value; break;
    case "--renderer": options.renderer = value; break;
    case "--shell-mode": options.shellMode = value; break;
    case "--output-swift": options.outputSwift = value; break;
    case "--output-manifest": options.outputManifest = value; break;
    default: throw new Error(`unknown option: ${key}`);
  }
}

if (!options.app || !options.outputSwift || !options.outputManifest) {
  throw new Error("--app, --output-swift, and --output-manifest are required");
}

const workspaceRoot = resolve(options.workspaceRoot);
const mouiRoot = resolve(options.mouiRoot);
const app = readMobileApp(options.app, {
  workspaceRoot,
  mouiRoot,
  skiaRoot: options.skiaRoot || undefined,
  appConfigPath: options.appConfig || undefined,
  contractsPath: options.contracts || undefined,
});
if (!app.ios) throw new Error(`app ${options.app} does not configure iOS`);
if (!["managed", "ejected"].includes(options.shellMode)) {
  throw new Error("--shell-mode must be managed or ejected");
}
if (app.ios.shellMode !== options.shellMode) {
  throw new Error(
    `app ${options.app} requests iOS shellMode=${app.ios.shellMode}; ${options.shellMode} shell required`,
  );
}

const swiftType = /^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$/;
// Notifications and clipboard use runtime authorization/privacy APIs and have no usage-description key.
const managedPermissions = new Map([
  ["camera", [
    ["NSCameraUsageDescription", "needs camera access for app features you choose to use."],
  ]],
  ["microphone", [
    ["NSMicrophoneUsageDescription", "needs microphone access for app features you choose to use."],
  ]],
  ["location", [
    ["NSLocationWhenInUseUsageDescription", "needs your location while you use the app."],
  ]],
  ["photos", [
    ["NSPhotoLibraryUsageDescription", "needs photo library access for app features you choose to use."],
  ]],
  ["notifications", []],
  ["clipboard", []],
]);
const collectFiles = path => {
  const result = [];
  const visit = current => {
    if (statSync(current).isDirectory()) {
      for (const name of readdirSync(current).sort()) visit(resolve(current, name));
    } else {
      result.push(current);
    }
  };
  visit(path);
  return result;
};

const pluginTypes = [];
const swiftSources = [];
const objcxxSources = [];
const resources = (app.mobile.resources || []).map(resource => resolve(workspaceRoot, resource));
for (const resource of resources) {
  if (!existsSync(resource)) throw new Error(`managed iOS resource does not exist: ${resource}`);
}
for (const plugin of app.plugins) {
  const platform = plugin.platforms.ios;
  if (!platform) continue;
  if (!swiftType.test(platform.entry)) {
    throw new Error(`${plugin.path}: iOS entry must be a Swift type name: ${platform.entry}`);
  }
  pluginTypes.push(platform.entry);
  for (const source of platform.sources) {
    for (const file of collectFiles(resolve(plugin.root, source))) {
      if (extname(file) === ".swift") swiftSources.push(file);
      if (extname(file) === ".mm") objcxxSources.push(file);
    }
  }
  for (const resource of platform.resources) resources.push(resolve(plugin.root, resource));
}

const managedAppArgument = `moui-${app.id.replaceAll("_", "-")}-ios`;
const statusBar = app.mobile.systemUi?.statusBar || "auto";
const orientation = app.mobile.orientation || "any";
const permissionUsageDescriptions = [];
if (options.shellMode === "managed") {
  for (const permission of app.mobile.permissions || []) {
    const declarations = managedPermissions.get(permission);
    if (!declarations) {
      throw new Error(
        `managed iOS shell does not support mobile.permissions entry ${JSON.stringify(permission)}; ` +
          "use a supported permission or eject the iOS shell",
      );
    }
    for (const [plistKey, purpose] of declarations) {
      permissionUsageDescriptions.push({
        permission,
        plistKey,
        description: `${app.displayName} ${purpose}`,
      });
    }
  }
}

const swift = [
  "import MoUIMobileShell",
  "",
  "extension MOUIMobileConfiguration {",
  "    public static let generated = MOUIMobileConfiguration(",
  `        appArgument: ${JSON.stringify(managedAppArgument)},`,
  `        renderer: ${JSON.stringify(options.renderer)},`,
  `        fullscreen: ${app.ios.fullscreen ? "true" : "false"},`,
  `        statusBar: MOUIMobileStatusBarMode(rawValue: ${JSON.stringify(statusBar)}) ?? .auto,`,
  `        orientation: MOUIMobileOrientation(rawValue: ${JSON.stringify(orientation)}) ?? .any,`,
  `        plugins: [${pluginTypes.map(type => `${type}.self`).join(", ")}]`,
  "    )",
  "}",
  "",
].join("\n");
writeFileSync(resolve(options.outputSwift), swift);
writeFileSync(resolve(options.outputManifest), JSON.stringify({
  shellMode: app.ios.shellMode,
  deploymentTarget: app.ios.deploymentTarget,
  permissions: [...(app.mobile.permissions || [])],
  permissionUsageDescriptions,
  swiftSources,
  objcxxSources,
  resources: [...new Set(resources)],
  pluginTypes,
}, null, 2) + "\n");

if (!existsSync(resolve(options.outputSwift))) throw new Error("generated Swift config was not written");
