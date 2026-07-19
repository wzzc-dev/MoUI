import { existsSync, readdirSync, readFileSync } from "node:fs";
import { basename, dirname, isAbsolute, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

import { validateShellMetadataV1 } from "./shell-config-schema.mjs";
import { readMouiPluginManifests } from "./plugin-manifest.mjs";

/** Root of the independently published wzzc-dev/moui_shell package. */
export const shellPackageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const readJson = path => JSON.parse(readFileSync(path, "utf8"));
const envOr = (name, fallback = "") => process.env[name] || fallback;
const firstExisting = candidates => candidates.find(candidate => candidate && existsSync(candidate)) || "";

const normalized = (root, value) => isAbsolute(value) ? value : resolve(root, value);
const portableRelative = (root, path) => relative(root, path).split(sep).join("/");

export const defaultWorkspaceRoot = () => {
  const fromEnvironment = envOr("MOUI_SHELL_WORKSPACE_ROOT");
  if (fromEnvironment) return resolve(fromEnvironment);
  const cwd = process.cwd();
  if (existsSync(join(cwd, "moon.mod")) || existsSync(join(cwd, "moon.work"))) return cwd;
  const repositoryRoot = resolve(shellPackageRoot, "..");
  return existsSync(join(repositoryRoot, "moon.work")) ? repositoryRoot : cwd;
};

export const defaultMouiRoot = workspaceRoot =>
  firstExisting([
    envOr("MOUI_PACKAGE_ROOT"),
    join(workspaceRoot, "moui"),
    join(workspaceRoot, ".mooncakes/wzzc-dev/moui"),
  ]);

export const defaultShellRoot = workspaceRoot =>
  firstExisting([
    envOr("MOUI_SHELL_PACKAGE_ROOT"),
    join(workspaceRoot, "moui_shell"),
    join(workspaceRoot, ".mooncakes/wzzc-dev/moui_shell"),
    shellPackageRoot,
  ]);

export const defaultSkiaRoot = (workspaceRoot, mouiRoot) =>
  firstExisting([
    envOr("MOUI_SKIA_ROOT"),
    join(workspaceRoot, "moui_skia"),
    join(dirname(mouiRoot), "moui_skia"),
    join(workspaceRoot, ".mooncakes/wzzc-dev/moui_skia"),
  ]);

const appMetadataPath = (workspaceRoot, appId, explicitPath) => {
  if (explicitPath) return normalized(workspaceRoot, explicitPath);
  const candidates = [
    join(workspaceRoot, "examples", appId, "shell.json"),
    join(workspaceRoot, "shell.json"),
  ];
  return candidates.find(path => existsSync(path)) || candidates[0];
};

const assertExistingDirectory = (path, label) => {
  if (!path || !existsSync(path)) throw new Error(`${label} could not be resolved`);
  return resolve(path);
};

const managedMoonPackage = ({ workspaceRoot, metadataPath, platform }) => {
  const appRoot = dirname(metadataPath);
  const candidates = [join(appRoot, `${platform}_skia`), join(appRoot, platform)];
  const selected = candidates.find(path => existsSync(join(path, "moon.pkg"))) || candidates[0];
  if (!existsSync(join(selected, "moon.pkg"))) {
    throw new Error(`shell.json ${platform} entrypoint package is missing: ${selected}`);
  }
  return portableRelative(workspaceRoot, selected);
};

const fixedEmbeddingExports = () => ({
  attachSurface: "moui_embedding_attach_surface",
  resize: "moui_embedding_resize",
  dispatchPointer: "moui_embedding_dispatch_pointer",
  dispatchScroll: "moui_embedding_dispatch_scroll",
  frameTick: "moui_embedding_frame_tick",
  renderFrame: "moui_embedding_render_frame",
  detachSurface: "moui_embedding_detach_surface",
  destroyApplication: "moui_embedding_destroy_application",
  dispatchHostResponseEnvelope: "moui_embedding_dispatch_host_response_envelope_json",
});

const managedPlatformContract = ({ appId, platform, metadataPath, workspaceRoot, shellRoot }) => {
  const moonPackage = managedMoonPackage({ workspaceRoot, metadataPath, platform });
  const safeId = appId.replace(/[^A-Za-z0-9_]/g, "_");
  const appSlug = appId.replaceAll("_", "-");
  const common = {
    moonPackage,
    generatedC: `${basename(moonPackage)}.c`,
    appArg: `moui-${appSlug}-${platform}`,
    moonbitMainAlias: "moui_embedding_moonbit_generated_main",
    exports: fixedEmbeddingExports(),
  };
  if (platform === "android") return { ...common, nativeLibrary: `moui_${safeId}_android` };
  if (platform === "ios") {
    return { ...common, infoPlist: join(shellRoot, "ios/runner/template/Info.plist") };
  }
  return { ...common, nativeLibrary: "moui_embedding_harmonyos" };
};

const shellAppIds = workspaceRoot => {
  const examples = join(workspaceRoot, "examples");
  if (!existsSync(examples)) return existsSync(join(workspaceRoot, "shell.json")) ? [""] : [];
  return readdirSync(examples)
    .filter(name => existsSync(join(examples, name, "shell.json")))
    .sort();
};

/**
 * Read one strict shell.json and derive the fixed v1 embedding table contract.
 * There is intentionally no contract registry or alternate metadata branch.
 */
export const readShellApp = (appId, options = {}) => {
  const workspaceRoot = resolve(options.workspaceRoot || defaultWorkspaceRoot());
  const mouiRoot = assertExistingDirectory(options.mouiRoot || defaultMouiRoot(workspaceRoot), "MoUI package root");
  const shellRoot = assertExistingDirectory(options.shellRoot || defaultShellRoot(workspaceRoot), "MoUI shell package root");
  const skiaRoot = assertExistingDirectory(options.skiaRoot || defaultSkiaRoot(workspaceRoot, mouiRoot), "moui_skia package root");
  const metadataPath = appMetadataPath(workspaceRoot, appId, options.appConfigPath);
  if (!existsSync(metadataPath)) throw new Error(`shell app metadata not found for ${appId}: ${metadataPath}`);
  const metadata = validateShellMetadataV1(readJson(metadataPath), { path: metadataPath, appId });
  const app = {
    id: metadata.id,
    displayName: metadata.displayName,
    artifactName: metadata.artifactName,
    appPackage: metadata.appPackage,
    schemaVersion: metadata.schemaVersion,
    shellApiVersion: metadata.shellApiVersion,
    embeddingApiVersion: metadata.embeddingApiVersion,
    shell: { ...metadata.shell, fullscreen: metadata.shell.systemUi.fullscreen, supportsScroll: true },
    paths: { workspaceRoot, mouiRoot, shellRoot, skiaRoot, metadata: metadataPath },
    plugins: readMouiPluginManifests(metadata.shell.plugins, { workspaceRoot }),
  };
  for (const platform of ["android", "ios", "harmonyos"]) {
    const platformMetadata = metadata[platform];
    if (!platformMetadata) continue;
    app[platform] = {
      ...managedPlatformContract({ appId: metadata.id, platform, metadataPath, workspaceRoot, shellRoot }),
      ...platformMetadata,
      fullscreen: metadata.shell.systemUi.fullscreen,
      supportsScroll: true,
    };
  }
  const grantedPermissions = new Set(metadata.shell.permissions);
  for (const plugin of app.plugins) {
    for (const permission of plugin.permissions) {
      if (!grantedPermissions.has(permission)) {
        throw new Error(`${metadataPath}: plugin ${plugin.id} requires undeclared permission ${JSON.stringify(permission)}`);
      }
    }
  }
  return app;
};

/** Read registered applications without a repository-owned build-contract registry. */
export const readShellApps = (options = {}) => {
  const workspaceRoot = resolve(options.workspaceRoot || defaultWorkspaceRoot());
  const appIds = options.appIds?.length ? options.appIds : shellAppIds(workspaceRoot);
  const apps = {};
  for (const appId of appIds) apps[appId] = readShellApp(appId, { ...options, workspaceRoot });
  return apps;
};
