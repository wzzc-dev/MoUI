#!/usr/bin/env node
// Guard: Mo Workbench OpenSeek native transport requires ./openseek in moon.work
// when building macos_skia (local submodule workflow).

import { readFileSync, existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const moonWork = join(repoRoot, "moon.work");
const openseekMod = join(repoRoot, "openseek", "moon.mod");
const transportPkg = join(
  repoRoot,
  "examples/mo_workbench/openseek_native_transport/moon.pkg",
);

const errors = [];

if (!existsSync(transportPkg)) {
  errors.push("missing examples/mo_workbench/openseek_native_transport/moon.pkg");
}

if (!existsSync(openseekMod)) {
  errors.push(
    "openseek submodule not initialized (run: git submodule update --init openseek)",
  );
}

const work = readFileSync(moonWork, "utf8");
if (!/^\s*"\.\/openseek",\s*$/m.test(work)) {
  errors.push(
    'moon.work must list "./openseek" until bobzhang/openseek is published on mooncakes.io.\n' +
      "  Run: sh scripts/openseek-dev-mode.sh on",
  );
}

if (errors.length > 0) {
  console.error("validate-openseek-workbench failed:\n");
  for (const err of errors) {
    console.error(`  - ${err}`);
  }
  process.exit(1);
}

console.log("validate-openseek-workbench: ok");