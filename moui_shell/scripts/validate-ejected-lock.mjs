#!/usr/bin/env node

import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { basename, dirname, resolve } from "node:path";

const usage = () => {
  console.error(
    "Usage: validate-ejected-lock.mjs --lock <path> --platform <android|ios|harmonyos> --moui-root <path> --shell-root <path> [--project-root <path>] [--app-config <path>]",
  );
};

const required = new Map();
for (let index = 2; index < process.argv.length; index += 2) {
  const flag = process.argv[index];
  const value = process.argv[index + 1];
  if (!flag?.startsWith("--") || value === undefined) {
    usage();
    process.exit(2);
  }
  required.set(flag.slice(2), value);
}

for (const name of ["lock", "platform", "moui-root", "shell-root"]) {
  if (!required.get(name)) {
    usage();
    process.exit(2);
  }
}

const lockPath = resolve(required.get("lock"));
const platform = required.get("platform");
const mouiRoot = resolve(required.get("moui-root"));
const shellRoot = resolve(required.get("shell-root"));
const projectRoot = required.get("project-root")
  ? resolve(required.get("project-root"))
  : "";
const appConfig = required.get("app-config") ? resolve(required.get("app-config")) : "";

if (!new Set(["android", "ios", "harmonyos"]).has(platform)) {
  throw new Error(`unsupported shell platform: ${platform}`);
}

const readJson = path => {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    throw new Error(`${path}: invalid JSON (${error.message})`);
  }
};

const packageVersion = (root, expectedName) => {
  const path = resolve(root, "moon.mod");
  const source = readFileSync(path, "utf8");
  const name = source.match(/^name\s*=\s*"([^"]+)"\s*$/m)?.[1];
  const version = source.match(/^version\s*=\s*"([^"]+)"\s*$/m)?.[1];
  if (name !== expectedName || !version) {
    throw new Error(`${path}: expected ${expectedName} with a version`);
  }
  return version;
};

const sha256 = value => `sha256:${createHash("sha256").update(value).digest("hex")}`;
const expectedCapabilitySnapshot = currentPlatform => sha256(
  `shellApi=1\nembeddingApi=1\nplatform=${currentPlatform}\n` +
    "capabilities=surface,pointer,scroll,frame-scheduling,text-input,clipboard,accessibility,platform-views,host-channel\n",
);
const digest = (value, path) => {
  if (typeof value !== "string" || !/^sha256:[0-9a-f]{64}$/.test(value)) {
    throw new Error(`${path} must be a sha256 digest`);
  }
};

const lock = readJson(lockPath);
for (const [field, value] of Object.entries({
  schemaVersion: 1,
  mode: "ejected",
  platform,
  shellApiVersion: 1,
  embeddingApiVersion: 1,
  sourceTemplate: `${platform}/runner/template`,
})) {
  if (lock[field] !== value) {
    throw new Error(`${lockPath}: ${field} must be ${JSON.stringify(value)}`);
  }
}
for (const field of ["mouiVersion", "mouiShellVersion"]) {
  if (typeof lock[field] !== "string" || lock[field].length === 0) {
    throw new Error(`${lockPath}: ${field} must be a non-empty string`);
  }
}
for (const field of [
  "capabilitySnapshotDigest",
  "sourceTemplateDigest",
  "configDigest",
  "pluginDigest",
  "contentDigest",
]) {
  digest(lock[field], `${lockPath}.${field}`);
}
if (!Array.isArray(lock.pluginManifests) || !lock.pluginManifests.every(value => typeof value === "string")) {
  throw new Error(`${lockPath}.pluginManifests must be a string array`);
}
if (!Array.isArray(lock.files) || !lock.files.every(file =>
  file && typeof file.path === "string" && typeof file.sha256 === "string" && /^sha256:[0-9a-f]{64}$/.test(file.sha256),
)) {
  throw new Error(`${lockPath}.files must contain path and sha256 entries`);
}
if (lock.capabilitySnapshotDigest !== expectedCapabilitySnapshot(platform)) {
  throw new Error(`${lockPath}: capabilitySnapshotDigest does not match embedding API v1 for ${platform}`);
}

const installedMouiVersion = packageVersion(mouiRoot, "wzzc-dev/moui");
const installedShellVersion = packageVersion(shellRoot, "wzzc-dev/moui_shell");
if (lock.mouiVersion !== installedMouiVersion || lock.mouiShellVersion !== installedShellVersion) {
  throw new Error(
    `${lockPath}: package versions do not match resolved packages ` +
      `(lock moui=${lock.mouiVersion} shell=${lock.mouiShellVersion}; ` +
      `resolved moui=${installedMouiVersion} shell=${installedShellVersion})`,
  );
}

if (projectRoot) {
  const manifestPath = resolve(projectRoot, "moui.project.json");
  if (!existsSync(manifestPath)) {
    throw new Error(`${manifestPath}: required for an ejected shell build`);
  }
  const manifest = readJson(manifestPath);
  if (manifest.schemaVersion !== 1 || typeof manifest.mouiVersion !== "string") {
    throw new Error(`${manifestPath}: schemaVersion=1 and mouiVersion are required`);
  }
  if (manifest.mouiVersion !== lock.mouiVersion) {
    throw new Error(`${manifestPath}: mouiVersion must match ${basename(lockPath)}.mouiVersion`);
  }
  if (!Array.isArray(manifest.platforms) || !manifest.platforms.includes(platform)) {
    throw new Error(`${manifestPath}: platforms must include ${platform}`);
  }
}

if (appConfig) {
  const config = readJson(appConfig);
  if (config.schemaVersion !== 1 || config.shellApiVersion !== 1 || config.embeddingApiVersion !== 1) {
    throw new Error(`${appConfig}: schemaVersion, shellApiVersion, and embeddingApiVersion must all be 1`);
  }
  if (config.shell?.profile !== "handheld") {
    throw new Error(`${appConfig}: shell.profile must be handheld`);
  }
  if (config[platform]?.runnerMode !== "ejected") {
    throw new Error(`${appConfig}: ${platform}.runnerMode must be ejected`);
  }
}

console.log(`[moui-shell] validated ejected ${platform} lock: ${lockPath}`);
