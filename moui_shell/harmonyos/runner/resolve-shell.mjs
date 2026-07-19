#!/usr/bin/env node

import {
  cpSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { basename, dirname, extname, parse, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

import { readShellApp } from "../../scripts/app-config.mjs";

const permissionCapabilities = new Map([
  ["camera", [{
    name: "ohos.permission.CAMERA",
    reasonResource: "permission_camera",
    purpose: "needs camera access for app features you choose to use.",
  }]],
  ["microphone", [{
    name: "ohos.permission.MICROPHONE",
    reasonResource: "permission_microphone",
    purpose: "needs microphone access for app features you choose to use.",
  }]],
  ["location", [
    {
      name: "ohos.permission.APPROXIMATELY_LOCATION",
      reasonResource: "permission_location",
      purpose: "needs your precise or approximate location while you use the app.",
    },
    {
      name: "ohos.permission.LOCATION",
      reasonResource: "permission_location",
      purpose: "needs your precise or approximate location while you use the app.",
    },
  ]],
  ["photos", [{
    name: "ohos.permission.READ_IMAGEVIDEO",
    reasonResource: "permission_photos",
    purpose: "needs read access to photos and videos you choose to use.",
  }]],
  // Notification permission is requested through notificationManager at runtime.
  ["notifications", []],
  ["clipboard", [{
    name: "ohos.permission.READ_PASTEBOARD",
    reasonResource: "permission_read_pasteboard",
    purpose: "needs access to clipboard content you choose to paste.",
  }]],
]);

const resolvePermissionCapabilities = (capabilities, displayName) => {
  const permissions = [];
  const seen = new Set();
  for (const capability of capabilities) {
    const mapped = permissionCapabilities.get(capability);
    if (!mapped) {
      throw new Error(
        `managed HarmonyOS shell does not support shell.permissions capability ` +
          `${JSON.stringify(capability)}; use a supported capability or eject the HarmonyOS shell`,
      );
    }
    for (const declaration of mapped) {
      if (seen.has(declaration.name)) continue;
      seen.add(declaration.name);
      permissions.push({
        permission: {
          name: declaration.name,
          reason: `$string:${declaration.reasonResource}`,
          usedScene: {
            abilities: ["EntryAbility"],
            when: "inuse",
          },
        },
        reasonResource: declaration.reasonResource,
        reasonValue: `${displayName} ${declaration.purpose}`,
      });
    }
  }
  return permissions.sort((left, right) =>
    left.permission.name.localeCompare(right.permission.name),
  );
};

const options = {
  workspaceRoot: process.cwd(),
  mouiRoot: "",
  app: "",
  appConfig: "",
  renderer: "auto",
  output: "",
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
    case "--renderer": options.renderer = value; break;
    case "--output": options.output = value; break;
    default: throw new Error(`unknown option: ${key}`);
  }
}

if (!options.app || !options.output) {
  throw new Error("--app and --output are required");
}

const workspaceRoot = resolve(options.workspaceRoot);
const app = readShellApp(options.app, {
  workspaceRoot,
  mouiRoot: options.mouiRoot ? resolve(options.mouiRoot) : undefined,
  appConfigPath: options.appConfig || undefined,
});
if (!app.harmonyos) throw new Error(`app ${options.app} does not configure HarmonyOS`);
if (app.harmonyos.runnerMode !== "managed") {
  throw new Error(
    `app ${options.app} requests HarmonyOS runnerMode=${app.harmonyos.runnerMode}; managed shell required`,
  );
}
if (app.schemaVersion !== 1 || app.shellApiVersion !== 1 || app.embeddingApiVersion !== 1 || app.shell.profile !== "handheld") {
  throw new Error("managed HarmonyOS shell requires schema v1, handheld profile, shell API v1, and embedding API v1");
}
if (app.harmonyos.compatibleSdkVersion < 20 || app.harmonyos.compatibleSdkVersion > 21) {
  throw new Error("managed HarmonyOS shell requires compatibleSdkVersion between API 20 and target API 21");
}
if (app.harmonyos.nativeLibrary !== "moui_embedding_harmonyos") {
  throw new Error("managed HarmonyOS shell requires fixed native library moui_embedding_harmonyos");
}
const resolvedPermissions = resolvePermissionCapabilities(
  app.shell.permissions || [],
  app.displayName,
);

const templateRoot = resolve(app.paths.shellRoot, "harmonyos/runner/template");
const outputRoot = resolve(options.output);
if (!existsSync(templateRoot)) throw new Error(`canonical HarmonyOS template not found: ${templateRoot}`);
const containsPath = (root, candidate) => {
  const path = relative(root, candidate);
  return path === "" || (path !== ".." && !path.startsWith(`..${sep}`));
};
if (outputRoot === parse(outputRoot).root || outputRoot === workspaceRoot || outputRoot === app.paths.mouiRoot ||
    containsPath(outputRoot, templateRoot) || containsPath(templateRoot, outputRoot)) {
  throw new Error(`refusing unsafe managed HarmonyOS shell output: ${outputRoot}`);
}
if (existsSync(outputRoot) && readdirSync(outputRoot).length > 0 &&
    !existsSync(resolve(outputRoot, ".moui-managed-shell.json"))) {
  throw new Error(`refusing to replace non-managed HarmonyOS shell directory: ${outputRoot}`);
}
rmSync(outputRoot, { recursive: true, force: true });
mkdirSync(dirname(outputRoot), { recursive: true });
cpSync(templateRoot, outputRoot, { recursive: true });

const readJson = path => JSON.parse(readFileSync(path, "utf8"));
const writeJson = (path, value) => writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
const updateString = (path, name, value) => {
  const resource = readJson(path);
  const item = resource.string.find(entry => entry.name === name);
  if (!item) throw new Error(`${path}: missing string resource ${name}`);
  item.value = value;
  writeJson(path, resource);
};
const upsertString = (path, name, value) => {
  const resource = readJson(path);
  const item = resource.string.find(entry => entry.name === name);
  if (item) item.value = value;
  else resource.string.push({ name, value });
  writeJson(path, resource);
};

const appScopePath = resolve(outputRoot, "AppScope/app.json5");
const appScope = readJson(appScopePath);
appScope.app.bundleName = app.harmonyos.bundleName;
writeJson(appScopePath, appScope);

const rootPackagePath = resolve(outputRoot, "oh-package.json5");
const rootPackage = readJson(rootPackagePath);
rootPackage.name = `${app.id.replaceAll("_", "-")}-harmonyos`;
rootPackage.description = `${app.displayName} managed HarmonyOS shell`;
writeJson(rootPackagePath, rootPackage);

const buildProfilePath = resolve(outputRoot, "build-profile.json5");
const buildProfile = readJson(buildProfilePath);
if (!Array.isArray(buildProfile.modules) || buildProfile.modules.length !== 1) {
  throw new Error(`${buildProfilePath}: canonical shell must contain one entry module`);
}
buildProfile.modules[0].name = app.harmonyos.moduleName;
const compatibleSdkVersion = app.harmonyos.compatibleSdkVersion === 20
  ? "6.0.0(20)"
  : "6.0.1(21)";
for (const product of buildProfile.app.products) {
  product.targetSdkVersion = "6.0.1(21)";
  product.compatibleSdkVersion = compatibleSdkVersion;
}
writeJson(buildProfilePath, buildProfile);

const modulePath = resolve(outputRoot, "entry/src/main/module.json5");
const module = readJson(modulePath);
module.module.name = app.harmonyos.moduleName;
const configuredPermissions = new Map(
  (module.module.requestPermissions || []).map(permission => [permission.name, permission]),
);
const generatedPermissionReasons = new Map();
for (const resolvedPermission of resolvedPermissions) {
  const { permission, reasonResource, reasonValue } = resolvedPermission;
  if (configuredPermissions.has(permission.name)) continue;
  configuredPermissions.set(permission.name, permission);
  generatedPermissionReasons.set(reasonResource, reasonValue);
}
module.module.requestPermissions = [...configuredPermissions.values()].sort((left, right) =>
  left.name.localeCompare(right.name),
);
writeJson(modulePath, module);

const entryPackagePath = resolve(outputRoot, "entry/oh-package.json5");
const entryPackage = readJson(entryPackagePath);
entryPackage.name = app.harmonyos.moduleName;
entryPackage.description = `${app.displayName} managed entry module`;
writeJson(entryPackagePath, entryPackage);

updateString(
  resolve(outputRoot, "AppScope/resources/base/element/string.json"),
  "app_name",
  app.harmonyos.appName,
);
const entryStrings = resolve(outputRoot, "entry/src/main/resources/base/element/string.json");
updateString(entryStrings, "app_name", app.harmonyos.appName);
updateString(entryStrings, "module_desc", app.harmonyos.moduleDescription);
updateString(entryStrings, "entry_desc", app.harmonyos.entryDescription);
for (const [name, value] of generatedPermissionReasons) {
  upsertString(entryStrings, name, value);
}

const generatedConfig = [
  "// Generated by moui_shell/harmonyos/resolve-managed-shell.mjs.",
  "export interface MoUIGeneratedConfiguration {",
  "  appArgument: string;",
  "  renderer: string;",
  "  fullscreen: boolean;",
  "  statusBar: string;",
  "  orientation: string;",
  "}",
  "",
  "export const mouiGeneratedConfiguration: MoUIGeneratedConfiguration = {",
  `  appArgument: ${JSON.stringify(`moui-${app.id.replaceAll("_", "-")}-harmonyos`)},`,
  `  renderer: ${JSON.stringify(options.renderer)},`,
  `  fullscreen: ${app.shell.systemUi.fullscreen ? "true" : "false"},`,
  `  statusBar: ${JSON.stringify(app.shell.systemUi.statusBar)},`,
  `  orientation: ${JSON.stringify(app.shell.orientation)}`,
  "};",
  "",
].join("\n");
writeFileSync(
  resolve(outputRoot, "entry/src/main/ets/moui/MoUIGeneratedConfig.ets"),
  generatedConfig,
);

const collectFiles = path => {
  const files = [];
  const visit = current => {
    if (statSync(current).isDirectory()) {
      for (const name of readdirSync(current).sort()) visit(resolve(current, name));
    } else {
      files.push(current);
    }
  };
  visit(path);
  return files;
};
const portable = path => path.split(sep).join("/");
const withoutExtension = path => path.slice(0, -extname(path).length);
const safeId = value => value.replace(/[^A-Za-z0-9_]/g, "_");
const entryTypePattern = /^[A-Za-z_][A-Za-z0-9_]*$/;
const pluginImports = [];
const pluginInstances = [];
const pluginRecords = [];

for (const [pluginIndex, plugin] of app.plugins.entries()) {
  const platform = plugin.platforms.harmonyos;
  if (!platform) continue;
  if (!entryTypePattern.test(platform.entry)) {
    throw new Error(`${plugin.path}: HarmonyOS entry must be an exported ArkTS class name`);
  }
  const stagedPluginDirectory = `${pluginIndex}-${safeId(plugin.id)}`;
  const destinationRoot = resolve(
    outputRoot,
    "entry/src/main/ets/plugins",
    stagedPluginDirectory,
  );
  const copiedSources = [];
  for (const source of platform.sources) {
    const absoluteSource = resolve(plugin.root, source);
    for (const file of collectFiles(absoluteSource)) {
      const relativeSource = portable(relative(plugin.root, file));
      const destination = resolve(destinationRoot, relativeSource);
      mkdirSync(dirname(destination), { recursive: true });
      cpSync(file, destination);
      copiedSources.push({ source: file, relativeSource, destination });
    }
  }
  const candidates = copiedSources.filter(source =>
    basename(source.relativeSource, extname(source.relativeSource)) === platform.entry,
  );
  const entrySource = candidates.length === 1
    ? candidates[0]
    : copiedSources.length === 1 ? copiedSources[0] : undefined;
  if (!entrySource) {
    throw new Error(
      `${plugin.path}: cannot resolve HarmonyOS entry ${platform.entry}; ` +
        "name one source file after the entry class",
    );
  }
  const importAlias = `MoUIGeneratedPlugin${pluginIndex}`;
  const importPath = portable(withoutExtension(relative(
    resolve(outputRoot, "entry/src/main/ets/moui"),
    entrySource.destination,
  )));
  pluginImports.push(
    `import { ${platform.entry} as ${importAlias} } from ${JSON.stringify(importPath.startsWith(".") ? importPath : `./${importPath}`)};`,
  );
  pluginInstances.push(`new ${importAlias}()`);

  const copiedResources = [];
  for (const resource of platform.resources) {
    const absoluteResource = resolve(plugin.root, resource);
    const destination = resolve(
      outputRoot,
      "entry/src/main/resources/rawfile/moui_plugins",
      stagedPluginDirectory,
      resource,
    );
    mkdirSync(dirname(destination), { recursive: true });
    cpSync(absoluteResource, destination, { recursive: true });
    copiedResources.push(destination);
  }
  pluginRecords.push({
    id: plugin.id,
    entry: platform.entry,
    platformViewKinds: plugin.platformViewKinds,
    hostChannels: plugin.hostChannels,
    sources: copiedSources.map(source => portable(relative(outputRoot, source.destination))),
    resources: copiedResources.map(resource => portable(relative(outputRoot, resource))),
  });
}

const generatedPlugins = [
  "// Generated by moui_shell/harmonyos/resolve-managed-shell.mjs.",
  "import { MoUIPluginRegistry } from './MoUIPlugins';",
  ...pluginImports,
  "",
  "export function installGeneratedPlugins(): void {",
  `  MoUIPluginRegistry.shared.install([${pluginInstances.join(", ")}]);`,
  "}",
  "",
].join("\n");
writeFileSync(
  resolve(outputRoot, "entry/src/main/ets/moui/MoUIGeneratedPlugins.ets"),
  generatedPlugins,
);

const appResourceRecords = [];
for (const [index, resource] of app.shell.resources.entries()) {
  const source = resolve(workspaceRoot, resource);
  if (!existsSync(source)) throw new Error(`managed HarmonyOS resource does not exist: ${source}`);
  const destination = resolve(
    outputRoot,
    "entry/src/main/resources/rawfile/moui_app",
    `${index}-${basename(resource)}`,
  );
  mkdirSync(dirname(destination), { recursive: true });
  cpSync(source, destination, { recursive: true });
  appResourceRecords.push({
    source: resource,
    destination: portable(relative(outputRoot, destination)),
  });
}

writeJson(resolve(outputRoot, ".moui-managed-shell.json"), {
  schemaVersion: 1,
  platform: "harmonyos",
  app: app.id,
  shellApiVersion: app.shellApiVersion,
  embeddingApiVersion: app.embeddingApiVersion,
  runnerMode: app.harmonyos.runnerMode,
  nativeLibrary: app.harmonyos.nativeLibrary,
  compatibleSdkVersion: app.harmonyos.compatibleSdkVersion,
  targetSdkVersion: 21,
  modelVersion: "6.0.1",
  plugins: pluginRecords,
  resources: appResourceRecords,
});
