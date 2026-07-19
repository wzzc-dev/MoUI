import {
  accessSync,
  constants,
  readFileSync,
  readdirSync,
  statSync,
} from "node:fs";
import { join } from "node:path";

export const defaultAndroidNdkVersion = "28.2.13676358";

const firstNumericVersion = value => {
  const match = String(value).match(/(?:^|[^0-9])([0-9]+(?:\.[0-9]+)*)/);
  return match ? match[1].split(".").map(part => Number.parseInt(part, 10)) : null;
};

const versionAtLeast = (actual, required) => {
  const length = Math.max(actual.length, required.length);
  for (let index = 0; index < length; index += 1) {
    const left = actual[index] || 0;
    const right = required[index] || 0;
    if (left > right) return true;
    if (left < right) return false;
  }
  return true;
};

const versionHasPrefix = (actual, expected) =>
  actual.length >= expected.length && expected.every((part, index) => actual[index] === part);

const isNonemptyFile = path => {
  try {
    const stat = statSync(path);
    return stat.isFile() && stat.size > 0;
  } catch {
    return false;
  }
};

const isExecutableFile = path => {
  if (!isNonemptyFile(path)) return false;
  if (process.platform === "win32") return true;
  try {
    accessSync(path, constants.X_OK);
    return true;
  } catch {
    return false;
  }
};

const androidNdkRevision = root => {
  const propertiesPath = join(root, "source.properties");
  if (!isNonemptyFile(propertiesPath)) return null;
  let properties;
  try {
    properties = readFileSync(propertiesPath, "utf8");
  } catch {
    return null;
  }
  for (const line of properties.split("\n")) {
    if (!line.trim().startsWith("Pkg.Revision")) continue;
    const separator = line.indexOf("=");
    if (separator >= 0) return firstNumericVersion(line.slice(separator + 1));
  }
  return null;
};

const isCompleteAndroidNdk = root => {
  const prebuiltRoot = join(root, "toolchains/llvm/prebuilt");
  let hosts;
  try {
    hosts = readdirSync(prebuiltRoot);
  } catch {
    return false;
  }
  return hosts.some(host => ["clang", "clang.exe"].some(name =>
    isExecutableFile(join(prebuiltRoot, host, "bin", name))
  ));
};

export const resolveAndroidNdkHome = (sdkRoot, env = process.env) => {
  const requested = env.MOUI_ANDROID_NDK_VERSION === undefined
    ? defaultAndroidNdkVersion
    : env.MOUI_ANDROID_NDK_VERSION;
  const requestedVersion = firstNumericVersion(requested);
  if (!requestedVersion) {
    throw new Error(`MOUI_ANDROID_NDK_VERSION is invalid: ${requested}`);
  }
  if (!versionAtLeast(requestedVersion, [28, 2])) {
    throw new Error(`configured Android NDK is below the 28.2 floor: ${requested}`);
  }

  const candidates = [
    env.ANDROID_NDK_HOME || "",
    env.ANDROID_NDK_ROOT || "",
    join(sdkRoot, "ndk", requested),
  ];
  for (const candidate of candidates) {
    if (!candidate || !isCompleteAndroidNdk(candidate)) continue;
    const revision = androidNdkRevision(candidate);
    if (revision && versionAtLeast(revision, [28, 2]) && versionHasPrefix(revision, requestedVersion)) {
      return candidate;
    }
  }
  return "";
};
