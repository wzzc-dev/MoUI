// shell.json is intentionally a fresh, strict schema.  It does not accept the
// former mobile schema or per-app ABI symbol maps.
const SCHEMA_VERSION = 1;
const SHELL_API_VERSION = 1;
const RUNTIME_ABI_VERSION = 1;

const rendererModes = new Set(["auto", "skia-gpu", "skia-raster"]);
const orientations = new Set(["any", "portrait", "landscape"]);
const statusBarModes = new Set(["auto", "visible", "hidden"]);
const runnerModes = new Set(["managed", "ejected"]);

const fail = (path, message) => {
  throw new Error(`${path}: ${message}`);
};

const object = (value, path) => {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    fail(path, "must be an object");
  }
  return value;
};

const string = (value, path) => {
  if (typeof value !== "string" || value.trim() === "") {
    fail(path, "must be a non-empty string");
  }
  return value;
};

const boolean = (value, path) => {
  if (typeof value !== "boolean") fail(path, "must be a boolean");
  return value;
};

const integer = (value, path) => {
  if (!Number.isInteger(value)) fail(path, "must be an integer");
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

const uniqueStrings = (value, path, { relativePaths = false } = {}) => {
  if (!Array.isArray(value)) fail(path, "must be an array");
  const result = value.map((item, index) => string(item, `${path}[${index}]`));
  if (new Set(result).size !== result.length) fail(path, "must not contain duplicates");
  if (relativePaths) {
    for (const item of result) {
      if (item.startsWith("/") || item.startsWith("\\") || /^[A-Za-z]:[\\/]/.test(item)) {
        fail(path, `path must be workspace-relative: ${JSON.stringify(item)}`);
      }
      if (item.split(/[\\/]/).includes("..")) {
        fail(path, `path must not escape the workspace: ${JSON.stringify(item)}`);
      }
    }
  }
  return result;
};

const enumValue = (value, allowed, path) => {
  string(value, path);
  if (!allowed.has(value)) fail(path, `must be one of ${[...allowed].join(", ")}`);
  return value;
};

const dottedVersionAtLeast = (value, floor, path) => {
  string(value, path);
  if (!/^\d+(?:\.\d+){0,2}$/.test(value)) fail(path, "must be a numeric dotted version");
  const parts = value.split(".").map(Number);
  const floorParts = floor.split(".").map(Number);
  const width = Math.max(parts.length, floorParts.length);
  for (let index = 0; index < width; index += 1) {
    const part = parts[index] || 0;
    const floorPart = floorParts[index] || 0;
    if (part > floorPart) return value;
    if (part < floorPart) fail(path, `must be at least ${floor}`);
  }
  return value;
};

const validateShell = (value, path) => {
  const shell = exactKeys(
    value,
    ["profile", "renderer", "systemUi", "orientation", "resources", "permissions", "plugins"],
    ["profile", "renderer", "systemUi", "orientation", "resources", "permissions", "plugins"],
    path,
  );
  if (shell.profile !== "handheld") fail(`${path}.profile`, "must be handheld");
  enumValue(shell.renderer, rendererModes, `${path}.renderer`);
  enumValue(shell.orientation, orientations, `${path}.orientation`);
  uniqueStrings(shell.resources, `${path}.resources`, { relativePaths: true });
  uniqueStrings(shell.permissions, `${path}.permissions`);
  uniqueStrings(shell.plugins, `${path}.plugins`, { relativePaths: true });
  const systemUi = exactKeys(
    shell.systemUi,
    ["fullscreen", "statusBar"],
    ["fullscreen", "statusBar"],
    `${path}.systemUi`,
  );
  boolean(systemUi.fullscreen, `${path}.systemUi.fullscreen`);
  enumValue(systemUi.statusBar, statusBarModes, `${path}.systemUi.statusBar`);
};

const validateAndroid = (value, path) => {
  const platform = exactKeys(
    value,
    ["applicationId", "runnerMode", "minSdk"],
    ["applicationId", "runnerMode", "minSdk"],
    path,
  );
  string(platform.applicationId, `${path}.applicationId`);
  enumValue(platform.runnerMode, runnerModes, `${path}.runnerMode`);
  if (integer(platform.minSdk, `${path}.minSdk`) < 23) fail(`${path}.minSdk`, "must be at least 23");
};

const validateIos = (value, path) => {
  const platform = exactKeys(
    value,
    ["bundleId", "productName", "runnerMode", "deploymentTarget"],
    ["bundleId", "productName", "runnerMode", "deploymentTarget"],
    path,
  );
  string(platform.bundleId, `${path}.bundleId`);
  string(platform.productName, `${path}.productName`);
  enumValue(platform.runnerMode, runnerModes, `${path}.runnerMode`);
  dottedVersionAtLeast(platform.deploymentTarget, "15.0", `${path}.deploymentTarget`);
};

const validateHarmonyos = (value, path) => {
  const platform = exactKeys(
    value,
    [
      "bundleName",
      "productName",
      "appName",
      "moduleName",
      "moduleDescription",
      "entryDescription",
      "runnerMode",
      "compatibleSdkVersion",
    ],
    ["bundleName", "productName", "runnerMode", "compatibleSdkVersion"],
    path,
  );
  for (const key of ["bundleName", "productName"]) string(platform[key], `${path}.${key}`);
  for (const key of ["appName", "moduleName", "moduleDescription", "entryDescription"]) {
    if (platform[key] !== undefined) string(platform[key], `${path}.${key}`);
  }
  enumValue(platform.runnerMode, runnerModes, `${path}.runnerMode`);
  if (integer(platform.compatibleSdkVersion, `${path}.compatibleSdkVersion`) < 20) {
    fail(`${path}.compatibleSdkVersion`, "must be at least 20");
  }
};

export const validateShellMetadataV1 = (value, { path = "shell.json", appId = "" } = {}) => {
  const metadata = exactKeys(
    value,
    [
      "schemaVersion",
      "id",
      "displayName",
      "artifactName",
      "appPackage",
      "shellApiVersion",
      "embeddingApiVersion",
      "shell",
      "android",
      "ios",
      "harmonyos",
    ],
    [
      "schemaVersion",
      "id",
      "displayName",
      "artifactName",
      "appPackage",
      "shellApiVersion",
      "embeddingApiVersion",
      "shell",
    ],
    path,
  );
  if (metadata.schemaVersion !== SCHEMA_VERSION) fail(path, `schemaVersion must be ${SCHEMA_VERSION}`);
  if (metadata.shellApiVersion !== SHELL_API_VERSION) {
    fail(path, `shellApiVersion must be ${SHELL_API_VERSION}`);
  }
  if (metadata.embeddingApiVersion !== RUNTIME_ABI_VERSION) {
    fail(path, `embeddingApiVersion must be ${RUNTIME_ABI_VERSION}`);
  }
  string(metadata.id, `${path}.id`);
  if (appId && metadata.id !== appId) fail(path, `id must match requested app ${appId}`);
  for (const key of ["displayName", "artifactName", "appPackage"]) {
    string(metadata[key], `${path}.${key}`);
  }
  validateShell(metadata.shell, `${path}.shell`);
  if (metadata.android !== undefined) validateAndroid(metadata.android, `${path}.android`);
  if (metadata.ios !== undefined) validateIos(metadata.ios, `${path}.ios`);
  if (metadata.harmonyos !== undefined) validateHarmonyos(metadata.harmonyos, `${path}.harmonyos`);
  if (!metadata.android && !metadata.ios && !metadata.harmonyos) {
    fail(path, "at least one of android, ios, or harmonyos must be configured");
  }
  return metadata;
};

export const shellConfigProtocol = Object.freeze({
  schemaVersion: SCHEMA_VERSION,
  shellApiVersion: SHELL_API_VERSION,
  embeddingApiVersion: RUNTIME_ABI_VERSION,
});
