#!/usr/bin/env node

/**
 * Thin shell: formal gate evaluation + claim assembly live in
 * tools/moui/claim_macos_gpu_promotion. Optional --require-passed still uses
 * the existing MoonBit GPU promotion manifest validator.
 */

import { spawnSync } from "node:child_process";
import { resolve, dirname, isAbsolute, join } from "node:path";
import { fileURLToPath } from "node:url";
import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";
import { validateGpuPromotionManifest } from "./lib/gpu-promotion-manifest.mjs";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const usage = `Usage: scripts/claim-macos-gpu-promotion.mjs --metrics <metrics.json> --out-dir <dir> [options]

Options:
  --runner TEXT     Provenance runner (default scripts/run-macos-gpu-performance-smoke.mjs)
  --artifact TEXT   Provenance artifact path (default out-dir relative to repo)
  --require-passed  Validate claim with --require-passed
  -h, --help
`;

const parseArgs = argv => {
  const options = {
    metrics: "",
    outDir: "",
    runner: "scripts/run-macos-gpu-performance-smoke.mjs --promotion-lifecycle",
    artifact: "",
    requirePassed: false,
    help: false,
  };
  for (let index = 0; index < argv.length; ) {
    const arg = argv[index];
    if (arg === "--metrics") {
      options.metrics = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--out-dir") {
      options.outDir = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--runner") {
      options.runner = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--artifact") {
      options.artifact = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--require-passed") {
      options.requirePassed = true;
      index += 1;
    } else if (arg === "-h" || arg === "--help") {
      options.help = true;
      index += 1;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  return options;
};

const normalize = path => (isAbsolute(path) ? path : resolve(repoRoot, path));

const main = () => {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    process.stdout.write(usage);
    process.exit(0);
  }
  if (!options.metrics || !options.outDir) {
    console.error(usage);
    process.exit(2);
  }
  const toolArgs = [
    "--repo-root",
    repoRoot,
    "--metrics",
    options.metrics,
    "--out-dir",
    options.outDir,
    "--runner",
    options.runner,
  ];
  if (options.artifact) {
    toolArgs.push("--artifact", options.artifact);
  }
  runMoonbitTool("tools/moui/claim_macos_gpu_promotion", toolArgs);

  if (options.requirePassed) {
    const outDir = normalize(options.outDir);
    const claimPath = join(outDir, "gpu-promotion-claim.json");
    const result = validateGpuPromotionManifest(claimPath, {
      requirePassed: true,
    });
    process.stdout.write(result.stdout || "");
    process.stderr.write(result.stderr || "");
    if (result.status !== 0) process.exit(result.status || 1);
    process.stdout.write("claim validated with --require-passed\n");
  }
};

try {
  main();
} catch (error) {
  console.error(String(error && error.stack ? error.stack : error));
  process.exit(1);
}
