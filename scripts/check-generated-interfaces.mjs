#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const run = (command, args, options = {}) => {
  const capture = options.capture === true;
  const result = spawnSync(command, args, {
    cwd: repoRoot,
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

const before = new Map(
  trackedInterfaces.map(path => {
    const absolutePath = resolve(repoRoot, path);
    return [path, existsSync(absolutePath) ? readFileSync(absolutePath) : null];
  }),
);

run("moon", ["info"]);

const changed = trackedInterfaces.filter(path => {
  const absolutePath = resolve(repoRoot, path);
  const previous = before.get(path);
  const current = existsSync(absolutePath) ? readFileSync(absolutePath) : null;
  if (previous === null || current === null) return previous !== current;
  return !previous.equals(current);
});

if (changed.length > 0) {
  console.error("\nGenerated MoonBit interfaces were stale and have been refreshed:");
  for (const path of changed) {
    console.error(`  ${path}`);
  }
  console.error("Review and commit the generated interface changes, then rerun the check.");
  process.exit(1);
}

console.log(`generated interface drift: ok (${trackedInterfaces.length} tracked packages)`);
