#!/usr/bin/env node

/**
 * Build a gpuPromoted=true claim manifest from a completed metrics overlay
 * only when ADR 0006 gates are numerically satisfied. Still does not edit
 * NativeGpuPlatform::gpu_promoted; that is a separate source change after
 * --require-passed succeeds and human review.
 */

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, isAbsolute, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
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
  const metricsPath = normalize(options.metrics);
  const outDir = normalize(options.outDir);
  mkdirSync(outDir, { recursive: true });
  const metrics = JSON.parse(readFileSync(metricsPath, "utf8"));
  const gates = metrics.promotionGates || {};
  const perf = gates.performance || {};
  const memory = gates.memory || {};
  const contextLoss = gates.contextLoss || {};
  const rasterFallback = gates.rasterFallback || {};
  const diagnostics = metrics.diagnostics || {};

  const failures = [];
  if (!gates.readbackEliminated) failures.push("readbackEliminated");
  if (!gates.rendererThread) failures.push("rendererThread");
  if (!gates.mailboxOk) failures.push("mailboxOk");
  if (!(perf.durationSeconds >= 600)) failures.push("performance.durationSeconds>=600");
  const p95Limit = (perf.refreshHz || 60) >= 120 ? 8.3 : 16.7;
  if (!(perf.p95FrameMs > 0 && perf.p95FrameMs <= p95Limit)) {
    failures.push(`performance.p95FrameMs<=${p95Limit}`);
  }
  if (!(perf.droppedFramePercent >= 0 && perf.droppedFramePercent < 1)) {
    failures.push("performance.droppedFramePercent<1");
  }
  if (
    !(
      perf.inputToPresentPVsyncIntervals > 0 &&
      perf.inputToPresentPVsyncIntervals <= 2
    )
  ) {
    failures.push("performance.inputToPresentPVsyncIntervals<=2");
  }
  if (!memory.bounded) failures.push("memory.bounded");
  if (!(memory.surfaceRecreationCycles >= 100)) {
    failures.push("memory.surfaceRecreationCycles>=100");
  }
  if (!(memory.foregroundBackgroundCycles >= 100)) {
    failures.push("memory.foregroundBackgroundCycles>=100");
  }
  if (
    !(
      contextLoss.recoveredWithinVsyncs > 0 &&
      contextLoss.recoveredWithinVsyncs <= 3
    )
  ) {
    failures.push("contextLoss.recoveredWithinVsyncs in 1..3");
  }
  if (!contextLoss.rasterFallbackPreservedAppRuntime) {
    failures.push("contextLoss.rasterFallbackPreservedAppRuntime");
  }
  if (!rasterFallback.automaticAfterRepeatedFailure) {
    failures.push("rasterFallback.automaticAfterRepeatedFailure");
  }
  if ((diagnostics.readbackCount ?? 1) !== 0) failures.push("diagnostics.readbackCount==0");
  if (!diagnostics.workerThread) failures.push("diagnostics.workerThread");

  if (failures.length > 0) {
    console.error("cannot claim promotion; failing gates:");
    for (const f of failures) console.error(`  - ${f}`);
    process.exit(1);
  }

  const relativeArtifact =
    options.artifact ||
    (outDir.startsWith(repoRoot) ? outDir.slice(repoRoot.length + 1) : outDir);

  const claim = {
    schemaVersion: 1,
    renderer: "skia-gpu-native",
    platform: "macos",
    backend: "metal",
    gpuPromoted: true,
    requestedMode: "auto",
    surfaceRoute: "metal-gpu",
    evidenceProvenance: {
      kind: "matching-host-artifact",
      runner: options.runner,
      artifact: relativeArtifact,
    },
    diagnostics: {
      readbackCount: diagnostics.readbackCount ?? 0,
      workerThread: true,
      surfaceGeneration: diagnostics.surfaceGeneration ?? 0,
      contextGeneration: diagnostics.contextGeneration ?? 0,
      recoveryCount: diagnostics.recoveryCount ?? 0,
      fallbackCount: diagnostics.fallbackCount ?? 0,
    },
    promotionGates: gates,
    claim: {
      notes:
        "Generated by claim-macos-gpu-promotion.mjs after matching-host gates. Source flip is separate.",
      metricsPath: metricsPath.startsWith(repoRoot)
        ? metricsPath.slice(repoRoot.length + 1)
        : metricsPath,
    },
  };

  const claimPath = join(outDir, "gpu-promotion-claim.json");
  writeFileSync(claimPath, `${JSON.stringify(claim, null, 2)}\n`);
  process.stdout.write(`wrote ${claimPath}\n`);

  if (options.requirePassed) {
    const result = validateGpuPromotionManifest(claimPath, {
      requirePassed: true,
    });
    process.stdout.write(result.stdout);
    process.stderr.write(result.stderr);
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
