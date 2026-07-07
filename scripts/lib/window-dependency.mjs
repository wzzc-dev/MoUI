import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

export const windowDependencyVersions = (root = repoRoot) => {
  const modPath = resolve(root, "moui/moon.mod");
  const text = readFileSync(modPath, "utf8");
  const versions = [...text.matchAll(/"wzzc-dev\/window@([^"]+)"/g)].map(match => match[1]);
  return [...new Set(versions)];
};

export const windowDependencyVersion = (root = repoRoot) => {
  const versions = windowDependencyVersions(root);
  if (versions.length !== 1) {
    throw new Error(`Expected exactly one wzzc-dev/window version in moui/moon.mod, got ${versions.length}`);
  }
  return versions[0];
};

export const windowDependencyPackage = (root = repoRoot) =>
  `wzzc-dev/window@${windowDependencyVersion(root)}`;

export const windowDependencyCacheZip = (root = repoRoot) =>
  resolve(
    homedir(),
    ".moon/registry/cache/wzzc-dev/window",
    `${windowDependencyVersion(root)}.zip`,
  );
