#!/usr/bin/env node

import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

export const validatePermissionUsageDescriptions = (value, label = "managed shell manifest") => {
  if (!Array.isArray(value)) {
    throw new Error(`${label}: permissionUsageDescriptions must be an array`);
  }
  const seen = new Set();
  return value.map(entry => {
    if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
      throw new Error(`${label}: invalid permission usage declaration`);
    }
    const { permission, plistKey, description } = entry;
    if (typeof permission !== "string" ||
        typeof plistKey !== "string" ||
        !/^NS[A-Za-z]+UsageDescription$/.test(plistKey) ||
        typeof description !== "string" ||
        description.length === 0 ||
        seen.has(plistKey)) {
      throw new Error(
        `${label}: invalid permission usage declaration for ${JSON.stringify(permission)}`,
      );
    }
    seen.add(plistKey);
    return { permission, plistKey, description };
  });
};

export const validateDeploymentTarget = (value, label = "managed shell manifest") => {
  if (typeof value !== "string" || !/^\d+(?:\.\d+){0,2}$/.test(value)) {
    throw new Error(`${label}: deploymentTarget must be a numeric dotted version`);
  }
  const [major] = value.split(".").map(Number);
  if (major < 15) throw new Error(`${label}: deploymentTarget must be at least 15.0`);
  return value;
};

const compareDottedVersions = (left, right) => {
  const leftParts = left.split(".").map(Number);
  const rightParts = right.split(".").map(Number);
  for (let index = 0; index < Math.max(leftParts.length, rightParts.length); index += 1) {
    const difference = (leftParts[index] || 0) - (rightParts[index] || 0);
    if (difference !== 0) return difference;
  }
  return 0;
};

const updatePlistString = (plistPath, key, value) => {
  let result = spawnSync("plutil", ["-replace", key, "-string", value, plistPath], {
    encoding: "utf8",
  });
  if (result.status !== 0) {
    result = spawnSync("plutil", ["-insert", key, "-string", value, plistPath], {
      encoding: "utf8",
    });
  }
  if (result.status !== 0) {
    throw new Error(`failed to write ${key}: ${result.stderr || result.error || "plutil failed"}`);
  }
};

export const applyManagedInfoPlist = ({ manifestPath, plistPath, deploymentTarget = "" }) => {
  const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
  const configuredTarget = validateDeploymentTarget(manifest.deploymentTarget, manifestPath);
  const effectiveTarget = validateDeploymentTarget(
    deploymentTarget || configuredTarget,
    "effective iOS deployment target",
  );
  if (compareDottedVersions(effectiveTarget, configuredTarget) < 0) {
    throw new Error(
      `effective iOS deployment target ${effectiveTarget} is below managed config floor ${configuredTarget}`,
    );
  }
  const entries = validatePermissionUsageDescriptions(
    manifest.permissionUsageDescriptions,
    manifestPath,
  );
  updatePlistString(plistPath, "MinimumOSVersion", effectiveTarget);
  for (const entry of entries) {
    updatePlistString(plistPath, entry.plistKey, entry.description);
  }
};

const isMain = process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  const options = { manifestPath: "", plistPath: "", deploymentTarget: "" };
  for (let index = 2; index < process.argv.length; index += 1) {
    const key = process.argv[index];
    const value = process.argv[index + 1];
    if (!value) throw new Error(`missing value after ${key}`);
    index += 1;
    if (key === "--manifest") options.manifestPath = resolve(value);
    else if (key === "--plist") options.plistPath = resolve(value);
    else if (key === "--deployment-target") options.deploymentTarget = value;
    else throw new Error(`unknown option: ${key}`);
  }
  if (!options.manifestPath || !options.plistPath) {
    throw new Error("--manifest and --plist are required");
  }
  applyManagedInfoPlist(options);
}
