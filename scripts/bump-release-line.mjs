#!/usr/bin/env node

import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const version = process.argv[2];
if (!version || !/^\d+\.\d+\.\d+$/.test(version)) {
  console.error("usage: node scripts/bump-release-line.mjs <major.minor.patch>");
  process.exit(2);
}

const root = process.cwd();
const release = JSON.parse(
  readFileSync(join(root, "checks", "release-modules.json"), "utf8"),
);
const publicModules = release.modules.filter(
  (entry) => entry.publication === "public",
);
const names = publicModules.map((entry) => entry.name);

const updateManifestVersion = (path) => {
  const source = readFileSync(path, "utf8");
  const next = source.replace(
    /^version\s*=\s*"[^"]+"/m,
    `version = "${version}"`,
  );
  if (next === source) {
    throw new Error(`missing version declaration: ${path}`);
  }
  writeFileSync(path, next);
};

for (const entry of publicModules) {
  updateManifestVersion(join(root, entry.directory, "moon.mod"));
}

const workspaceText = readFileSync(join(root, "moon.work"), "utf8");
const members = [...workspaceText.matchAll(/^\s*"\.\/(.+?)",?$/gm)].map(
  (match) => match[1],
);
const dependencyPattern = (name) =>
  new RegExp(`("${name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")})@[^"]+"`, "g");

for (const member of members) {
  const path = join(root, member, "moon.mod");
  let source;
  try {
    source = readFileSync(path, "utf8");
  } catch {
    continue;
  }
  let next = source;
  for (const name of names) {
    next = next.replace(
      dependencyPattern(name),
      (_, prefix) => `${prefix}@${version}"`,
    );
  }
  if (next !== source) {
    writeFileSync(path, next);
  }
}

console.log(`release line ${version}: updated ${publicModules.length} modules and workspace pins`);
