import { existsSync, readFileSync } from "node:fs";
import { basename, dirname, isAbsolute, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { validateMobileMetadataV2 } from "./mobile-config-schema.mjs";
import { readMouiPluginManifests } from "./plugin-manifest.mjs";

export const mouiPackageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

const readJson = path => JSON.parse(readFileSync(path, "utf8"));

const normalize = (root, value) => {
  if (!value) return "";
  return isAbsolute(value) ? value : resolve(root, value);
};

const envOr = (name, fallback = "") => process.env[name] || fallback;

const firstExisting = candidates => candidates.find(candidate => candidate && existsSync(candidate)) || "";

export const defaultWorkspaceRoot = () => {
  const envRoot = envOr("MOUI_MOBILE_WORKSPACE_ROOT");
  if (envRoot) return resolve(envRoot);
  const cwd = process.cwd();
  if (existsSync(join(cwd, "moon.mod")) || existsSync(join(cwd, "moon.work"))) return cwd;
  const repoRoot = resolve(mouiPackageRoot, "..");
  if (existsSync(join(repoRoot, "moon.work"))) return repoRoot;
  return cwd;
};

export const defaultMouiRoot = workspaceRoot =>
  firstExisting([
    envOr("MOUI_PACKAGE_ROOT"),
    join(workspaceRoot, "moui"),
    join(workspaceRoot, ".mooncakes/wzzc-dev/moui"),
    mouiPackageRoot,
  ]);

export const defaultSkiaRoot = (workspaceRoot, mouiRoot) =>
  firstExisting([
    envOr("MOUI_SKIA_ROOT"),
    join(workspaceRoot, "moui_skia"),
    join(dirname(mouiRoot), "moui_skia"),
    join(workspaceRoot, ".mooncakes/wzzc-dev/moui_skia"),
  ]);

const assertString = (value, label) => {
  if (typeof value !== "string" || value.trim() === "") {
    throw new Error(`${label} must be a non-empty string`);
  }
  return value;
};

const assertBool = (value, label) => {
  if (typeof value !== "boolean") {
    throw new Error(`${label} must be a boolean`);
  }
  return value;
};

const assertObject = (value, label) => {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${label} must be an object`);
  }
  return value;
};

const optionalObject = (value, label) => {
  if (value === undefined) return null;
  return assertObject(value, label);
};

const optionalString = (value, label, fallback = "") => {
  if (value === undefined) return fallback;
  return assertString(value, label);
};

const appMetadataPath = (workspaceRoot, appId, explicitPath) => {
  if (explicitPath) return normalize(workspaceRoot, explicitPath);
  const candidates = [
    join(workspaceRoot, "examples", appId, "mobile.json"),
    join(workspaceRoot, "mobile.json"),
  ];
  return candidates.find(path => existsSync(path)) || candidates[0];
};

const contractsPath = (workspaceRoot, mouiRoot, explicitPath) => {
  const value = explicitPath || envOr("MOUI_MOBILE_CONTRACTS");
  if (value) return normalize(workspaceRoot, value);
  return join(mouiRoot, "mobile/build-contracts.json");
};

const requireMetadata = ({ appId, workspaceRoot, appConfigPath, allowLegacyConfig }) => {
  const path = appMetadataPath(workspaceRoot, appId, appConfigPath || envOr("MOUI_MOBILE_APP_CONFIG"));
  if (!existsSync(path)) {
    throw new Error(`mobile app metadata not found for ${appId}: ${path}`);
  }
  const rawMetadata = assertObject(readJson(path), path);
  if (rawMetadata.schemaVersion === 2) {
    validateMobileMetadataV2(rawMetadata, { path, appId });
    return {
      metadata: {
        ...rawMetadata,
        mobile: {
          ...rawMetadata.mobile,
          fullscreen: rawMetadata.mobile.systemUi.fullscreen,
        },
      },
      path,
      legacy: false,
    };
  }
  if (rawMetadata.schemaVersion !== 1) {
    throw new Error(`${path}: schemaVersion must be 2`);
  }
  if (!allowLegacyConfig && envOr("MOUI_MOBILE_ALLOW_LEGACY_CONFIG") !== "1") {
    throw new Error(
      `${path}: schemaVersion 1 is deprecated and requires the explicit legacy config flag; ` +
        "set MOUI_MOBILE_ALLOW_LEGACY_CONFIG=1 for the Release N compatibility path",
    );
  }
  const metadata = rawMetadata;
  if (metadata.id !== appId) {
    throw new Error(`${path}: id must match requested app ${appId}`);
  }
  assertString(metadata.displayName, `${path}: displayName`);
  assertString(metadata.artifactName, `${path}: artifactName`);
  assertString(metadata.appPackage, `${path}: appPackage`);
  const mobile = assertObject(metadata.mobile, `${path}: mobile`);
  assertBool(mobile.fullscreen, `${path}: mobile.fullscreen`);
  assertBool(mobile.supportsScroll, `${path}: mobile.supportsScroll`);
  const android = optionalObject(metadata.android, `${path}: android`);
  if (android) assertString(android.applicationId, `${path}: android.applicationId`);
  const ios = optionalObject(metadata.ios, `${path}: ios`);
  if (ios) {
    assertString(ios.bundleId, `${path}: ios.bundleId`);
    assertString(ios.productName, `${path}: ios.productName`);
    assertString(ios.infoPlist, `${path}: ios.infoPlist`);
  }
  const harmonyos = optionalObject(metadata.harmonyos, `${path}: harmonyos`);
  if (harmonyos) {
    assertString(harmonyos.bundleName, `${path}: harmonyos.bundleName`);
    assertString(harmonyos.productName, `${path}: harmonyos.productName`);
    optionalString(harmonyos.appName, `${path}: harmonyos.appName`);
    optionalString(harmonyos.moduleName, `${path}: harmonyos.moduleName`);
    optionalString(harmonyos.moduleDescription, `${path}: harmonyos.moduleDescription`);
    optionalString(harmonyos.entryDescription, `${path}: harmonyos.entryDescription`);
  }
  if (!android && !ios && !harmonyos) {
    throw new Error(`${path}: at least one of android, ios, or harmonyos must be configured`);
  }
  return { metadata, path, legacy: true };
};

const validateAndroidContract = (label, contract, supportsScroll) => {
  assertString(contract.moonPackage, `${label}.moonPackage`);
  assertString(contract.generatedC, `${label}.generatedC`);
  assertString(contract.nativeLibrary, `${label}.nativeLibrary`);
  assertString(contract.appArg, `${label}.appArg`);
  assertString(contract.moonbitMainAlias, `${label}.moonbitMainAlias`);
  const exports = assertObject(contract.exports, `${label}.exports`);
  for (const field of ["attachSurface", "resize", "dispatchPointer", "frameTick", "renderFrame", "detachSurface"]) {
    assertString(exports[field], `${label}.exports.${field}`);
  }
  if (supportsScroll) assertString(exports.dispatchScroll, `${label}.exports.dispatchScroll`);
};

const validateIosContract = (label, contract, supportsScroll) => {
  assertString(contract.moonPackage, `${label}.moonPackage`);
  assertString(contract.generatedC, `${label}.generatedC`);
  assertString(contract.appArg, `${label}.appArg`);
  assertString(contract.moonbitMainAlias, `${label}.moonbitMainAlias`);
  const exports = assertObject(contract.exports, `${label}.exports`);
  for (const field of ["attachView", "resize", "dispatchPointer", "frameTick", "renderFrame", "detachView"]) {
    assertString(exports[field], `${label}.exports.${field}`);
  }
  if (supportsScroll) assertString(exports.dispatchScroll, `${label}.exports.dispatchScroll`);
};

const validateHarmonyosContract = (label, contract, supportsScroll) => {
  assertString(contract.moonPackage, `${label}.moonPackage`);
  assertString(contract.generatedC, `${label}.generatedC`);
  assertString(contract.nativeLibrary, `${label}.nativeLibrary`);
  assertString(contract.appArg, `${label}.appArg`);
  assertString(contract.moonbitMainAlias, `${label}.moonbitMainAlias`);
  const exports = assertObject(contract.exports, `${label}.exports`);
  for (const field of ["attachSurface", "resize", "dispatchPointer", "frameTick", "renderFrame", "detachSurface"]) {
    assertString(exports[field], `${label}.exports.${field}`);
  }
  if (supportsScroll) assertString(exports.dispatchScroll, `${label}.exports.dispatchScroll`);
};

const platformContract = ({ appId, platform, metadataPlatform, builtInContracts }) => {
  const fromBuiltIn = builtInContracts?.[appId]?.[platform] || {};
  const hasBuiltIn = Object.keys(fromBuiltIn).length > 0;
  if (!metadataPlatform && !hasBuiltIn) return null;
  const fromNative = metadataPlatform?.native || {};
  const fromBuild = metadataPlatform?.build || {};
  return {
    ...fromBuiltIn,
    ...fromNative,
    ...fromBuild,
    exports: {
      ...(fromBuiltIn.exports || {}),
      ...(fromNative.exports || {}),
      ...(fromBuild.exports || {}),
    },
  };
};

const portableRelative = (root, path) => relative(root, path).split(sep).join("/");

const managedMoonPackage = ({ workspaceRoot, metadataPath, platform }) => {
  const appRoot = dirname(metadataPath);
  const candidates = [
    join(appRoot, `${platform}_skia`),
    join(appRoot, platform),
  ];
  const selected = candidates.find(path => existsSync(join(path, "moon.pkg"))) || candidates[0];
  return portableRelative(workspaceRoot, selected);
};

const managedPlatformContract = ({ appId, platform, metadataPath, workspaceRoot, mouiRoot }) => {
  const moonPackage = managedMoonPackage({ workspaceRoot, metadataPath, platform });
  const generatedC = `${basename(moonPackage)}.c`;
  const safeId = appId.replace(/[^A-Za-z0-9_]/g, "_");
  const appSlug = appId.replaceAll("_", "-");
  const common = {
    moonPackage,
    generatedC,
    appArg: `moui-${appSlug}-${platform}`,
    moonbitMainAlias: "moui_mobile_moonbit_generated_main",
  };
  if (platform === "android") {
    return {
      ...common,
      nativeLibrary: `moui_${safeId}_android`,
      exports: {
        attachSurface: "moui_mobile_attach_surface",
        resize: "moui_mobile_resize",
        dispatchPointer: "moui_mobile_dispatch_pointer",
        dispatchScroll: "moui_mobile_dispatch_scroll",
        frameTick: "moui_mobile_frame_tick",
        renderFrame: "moui_mobile_render_frame",
        detachSurface: "moui_mobile_detach_surface",
        destroyApplication: "moui_mobile_destroy_application",
        dispatchHostResponseEnvelope: "moui_mobile_dispatch_host_response_envelope_json",
      },
    };
  }
  if (platform === "ios") {
    return {
      ...common,
      infoPlist: join(mouiRoot, "mobile/ios/template/Info.plist"),
      exports: {
        attachView: "moui_mobile_attach_surface",
        resize: "moui_mobile_resize",
        dispatchPointer: "moui_mobile_dispatch_pointer",
        dispatchScroll: "moui_mobile_dispatch_scroll",
        frameTick: "moui_mobile_frame_tick",
        renderFrame: "moui_mobile_render_frame",
        detachView: "moui_mobile_detach_surface",
        destroyApplication: "moui_mobile_destroy_application",
        dispatchHostResponseEnvelope: "moui_mobile_dispatch_host_response_envelope_json",
      },
    };
  }
  return {
    ...common,
    nativeLibrary: "moui_mobile_harmonyos",
    exports: {
      attachSurface: "moui_mobile_attach_surface",
      resize: "moui_mobile_resize",
      dispatchPointer: "moui_mobile_dispatch_pointer",
      dispatchScroll: "moui_mobile_dispatch_scroll",
      frameTick: "moui_mobile_frame_tick",
      renderFrame: "moui_mobile_render_frame",
      detachSurface: "moui_mobile_detach_surface",
      destroyApplication: "moui_mobile_destroy_application",
      dispatchHostResponseEnvelope: "moui_mobile_dispatch_host_response_envelope_json",
    },
  };
};

const readContracts = path => {
  if (!existsSync(path)) return {};
  const contracts = assertObject(readJson(path), path);
  if (contracts.schemaVersion !== 1) {
    throw new Error(`${path}: schemaVersion must be 1`);
  }
  return assertObject(contracts.apps, `${path}: apps`);
};

const mergeApp = ({ appId, metadata, metadataPath, contractsFile, builtInContracts, workspaceRoot, mouiRoot, skiaRoot }) => {
  const mobile = metadata.mobile;
  const legacyConfig = metadata.schemaVersion === 1;
  const contractFor = (platform, metadataPlatform) => {
    if (!metadataPlatform) return null;
    if (!legacyConfig) {
      return managedPlatformContract({
        appId,
        platform,
        metadataPath,
        workspaceRoot,
        mouiRoot,
      });
    }
    return platformContract({
      appId,
      platform,
      metadataPlatform,
      builtInContracts,
    });
  };
  const androidContract = contractFor("android", metadata.android);
  const iosContract = contractFor("ios", metadata.ios);
  const harmonyosContract = contractFor("harmonyos", metadata.harmonyos);
  if (androidContract && legacyConfig) {
    validateAndroidContract(`${metadataPath}: android.native or ${contractsFile}: apps.${appId}.android`, androidContract, mobile.supportsScroll);
  }
  if (iosContract && legacyConfig) {
    validateIosContract(`${metadataPath}: ios.native or ${contractsFile}: apps.${appId}.ios`, iosContract, mobile.supportsScroll);
  }
  if (harmonyosContract && legacyConfig) {
    validateHarmonyosContract(`${metadataPath}: harmonyos.native or ${contractsFile}: apps.${appId}.harmonyos`, harmonyosContract, mobile.supportsScroll);
  }
  const app = {
    id: appId,
    displayName: metadata.displayName,
    artifactName: metadata.artifactName,
    appPackage: metadata.appPackage,
    schemaVersion: metadata.schemaVersion,
    shellApiVersion: metadata.shellApiVersion || 0,
    runtimeAbiVersion: metadata.runtimeAbiVersion || 0,
    mobile: {
      ...mobile,
      supportsScroll: Boolean(
        androidContract?.exports?.dispatchScroll ||
          iosContract?.exports?.dispatchScroll ||
          harmonyosContract?.exports?.dispatchScroll,
      ),
    },
    paths: {
      workspaceRoot,
      mouiRoot,
      skiaRoot,
      metadata: metadataPath,
      contracts: contractsFile,
    },
  };
  if (legacyConfig) {
    app.deprecations = [{
      code: "mobile-config-schema-v1",
      removal: "Release N+1",
      message: "schemaVersion 1 and app-specific native export maps are deprecated",
    }];
  }
  if (androidContract) {
    app.android = {
      ...androidContract,
      applicationId: metadata.android.applicationId,
      fullscreen: mobile.fullscreen,
      supportsScroll: legacyConfig ? mobile.supportsScroll : Boolean(androidContract.exports?.dispatchScroll),
      shellMode: metadata.android.shellMode || "legacy",
      minSdk: metadata.android.minSdk || 0,
    };
  }
  if (iosContract) {
    app.ios = {
      ...iosContract,
      bundleId: metadata.ios.bundleId,
      productName: metadata.ios.productName,
      infoPlist: metadata.ios.infoPlist || join(mouiRoot, "mobile/ios/template/Info.plist"),
      fullscreen: mobile.fullscreen,
      supportsScroll: legacyConfig ? mobile.supportsScroll : Boolean(iosContract.exports?.dispatchScroll),
      shellMode: metadata.ios.shellMode || "legacy",
      deploymentTarget: metadata.ios.deploymentTarget || "0",
    };
  }
  if (harmonyosContract) {
    app.harmonyos = {
      ...harmonyosContract,
      bundleName: metadata.harmonyos.bundleName,
      productName: metadata.harmonyos.productName,
      appName: optionalString(metadata.harmonyos.appName, `${metadataPath}: harmonyos.appName`, metadata.displayName),
      moduleName: optionalString(metadata.harmonyos.moduleName, `${metadataPath}: harmonyos.moduleName`, "entry"),
      moduleDescription: optionalString(metadata.harmonyos.moduleDescription, `${metadataPath}: harmonyos.moduleDescription`, metadata.displayName),
      entryDescription: optionalString(metadata.harmonyos.entryDescription, `${metadataPath}: harmonyos.entryDescription`, metadata.displayName),
      fullscreen: mobile.fullscreen,
      supportsScroll: legacyConfig ? mobile.supportsScroll : Boolean(harmonyosContract.exports?.dispatchScroll),
      shellMode: metadata.harmonyos.shellMode || "legacy",
      compatibleSdkVersion: metadata.harmonyos.compatibleSdkVersion || 0,
    };
  }
  return app;
};

export const readMobileApp = (appId, options = {}) => {
  const workspaceRoot = resolve(options.workspaceRoot || defaultWorkspaceRoot());
  const mouiRootValue = options.mouiRoot || defaultMouiRoot(workspaceRoot);
  if (!mouiRootValue) throw new Error("unable to resolve MoUI package root; set MOUI_PACKAGE_ROOT or --moui-root");
  const mouiRoot = resolve(mouiRootValue);
  const skiaRootValue = options.skiaRoot || defaultSkiaRoot(workspaceRoot, mouiRoot);
  if (!skiaRootValue) throw new Error("unable to resolve moui_skia root; set MOUI_SKIA_ROOT or --skia-root");
  const skiaRoot = resolve(skiaRootValue);
  const contractsFile = contractsPath(workspaceRoot, mouiRoot, options.contractsPath);
  const builtInContracts = readContracts(contractsFile);
  const { metadata, path: metadataPath } = requireMetadata({
    appId,
    workspaceRoot,
    appConfigPath: options.appConfigPath,
    allowLegacyConfig: options.allowLegacyConfig === true,
  });
  const app = mergeApp({
    appId,
    metadata,
    metadataPath,
    contractsFile,
    builtInContracts,
    workspaceRoot,
    mouiRoot,
    skiaRoot,
  });
  app.plugins = metadata.schemaVersion === 2
    ? readMouiPluginManifests(metadata.mobile.plugins, { workspaceRoot })
    : [];
  const grantedPermissions = new Set(metadata.mobile.permissions || []);
  for (const plugin of app.plugins) {
    for (const permission of plugin.permissions) {
      if (!grantedPermissions.has(permission)) {
        throw new Error(
          `${metadataPath}: plugin ${plugin.id} requires undeclared permission ${JSON.stringify(permission)}`,
        );
      }
    }
  }
  return app;
};

export const readMobileApps = (options = {}) => {
  const workspaceRoot = resolve(options.workspaceRoot || defaultWorkspaceRoot());
  const mouiRootValue = options.mouiRoot || defaultMouiRoot(workspaceRoot);
  if (!mouiRootValue) throw new Error("unable to resolve MoUI package root; set MOUI_PACKAGE_ROOT or --moui-root");
  const mouiRoot = resolve(mouiRootValue);
  const contractsFile = contractsPath(workspaceRoot, mouiRoot, options.contractsPath);
  const builtInContracts = readContracts(contractsFile);
  const appIds = options.appIds && options.appIds.length > 0
    ? options.appIds
    : Object.keys(builtInContracts).sort();
  const apps = {};
  for (const appId of appIds) {
    apps[appId] = readMobileApp(appId, { ...options, workspaceRoot, mouiRoot, contractsPath: contractsFile });
  }
  return apps;
};
