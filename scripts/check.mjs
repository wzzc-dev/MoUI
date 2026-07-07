#!/usr/bin/env node

import { dirname, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import {
  defaultCheckEnv,
  ensureWindowSubmodule,
  formatPlanList,
  hostMatches,
  planProfile,
  readCheckCatalog,
} from "./lib/check-runner.mjs";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const catalogPath = resolve(repoRoot, "checks/profiles.json");

const usage = () => {
  console.error(
    "Usage: node scripts/check.mjs --profile <pr|daily|platform|theme|full> [--dry-run] [--json] [--list] [--skip-submodule-init]",
  );
};

let profile = "pr";
let dryRun = false;
let json = false;
let list = false;
let skipSubmoduleInit = false;

const args = process.argv.slice(2);
for (let index = 0; index < args.length; index += 1) {
  const arg = args[index];
  if (arg === "--profile") {
    profile = args[index + 1] ?? "";
    index += 1;
  } else if (arg === "--dry-run") {
    dryRun = true;
  } else if (arg === "--json") {
    json = true;
    dryRun = true;
  } else if (arg === "--list") {
    list = true;
    dryRun = true;
  } else if (arg === "--skip-submodule-init") {
    skipSubmoduleInit = true;
  } else if (arg === "--help" || arg === "-h") {
    usage();
    process.exit(0);
  } else {
    console.error(`Unknown argument: ${arg}`);
    usage();
    process.exit(2);
  }
}

const catalog = readCheckCatalog(catalogPath);
const plan = planProfile({ catalog, profile });

if (json) {
  console.log(JSON.stringify(plan, null, 2));
  process.exit(0);
}

if (list) {
  console.log(formatPlanList(plan).join("\n"));
  process.exit(0);
}

if (!dryRun && !skipSubmoduleInit) {
  ensureWindowSubmodule(repoRoot);
}

const env = defaultCheckEnv();

for (const step of plan.steps) {
  if (!hostMatches(step.host)) {
    console.log(`\n==> Skipping ${step.name} on ${plan.host}`);
    continue;
  }
  console.log(`\n==> ${step.argv.join(" ")}`);
  if (dryRun) continue;
  const result = spawnSync(step.argv[0], step.argv.slice(1), {
    cwd: repoRoot,
    env,
    stdio: "inherit",
    shell: false,
  });
  if (result.status !== 0 || result.error) {
    if (result.error) console.error(result.error.message);
    process.exit(result.status ?? 1);
  }
}

console.log(`\nMoUI ${profile} checks passed.`);
