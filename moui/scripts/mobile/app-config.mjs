import { existsSync, readFileSync } from "node:fs";
import { dirname, isAbsolute, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

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

const requireMetadata = ({ appId, workspaceRoot, appConfigPath }) => {
  const path = appMetadataPath(workspaceRoot, appId, appConfigPath || envOr("MOUI_MOBILE_APP_CONFIG"));
  if (!existsSync(path)) {
    throw new Error(`mobile app metadata not found for ${appId}: ${path}`);
  }
  const metadata = assertObject(readJson(path), path);
  if (metadata.schemaVersion !== 1) {
    throw new Error(`${path}: schemaVersion must be 1`);
  }
  if (metadata.id !== appId) {
    throw new Error(`${path}: id must match requested app ${appId}`);
  }
  assertString(metadata.displayName, `${path}: displayName`);
  assertString(metadata.artifactName, `${path}: artifactName`);
  assertString(metadata.appPackage, `${path}: appPackage`);
  const mobile = assertObject(metadata.mobile, `${path}: mobile`);
  assertBool(mobile.fullscreen, `${path}: mobile.fullscreen`);
  assertBool(mobile.supportsScroll, `${path}: mobile.supportsScroll`);
  const android = assertObject(metadata.android, `${path}: android`);
  assertString(android.applicationId, `${path}: android.applicationId`);
  const ios = assertObject(metadata.ios, `${path}: ios`);
  assertString(ios.bundleId, `${path}: ios.bundleId`);
  assertString(ios.productName, `${path}: ios.productName`);
  assertString(ios.infoPlist, `${path}: ios.infoPlist`);
  return { metadata, path };
};

const validateAndroidContract = (label, contract, supportsScroll) => {
  assertString(contract.moonPackage, `${label}.moonPackage`);
  assertString(contract.generatedC, `${label}.generatedC`);
  assertString(contract.nativeLibrary, `${label}.nativeLibrary`);
  assertString(contract.appArg, `${label}.appArg`);
  assertString(contract.moonbitMainAlias, `${label}.moonbitMainAlias`);
  const exports = assertObject(contract.exports, `${label}.exports`);
  for (const field of ["attachSurface", "resize", "dispatchPointer", "renderFrame", "detachSurface"]) {
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
  for (const field of ["attachView", "resize", "dispatchPointer", "renderFrame", "detachView"]) {
    assertString(exports[field], `${label}.exports.${field}`);
  }
  if (supportsScroll) assertString(exports.dispatchScroll, `${label}.exports.dispatchScroll`);
};

const platformContract = ({ appId, platform, metadataPlatform, builtInContracts }) => {
  const fromBuiltIn = builtInContracts?.[appId]?.[platform] || {};
  const fromNative = metadataPlatform.native || {};
  const fromBuild = metadataPlatform.build || {};
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
  const androidContract = platformContract({
    appId,
    platform: "android",
    metadataPlatform: metadata.android,
    builtInContracts,
  });
  const iosContract = platformContract({
    appId,
    platform: "ios",
    metadataPlatform: metadata.ios,
    builtInContracts,
  });
  validateAndroidContract(`${metadataPath}: android.native or ${contractsFile}: apps.${appId}.android`, androidContract, mobile.supportsScroll);
  validateIosContract(`${metadataPath}: ios.native or ${contractsFile}: apps.${appId}.ios`, iosContract, mobile.supportsScroll);
  return {
    id: appId,
    displayName: metadata.displayName,
    artifactName: metadata.artifactName,
    appPackage: metadata.appPackage,
    mobile: { ...mobile },
    paths: {
      workspaceRoot,
      mouiRoot,
      skiaRoot,
      metadata: metadataPath,
      contracts: contractsFile,
    },
    android: {
      ...androidContract,
      applicationId: metadata.android.applicationId,
      fullscreen: mobile.fullscreen,
      supportsScroll: mobile.supportsScroll,
    },
    ios: {
      ...iosContract,
      bundleId: metadata.ios.bundleId,
      productName: metadata.ios.productName,
      infoPlist: metadata.ios.infoPlist,
      fullscreen: mobile.fullscreen,
      supportsScroll: mobile.supportsScroll,
    },
  };
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
  });
  return mergeApp({
    appId,
    metadata,
    metadataPath,
    contractsFile,
    builtInContracts,
    workspaceRoot,
    mouiRoot,
    skiaRoot,
  });
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
