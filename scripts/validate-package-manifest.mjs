#!/usr/bin/env node

import { readFileSync } from "node:fs";

const usage = () => {
  console.error(
    "Usage: node scripts/validate-package-manifest.mjs <moui-package.json> [--platform macos|windows]",
  );
};

const args = process.argv.slice(2);
if (args.length < 1 || args.includes("--help") || args.includes("-h")) {
  usage();
  process.exit(args.length < 1 ? 2 : 0);
}

const manifestPath = args[0];
let expectedPlatform = "";
for (let i = 1; i < args.length; i += 1) {
  if (args[i] === "--platform") {
    expectedPlatform = args[i + 1] ?? "";
    i += 1;
  } else {
    console.error(`Unknown argument: ${args[i]}`);
    usage();
    process.exit(2);
  }
}

const fail = message => {
  console.error(`${manifestPath}: ${message}`);
  process.exitCode = 1;
};

let manifest;
try {
  manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
} catch (error) {
  console.error(`${manifestPath}: failed to read JSON: ${error.message}`);
  process.exit(1);
}

const requireString = field => {
  if (typeof manifest[field] !== "string" || manifest[field].trim() === "") {
    fail(`missing non-empty string field '${field}'`);
    return "";
  }
  return manifest[field];
};

if (manifest.schemaVersion !== 1) {
  fail("schemaVersion must be 1");
}

const platform = requireString("platform");
if (expectedPlatform && platform !== expectedPlatform) {
  fail(`platform must be '${expectedPlatform}'`);
}

const outputKind = requireString("outputKind");
requireString("appName");
requireString("moonPackage");
requireString("version");
requireString("buildNumber");
const executable = requireString("executable");
requireString("bundleName");

if (!Array.isArray(manifest.runtimeFiles)) {
  fail("runtimeFiles must be an array");
}

if (platform === "macos") {
  if (outputKind !== "app-bundle") {
    fail("macOS outputKind must be 'app-bundle'");
  }
  requireString("bundleIdentifier");
  if (!manifest.bundleName.endsWith(".app")) {
    fail("macOS bundleName must end with .app");
  }
} else if (platform === "windows") {
  if (outputKind !== "portable-folder") {
    fail("Windows outputKind must be 'portable-folder'");
  }
  if (!executable.toLowerCase().endsWith(".exe")) {
    fail("Windows executable must end with .exe");
  }
} else {
  fail("platform must be 'macos' or 'windows'");
}

if (process.exitCode) {
  process.exit(process.exitCode);
}

console.log(`${manifestPath}: ok (${platform} ${outputKind})`);
