#!/usr/bin/env node

import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { runCommand } from "./lib/moonbit-tool-runner.mjs";

const marker = "MOUI_PERFORMANCE_RESULT=";
let output = "";
let frames = "60";
let warmup = "12";
let provider = process.env.MOUI_PERFORMANCE_PROVIDER || "skia";
let surfaceRoute = process.env.MOUI_PERFORMANCE_SURFACE_ROUTE || "raster";
const routes = ["raster", "metal-gpu", "metal-gpu-host", "metal-gpu-host-rotating"];
const providers = ["skia", "skia-neutral", "sun"];
const args = process.argv.slice(2);
for (let index = 0; index < args.length; index += 1) {
  const arg = args[index];
  if (
    arg === "--output" || arg === "--frames" || arg === "--warmup" ||
    arg === "--surface-route" || arg === "--provider"
  ) {
    const value = args[index + 1];
    if (!value) {
      console.error("missing value for " + arg);
      process.exit(2);
    }
    if (arg === "--output") output = value;
    if (arg === "--frames") frames = value;
    if (arg === "--warmup") warmup = value;
    if (arg === "--surface-route") surfaceRoute = value;
    if (arg === "--provider") provider = value;
    index += 1;
  } else if (arg === "-h" || arg === "--help") {
    console.log(
      "Usage: node scripts/run-performance-budgets.mjs [--provider " +
        providers.join("|") +
        "] [--surface-route " +
        routes.join("|") +
        "] [--output PATH] [--frames N] [--warmup N]",
    );
    console.log(
      "  skia + raster is the gated runner (native-skia-raster); every other",
    );
    console.log(
      "  combination emits its own runner identity and is a control run, not",
    );
    console.log("  validated against budgets.");
    console.log(
      "  the metal-gpu routes exist only for provider skia: they are arguments to",
    );
    console.log(
      "  Skia's own constructor, and no RendererProvider expression reaches them.",
    );
    process.exit(0);
  } else {
    console.error("unknown argument: " + arg);
    process.exit(2);
  }
}
if (!providers.includes(provider)) {
  console.error("unknown provider: " + provider);
  process.exit(2);
}
if (!routes.includes(surfaceRoute)) {
  console.error("unknown surface route: " + surfaceRoute);
  process.exit(2);
}
const gated = provider === "skia" && surfaceRoute === "raster";
if (!output) {
  if (gated) {
    output = "artifacts/performance/result.json";
  } else {
    output =
      "artifacts/performance/result-" + provider + "-" + surfaceRoute + ".json";
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
      MOUI_PERFORMANCE_PROVIDER: provider,
      MOUI_PERFORMANCE_FRAMES: frames,
      MOUI_PERFORMANCE_WARMUP: warmup,
      MOUI_PERFORMANCE_SURFACE_ROUTE: surfaceRoute,
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

if (gated) {
  runCommand(
    "node",
    [
      "scripts/validate-performance-budgets.mjs",
      "--results",
      outputPath,
    ],
  );
} else {
  console.log(
    "provider " + provider + " route " + surfaceRoute +
      " is a control run; budget validation is skipped (gated runner is native-skia-raster)",
  );
}
console.log("performance budget report: " + output);
