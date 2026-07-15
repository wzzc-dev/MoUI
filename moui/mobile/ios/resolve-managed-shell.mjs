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
  app: "",
  appConfig: "",
  contracts: "",
  renderer: "auto",
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
    case "--app": options.app = value; break;
    case "--app-config": options.appConfig = value; break;
    case "--contracts": options.contracts = value; break;
    case "--renderer": options.renderer = value; break;
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
  appConfigPath: options.appConfig || undefined,
  contractsPath: options.contracts || undefined,
});
if (!app.ios) throw new Error(`app ${options.app} does not configure iOS`);
if (app.ios.shellMode !== "managed") {
  throw new Error(`app ${options.app} requests iOS shellMode=${app.ios.shellMode}; managed shell required`);
}

const swiftType = /^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$/;
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
  swiftSources,
  objcxxSources,
  resources: [...new Set(resources)],
  pluginTypes,
}, null, 2) + "\n");

if (!existsSync(resolve(options.outputSwift))) throw new Error("generated Swift config was not written");
