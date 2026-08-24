#!/usr/bin/env node

import {
  existsSync,
  readFileSync,
  rmSync,
} from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const committedReport = join(repoRoot, "checks/api-surface-report.json");
const checkReport = join(repoRoot, "checks/api-surface-report.check.json");

const mode = process.argv.slice(2).find(arg => {
  return arg === "--write" || arg === "--check";
});
if (!mode || process.argv.slice(2).filter(arg => {
  return arg === "--write" || arg === "--check";
}).length !== 1) {
  console.error("Usage: node scripts/generate-repo-docs.mjs --write|--check");
  process.exit(2);
}

const run = (command, args) => {
  const result = spawnSync(command, args, {
    cwd: repoRoot,
    env: { ...process.env, MOUI_SKIA_DISABLE_PREBUILD_SKIA: "1" },
    stdio: "inherit",
  });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(
      command + " " + args.join(" ") + " failed with exit code " +
        result.status,
    );
  }
};

const reportsMatch = (leftPath, rightPath) => {
  try {
    return JSON.stringify(JSON.parse(readFileSync(leftPath, "utf8"))) ===
      JSON.stringify(JSON.parse(readFileSync(rightPath, "utf8")));
  } catch {
    return false;
  }
};

const report = mode === "--write" ? committedReport : checkReport;
try {
  run(process.execPath, [
    "scripts/validate-api-surface.mjs",
    "--report",
    report,
  ]);
  if (mode === "--check") {
    if (!existsSync(committedReport) ||
      !reportsMatch(committedReport, checkReport)) {
      throw new Error(
        "checks/api-surface-report.json is stale; run generate_repo_docs --write",
      );
    }
  }
  run("moon", [
    "run",
    "tools/moui/generate_repo_docs",
    "--target",
    "native",
    "--",
    mode,
    "--repo-root",
    repoRoot,
    "--api-report",
    report,
  ]);
  if (mode === "--write") {
    run(process.execPath, ["scripts/sync-website-docs.mjs"]);
  } else {
    run(process.execPath, ["scripts/check-website-docs.mjs"]);
  }
} finally {
  rmSync(checkReport, { force: true });
}
