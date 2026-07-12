#!/usr/bin/env node

import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const defaultRepoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const usage = () => {
  console.error("Usage: node scripts/check-website-docs.mjs [--root <dir>]");
};

let repoRoot = defaultRepoRoot;
const args = process.argv.slice(2);
for (let index = 0; index < args.length; index += 1) {
  const arg = args[index];
  if (arg === "--root") {
    const value = args[index + 1];
    if (!value) {
      usage();
      process.exit(2);
    }
    repoRoot = resolve(value);
    index += 1;
  } else if (arg === "--help" || arg === "-h") {
    usage();
    process.exit(0);
  } else {
    console.error(`Unknown argument: ${arg}`);
    usage();
    process.exit(2);
  }
}

const tempRoot = mkdtempSync(join(tmpdir(), "moui-website-docs-check-"));
const outDir = join(tempRoot, "docs");
const syncScript = join(repoRoot, "scripts", "sync-website-docs.mjs");

const run = extraArgs => {
  const result = spawnSync(
    process.execPath,
    [syncScript, "--root", repoRoot, "--out", outDir, ...extraArgs],
    { cwd: repoRoot, encoding: "utf8" },
  );
  if (result.status !== 0 || result.error) {
    if (result.stdout) process.stdout.write(result.stdout);
    if (result.stderr) process.stderr.write(result.stderr);
    if (result.error) console.error(result.error.message);
    process.exitCode = result.status ?? 1;
    return false;
  }
  return true;
};

try {
  if (run([]) && run(["--check"])) {
    console.log("website docs temporary generation check: ok");
  }
} finally {
  rmSync(tempRoot, { recursive: true, force: true });
}
