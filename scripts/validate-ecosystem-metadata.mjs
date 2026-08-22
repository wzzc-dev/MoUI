#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(fileURLToPath(new URL("..", import.meta.url)));
const readJson = relativePath => {
  const path = join(repoRoot, relativePath);
  if (!existsSync(path)) throw new Error(`missing metadata file: ${relativePath}`);
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    throw new Error(`invalid JSON in ${relativePath}: ${error.message}`);
  }
};

const policy = readJson("checks/compatibility-policy.json");
const quality = readJson("checks/component-quality.json");
if (policy.schemaVersion !== 1 || quality.schemaVersion !== 1) {
  throw new Error("ecosystem metadata must use schemaVersion 1");
}
if (policy.versioning?.scheme !== "semver") {
  throw new Error("compatibility policy must declare semver versioning");
}
if (!Number.isInteger(policy.deprecation?.minimumNoticeReleases) || policy.deprecation.minimumNoticeReleases < 2) {
  throw new Error("deprecation policy must retain at least two release notices");
}
const allowedLevels = new Set(["stable", "preview", "experimental"]);
const allowedStatuses = new Set(["ready", "partial", "contract-only"]);
const ids = new Set();
for (const component of quality.components ?? []) {
  for (const field of ["id", "package", "level", "status", "evidence"]) {
    if (!(field in component)) throw new Error(`component ${component.id ?? "<unknown>"} is missing ${field}`);
  }
  if (ids.has(component.id)) throw new Error(`duplicate component id: ${component.id}`);
  ids.add(component.id);
  if (!allowedLevels.has(component.level) || !allowedStatuses.has(component.status)) {
    throw new Error(`invalid quality classification for ${component.id}`);
  }
  if (!Array.isArray(component.evidence) || component.evidence.length === 0) {
    throw new Error(`component ${component.id} needs evidence paths`);
  }
  for (const evidence of component.evidence) {
    if (!existsSync(join(repoRoot, evidence))) throw new Error(`missing evidence for ${component.id}: ${evidence}`);
  }
}
if (!policy.consumerGate?.command.includes("external-consumer-ci.mjs")) {
  throw new Error("compatibility policy must point at the external consumer gate");
}
console.log(`ecosystem metadata: ok (${quality.components.length} quality records)`);
