import {
  existsSync,
  lstatSync,
  readFileSync,
  readdirSync,
  realpathSync,
  statSync,
} from "node:fs";
import { dirname, extname, isAbsolute, relative, resolve, sep } from "node:path";

const platformSourceExtensions = {
  android: new Set([".kt", ".java"]),
  ios: new Set([".swift", ".mm", ".h", ".hpp"]),
  harmonyos: new Set([".ets", ".ts"]),
};

const forbiddenNames = new Set([
  "CMakeLists.txt",
  "Package.swift",
  "Podfile",
  "build-profile.json5",
  "build.gradle",
  "build.gradle.kts",
  "hvigorfile.ts",
  "hvigor-config.json5",
  "oh-package.json5",
  "package.json",
  "settings.gradle",
  "settings.gradle.kts",
]);

const fail = (path, message) => {
  throw new Error(`${path}: ${message}`);
};

const object = (value, path) => {
  if (value === null || typeof value !== "object" || Array.isArray(value)) fail(path, "must be an object");
  return value;
};

const string = (value, path) => {
  if (typeof value !== "string" || value.trim() === "") fail(path, "must be a non-empty string");
  return value;
};

const exactKeys = (value, allowed, required, path) => {
  const record = object(value, path);
  for (const key of Object.keys(record)) {
    if (!allowed.includes(key)) fail(path, `unknown field ${JSON.stringify(key)}`);
  }
  for (const key of required) {
    if (!(key in record)) fail(path, `missing required field ${JSON.stringify(key)}`);
  }
  return record;
};

const identifiers = (value, path) => {
  if (!Array.isArray(value)) fail(path, "must be an array");
  const result = value.map((item, index) => string(item, `${path}[${index}]`));
  if (new Set(result).size !== result.length) fail(path, "must not contain duplicates");
  for (const item of result) {
    if (item === "moui" || item.startsWith("moui.")) {
      fail(path, `reserved moui.* namespace: ${JSON.stringify(item)}`);
    }
  }
  return result;
};

const relativePaths = (value, path) => {
  if (!Array.isArray(value)) fail(path, "must be an array");
  const result = value.map((item, index) => string(item, `${path}[${index}]`));
  if (new Set(result).size !== result.length) fail(path, "must not contain duplicates");
  for (const item of result) {
    if (isAbsolute(item) || item.split(/[\\/]/).includes("..")) {
      fail(path, `path must stay inside the plugin: ${JSON.stringify(item)}`);
    }
  }
  return result;
};

const isInside = (root, candidate) => {
  const path = relative(root, candidate);
  return path === "" || (!path.startsWith(`..${sep}`) && path !== "..");
};

const checkedRealPath = (path, root, label) => {
  if (!existsSync(path)) fail(label, `path does not exist: ${path}`);
  const real = realpathSync(path);
  if (!isInside(root, real)) fail(label, `path escapes plugin root: ${path}`);
  return real;
};

const walkFiles = root => {
  const files = [];
  const visitedDirectories = new Set();
  const visit = path => {
    const info = lstatSync(path);
    if (info.isSymbolicLink()) {
      const target = realpathSync(path);
      if (!isInside(root, target)) fail(path, `symlink escapes plugin root: ${target}`);
      if (statSync(target).isDirectory()) visit(target);
      else files.push(target);
      return;
    }
    if (info.isDirectory()) {
      const real = realpathSync(path);
      if (visitedDirectories.has(real)) return;
      visitedDirectories.add(real);
      const name = path.slice(path.lastIndexOf(sep) + 1);
      if (path !== root && name === "jniLibs") fail(path, "jniLibs requires an ejected shell");
      if (name.endsWith(".framework") || name.endsWith(".xcframework")) {
        fail(path, "managed plugins cannot contain native dependencies; eject the shell instead");
      }
      for (const name of readdirSync(path)) visit(resolve(path, name));
      return;
    }
    files.push(path);
  };
  visit(root);
  return files;
};

const validateNoBuildExtensions = (pluginRoot, manifestPath) => {
  for (const path of walkFiles(pluginRoot)) {
    if (path === manifestPath) continue;
    const name = path.slice(path.lastIndexOf(sep) + 1);
    if (forbiddenNames.has(name) || name.endsWith(".cmake") || name.endsWith(".gradle")) {
      fail(path, "managed plugins cannot contain dependency or build scripts; eject the shell instead");
    }
    if ([".a", ".aar", ".dylib", ".jar", ".klib", ".so", ".swiftmodule"].includes(extname(name))) {
      fail(path, "managed plugins cannot contain native dependencies; eject the shell instead");
    }
  }
};

const validatePlatform = (value, platform, path, pluginRoot) => {
  const record = exactKeys(value, ["sources", "resources", "entry"], ["sources", "resources", "entry"], path);
  const sources = relativePaths(record.sources, `${path}.sources`);
  const resources = relativePaths(record.resources, `${path}.resources`);
  string(record.entry, `${path}.entry`);
  if (sources.length === 0) fail(`${path}.sources`, "must contain at least one source path");
  for (const source of sources) {
    const real = checkedRealPath(resolve(pluginRoot, source), pluginRoot, `${path}.sources`);
    const sourceFiles = statSync(real).isDirectory() ? walkFiles(real) : [real];
    for (const file of sourceFiles) {
      const extension = extname(file);
      if (!platformSourceExtensions[platform].has(extension)) {
        fail(`${path}.sources`, `unsupported ${platform} source extension ${JSON.stringify(extension)}: ${file}`);
      }
    }
  }
  for (const resource of resources) {
    checkedRealPath(resolve(pluginRoot, resource), pluginRoot, `${path}.resources`);
  }
  return { sources, resources, entry: record.entry };
};

export const readMouiPluginManifest = (manifestPath, { workspaceRoot } = {}) => {
  const resolvedWorkspace = realpathSync(resolve(workspaceRoot || process.cwd()));
  const requestedManifest = resolve(manifestPath);
  if (!existsSync(requestedManifest)) fail(requestedManifest, "plugin manifest does not exist");
  const resolvedManifest = realpathSync(requestedManifest);
  if (!isInside(resolvedWorkspace, resolvedManifest)) fail(requestedManifest, "plugin must be inside the workspace");
  const pluginRoot = realpathSync(dirname(resolvedManifest));
  const manifest = exactKeys(
    JSON.parse(readFileSync(resolvedManifest, "utf8")),
    ["schemaVersion", "id", "shellApi", "platforms", "platformViewKinds", "hostChannels", "permissions"],
    ["schemaVersion", "id", "shellApi", "platforms", "platformViewKinds", "hostChannels", "permissions"],
    resolvedManifest,
  );
  if (manifest.schemaVersion !== 1) fail(resolvedManifest, "schemaVersion must be 1");
  if (manifest.shellApi !== 1) fail(resolvedManifest, "shellApi must be 1");
  string(manifest.id, `${resolvedManifest}.id`);
  if (manifest.id === "moui" || manifest.id.startsWith("moui.")) {
    fail(`${resolvedManifest}.id`, "moui.* is a reserved namespace");
  }
  const platforms = exactKeys(manifest.platforms, ["android", "ios", "harmonyos"], [], `${resolvedManifest}.platforms`);
  if (Object.keys(platforms).length === 0) fail(`${resolvedManifest}.platforms`, "must configure at least one platform");
  const normalizedPlatforms = {};
  for (const platform of Object.keys(platforms)) {
    normalizedPlatforms[platform] = validatePlatform(
      platforms[platform],
      platform,
      `${resolvedManifest}.platforms.${platform}`,
      pluginRoot,
    );
  }
  const platformViewKinds = identifiers(manifest.platformViewKinds, `${resolvedManifest}.platformViewKinds`);
  const hostChannels = identifiers(manifest.hostChannels, `${resolvedManifest}.hostChannels`);
  const permissions = identifiers(manifest.permissions, `${resolvedManifest}.permissions`);
  validateNoBuildExtensions(pluginRoot, resolvedManifest);
  return {
    schemaVersion: 1,
    id: manifest.id,
    shellApi: 1,
    path: resolvedManifest,
    root: pluginRoot,
    platforms: normalizedPlatforms,
    platformViewKinds,
    hostChannels,
    permissions,
  };
};

const assertGloballyUnique = (plugins, field, label) => {
  const owners = new Map();
  for (const plugin of plugins) {
    for (const value of plugin[field]) {
      const owner = owners.get(value);
      if (owner) fail(label, `${JSON.stringify(value)} is declared by both ${owner} and ${plugin.id}`);
      owners.set(value, plugin.id);
    }
  }
};

export const readMouiPluginManifests = (paths, { workspaceRoot } = {}) => {
  const root = resolve(workspaceRoot || process.cwd());
  const plugins = paths.map(path => readMouiPluginManifest(resolve(root, path), { workspaceRoot: root }));
  const ids = new Set();
  for (const plugin of plugins) {
    if (ids.has(plugin.id)) fail("mobile.plugins", `duplicate plugin id ${JSON.stringify(plugin.id)}`);
    ids.add(plugin.id);
  }
  assertGloballyUnique(plugins, "platformViewKinds", "mobile.plugins");
  assertGloballyUnique(plugins, "hostChannels", "mobile.plugins");
  return plugins;
};
