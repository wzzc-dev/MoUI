#!/usr/bin/env node

import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { runCommand } from "./lib/moonbit-tool-runner.mjs";

const marker = "MOUI_PERFORMANCE_RESULT=";
let output = "artifacts/performance/result.json";
let frames = "60";
let warmup = "12";
const args = process.argv.slice(2);
for (let index = 0; index < args.length; index += 1) {
  const arg = args[index];
  if (arg === "--output" || arg === "--frames" || arg === "--warmup") {
    const value = args[index + 1];
    if (!value) {
      console.error("missing value for " + arg);
      process.exit(2);
    }
    if (arg === "--output") output = value;
    if (arg === "--frames") frames = value;
    if (arg === "--warmup") warmup = value;
    index += 1;
  } else if (arg === "--help" || arg === "-h") {
    console.log(
      "Usage: node scripts/run-performance-budgets.mjs [--output PATH] [--frames N] [--warmup N]",
    );
    process.exit(0);
  } else {
    console.error("unknown argument: " + arg);
    process.exit(2);
  }
}

const result = runCommand(
  "moon",
  [
    "run",
    "benchmarks/performance_budget/native",
    "--target",
    "native",
    "--release",
  ],
  {
    encoding: "utf8",
    exitOnFailure: false,
    env: {
      ...process.env,
      MOUI_PERFORMANCE_FRAMES: frames,
      MOUI_PERFORMANCE_WARMUP: warmup,
    },
  },
);
if (result.status !== 0) {
  process.exit(result.status ?? 1);
}

const line = result.stdout
  .split(/\r?\n/)
  .find(candidate => candidate.startsWith(marker));
if (!line) {
  console.error("performance benchmark did not emit a result marker");
  process.exit(1);
}
const report = JSON.parse(line.slice(marker.length));
const outputPath = resolve(output);
mkdirSync(dirname(outputPath), { recursive: true });
writeFileSync(outputPath, JSON.stringify(report, null, 2) + "\n");

runCommand(
  "node",
  [
    "scripts/validate-performance-budgets.mjs",
    "--results",
    outputPath,
  ],
);
console.log("performance budget report: " + output);
