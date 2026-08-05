#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const rootArg = process.argv.indexOf("--repo-root");
const root = rootArg >= 0 ? process.argv[rootArg + 1] : process.cwd();
const rootPackage = join(root, "moui", "moon.pkg");
const importPattern = /"(wzzc-dev\/moui(?:\/[^"\s]+)?)"/g;
const visited = new Set();
const violations = [];

function packagePath(importPath) {
  if (importPath === "wzzc-dev/moui") return join(root, "moui", "moon.pkg");
  if (!importPath.startsWith("wzzc-dev/moui/")) return undefined;
  return join(root, ...importPath.split("/").slice(1), "moon.pkg");
}

function isForbiddenBackend(importPath) {
  return importPath.startsWith("wzzc-dev/moui/backend/") &&
    importPath !== "wzzc-dev/moui/backend";
}

function walk(pkgPath) {
  if (visited.has(pkgPath) || !existsSync(pkgPath)) return;
  visited.add(pkgPath);
  const content = readFileSync(pkgPath, "utf8");
  for (const match of content.matchAll(importPattern)) {
    const importPath = match[1];
    if (isForbiddenBackend(importPath)) {
      violations.push(`${pkgPath}: imports forbidden backend package ${importPath}`);
      continue;
    }
    const child = packagePath(importPath);
    if (child) walk(child);
  }
}

walk(rootPackage);
if (violations.length) {
  console.error("root facade dependency violations:");
  for (const violation of violations) console.error(`- ${violation}`);
  process.exit(1);
}

console.log(`root facade dependency guard: ok (${visited.size} moui packages)`);
