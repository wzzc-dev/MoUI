#!/usr/bin/env node

// Generated-interface drift check.
//
// `moon info` writes one `pkg.generated.mbti` per package, and the repository
// tracks those files (240 of them) so the public surface of every published
// module is reviewable in a diff. This check regenerates them and fails when a
// tracked file would change, but it also covers the two blind spots that the
// previous `git diff --exit-code` approach missed:
//
//   1. A package that never had its interface committed. `git diff` cannot see
//      an untracked file, so a new package silently shipped without one.
//   2. Module roots that are not `moon.work` members (their packages are
//      outside workspace-wide `moon info`), such as the native smoke modules.
import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const run = (command, args, options = {}) => {
  const capture = options.capture === true;
  const result = spawnSync(command, args, {
    cwd: options.cwd ?? repoRoot,
    env: {
      ...process.env,
      MOUI_SKIA_DISABLE_PREBUILD_SKIA:
        process.env.MOUI_SKIA_DISABLE_PREBUILD_SKIA ?? "1",
    },
    stdio: capture ? undefined : "inherit",
    encoding: capture ? "utf8" : undefined,
  });
  if (result.error) {
    console.error(result.error.message);
    process.exit(1);
  }
  if (result.status !== 0) {
    if (capture) {
      if (result.stdout) process.stdout.write(result.stdout);
      if (result.stderr) process.stderr.write(result.stderr);
    }
    process.exit(result.status ?? 1);
  }
  return result.stdout ?? "";
};

const workspaceMembers = (() => {
  const workText = readFileSync(resolve(repoRoot, "moon.work"), "utf8");
  const block = workText.match(/members\s*=\s*\[([\s\S]*?)\]/);
  if (!block) {
    console.error("moon.work does not define a members array");
    process.exit(1);
  }
  return new Set(
    [...block[1].matchAll(/"([^"]+)"/g)].map(match =>
      match[1].replace(/^\.\//, ""),
    ),
  );
})();

const trackedInterfaces = run(
  "git",
  ["ls-files", "-z", "--", ":(glob)**/pkg.generated.mbti"],
  { capture: true },
)
  .split("\0")
  .filter(Boolean)
  .sort();

if (trackedInterfaces.length === 0) {
  console.error("generated interface drift check found no tracked pkg.generated.mbti files");
  process.exit(1);
}

const moduleRootOf = path => {
  let dir = dirname(path);
  while (dir !== "." && dir !== "") {
    const absolute = resolve(repoRoot, dir);
    if (
      existsSync(resolve(absolute, "moon.mod")) ||
      existsSync(resolve(absolute, "moon.mod.json"))
    ) {
      return dir;
    }
    dir = dirname(dir);
  }
  return "";
};

const before = new Map(
  trackedInterfaces.map(path => {
    const absolutePath = resolve(repoRoot, path);
    return [path, existsSync(absolutePath) ? readFileSync(absolutePath) : null];
  }),
);

run("moon", ["info"]);

// Module roots outside the workspace are not covered by workspace-wide
// `moon info`; regenerate them from their own module root and remember their
// package-relative directories so the comparison below still finds them.
const externalModuleRoots = [
  ...new Set(trackedInterfaces.map(moduleRootOf)),
].filter(root => root !== "" && !workspaceMembers.has(root));

for (const root of externalModuleRoots) {
  run("moon", ["info"], { cwd: resolve(repoRoot, root) });
}

const changed = trackedInterfaces.filter(path => {
  const absolutePath = resolve(repoRoot, path);
  const previous = before.get(path);
  const current = existsSync(absolutePath) ? readFileSync(absolutePath) : null;
  if (previous === null || current === null) return previous !== current;
  return !previous.equals(current);
});

// `moon info` also generates interfaces for packages that never committed one.
// Those are invisible to `git diff`, so surface them explicitly instead of
// letting a new package ship without a reviewable public surface.
const statusEntries = run(
  "git",
  [
    "status",
    "--porcelain",
    "-z",
    "--untracked-files=all",
    "--",
    ":(glob)**/pkg.generated.mbti",
  ],
  { capture: true },
)
  .split("\0")
  .filter(Boolean);

// `-z` emits rename/copy entries as "XY newpath\0oldpath", so the old path
// arrives as a bare token that looks like a path with no status prefix. Walk the
// entries by status instead of mapping every token.
const untracked = [];
for (let index = 0; index < statusEntries.length; index += 1) {
  const entry = statusEntries[index];
  const status = entry.slice(0, 2);
  if (status[0] === "R" || status[0] === "C") {
    index += 1;
    continue;
  }
  if (status === "??" && !trackedInterfaces.includes(entry.slice(3))) {
    untracked.push(entry.slice(3));
  }
}

if (changed.length > 0 || untracked.length > 0) {
  if (changed.length > 0) {
    console.error("\nGenerated MoonBit interfaces were stale and have been refreshed:");
    for (const path of changed) {
      console.error(`  ${path}`);
    }
  }
  if (untracked.length > 0) {
    console.error("\nGenerated MoonBit interfaces exist but are not committed:");
    for (const path of untracked) {
      console.error(`  ${path}`);
    }
  }
  console.error(
    "Review and commit the generated interface changes, then rerun the check.",
  );
  process.exit(1);
}

console.log(
  `generated interface drift: ok (${trackedInterfaces.length} tracked packages, ` +
    `${externalModuleRoots.length} external module roots)`,
);
