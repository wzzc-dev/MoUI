#!/usr/bin/env node

// Workspace test sweep for the main repo. `moui_studio` is a subrepo whose
// tests (and the Rust-built plugin fixtures they take) are owned by its own CI
// (wzzc-dev/moui_studio), so it stays out of this sweep. Members come from
// moon.work, and packages are enumerated explicitly: `moon test` with no paths
// would also run the subrepo, while module paths alone only test the module
// root package and silently drop the rest of the tree.
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join, resolve } from "node:path";
import { repoRoot } from "./lib/moonbit-tool-runner.mjs";

const EXCLUDED_MEMBERS = new Set(["moui_studio"]);
const SKIP_DIRS = new Set(["_build", ".git", ".repos", "node_modules", "dist", "target", "artifacts"]);
const MANIFESTS = ["moon.pkg", "moon.pkg.json"];
const MODULE_MANIFESTS = ["moon.mod", "moon.mod.json"];

const workText = readFileSync(resolve(repoRoot, "moon.work"), "utf8");
const membersBlock = workText.match(/members\s*=\s*\[([\s\S]*?)\]/);
if (!membersBlock) {
  console.error("moon.work does not define a members array");
  process.exit(1);
}
const members = [...membersBlock[1].matchAll(/"([^"]+)"/g)].map(match =>
  match[1].replace(/^\.\//, ""),
);
const skipped = members.filter(member => EXCLUDED_MEMBERS.has(member));
const targets = members.filter(member => !EXCLUDED_MEMBERS.has(member));
if (targets.length === 0) {
  console.error("moon.work members array is empty");
  process.exit(1);
}

const isPackageDir = dir => MANIFESTS.some(name => existsSync(join(dir, name)));
const isModuleRoot = dir => MODULE_MANIFESTS.some(name => existsSync(join(dir, name)));
const packages = [];
const walk = dir => {
  if (!existsSync(dir)) return;
  if (isPackageDir(dir)) packages.push(dir);
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (!entry.isDirectory() || SKIP_DIRS.has(entry.name)) continue;
    const child = join(dir, entry.name);
    // Nested module roots are their own member (or the excluded subrepo), so the
    // outer walk stops here instead of re-testing them under this member.
    if (isModuleRoot(child)) continue;
    walk(child);
  }
};
for (const member of targets) walk(member);
if (packages.length === 0) {
  console.error("no package directories found under the workspace members");
  process.exit(1);
}
console.log(
  `workspace tests: ${packages.length} packages in ${targets.length} members` +
    (skipped.length > 0 ? ` (subrepo-owned, skipped: ${skipped.join(", ")})` : ""),
);

const result = spawnSync("moon", ["test", ...packages, ...process.argv.slice(2)], {
  cwd: repoRoot,
  stdio: "inherit",
});
if (result.error) {
  console.error(result.error.message);
  process.exit(1);
}
process.exit(result.status ?? 0);
