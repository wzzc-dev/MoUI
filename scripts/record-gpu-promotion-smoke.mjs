#!/usr/bin/env node

/**
 * Thin Node orchestrator for ADR 0006 GPU promotion scaffolding.
 *
 * Manifest construction / gap reports: tools/moui/gpu_promotion_scaffold
 * Validation: tools/moui/validate_gpu_promotion_manifest
 * This script only spawns smokes and calls those tools.
 *
 * Never flips NativeGpuPlatform::gpu_promoted.
 */

import { spawnSync } from "node:child_process";
import { join } from "node:path";
import {
  PLATFORMS,
  ensureDir,
  interpretMacosGpuSmokeLog,
  normalizeRepoPath,
  readOptionalText,
  repoRoot,
  runGpuPromotionScaffold,
  validateGpuPromotionManifest,
  validateGpuWorkerNoReadback,
} from "./lib/gpu-promotion-manifest.mjs";
import { writeFileSync } from "node:fs";

const usage = `Usage: scripts/record-gpu-promotion-smoke.mjs --platform <id> [options]

Platforms: ${PLATFORMS.join("|")}

Options:
  --mode scaffold|short-smoke|performance|full
                         scaffold (default): MoonBit pending manifest + gap report.
                         short-smoke: macOS Metal short path then scaffold ingest.
                         performance: run macOS GPU present-interval harness
                         (scripts/run-macos-gpu-performance-smoke.mjs) and merge metrics.
                         full: write full-plan.json + empty metrics skeleton,
                         merge via --metrics-json if measurements exist later,
                         then exit 3 until remaining gates land.
  --out-dir PATH         Default artifacts/gpu-promotion/<platform>/<timestamp>
  --duration-seconds N   Requested full-run duration (default 600).
  --metrics-json PATH    Optional measured metrics overlay for scaffold merge.
  --require-passed       Validate with --require-passed (expected fail until gates).
  --skip-static-guard    Skip validate-gpu-worker-no-readback.mjs
  --dry-run              Print plan only.
  -h, --help             Show this help.
`;

const parseArgs = argv => {
  const options = {
    platform: "",
    mode: "scaffold",
    outDir: "",
    durationSeconds: 600,
    metricsJson: "",
    requirePassed: false,
    skipStaticGuard: false,
    dryRun: false,
    help: false,
  };
  for (let index = 0; index < argv.length; ) {
    const arg = argv[index];
    if (arg === "--platform") {
      options.platform = (argv[index + 1] || "").toLowerCase();
      index += 2;
    } else if (arg === "--mode") {
      options.mode = (argv[index + 1] || "").toLowerCase();
      index += 2;
    } else if (arg === "--out-dir") {
      options.outDir = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--duration-seconds") {
      options.durationSeconds = Number.parseInt(argv[index + 1] || "", 10);
      index += 2;
    } else if (arg === "--metrics-json") {
      options.metricsJson = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--require-passed") {
      options.requirePassed = true;
      index += 1;
    } else if (arg === "--skip-static-guard") {
      options.skipStaticGuard = true;
      index += 1;
    } else if (arg === "--dry-run") {
      options.dryRun = true;
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

const fullPlan = ({ platform, durationSeconds, outDir }) => ({
  schemaVersion: 1,
  status: "not-implemented",
  platform,
  durationSecondsRequested: durationSeconds,
  outDir,
  phases: [
    {
      id: "short-path",
      description: "Metal/Vulkan/D3D/EGL GPU present markers (short smoke)",
      status: platform === "macos" ? "available-via-short-smoke" : "pending",
    },
    {
      id: "performance",
      description: "≥ durationSeconds frame telemetry p95/drop%/input latency",
      status: "missing-runner",
    },
    {
      id: "memory-lifecycle",
      description: "≥ 100 surface recreation + ≥ 100 fg/bg; bounded memory",
      status: "missing-runner",
    },
    {
      id: "mailbox-stress",
      description: "Frame flood with non-droppable lifecycle controls",
      status: "missing-runner",
    },
    {
      id: "context-loss",
      description: "Forced loss recover ≤ 3 VSync; preserve AppRuntime",
      status: "missing-runner",
    },
    {
      id: "raster-fallback",
      description: "Automatic fallback after repeated recovery failure",
      status: "missing-runner",
    },
  ],
  metricsJsonTemplate: {
    notes: "Fill from matching-host full harness; never hand-claim promotion.",
    diagnostics: {
      readbackCount: 0,
      workerThread: false,
      surfaceGeneration: 0,
      contextGeneration: 0,
      recoveryCount: 0,
      fallbackCount: 0,
    },
    promotionGates: {
      readbackEliminated: false,
      rendererThread: false,
      mailboxOk: false,
      performance: {
        refreshHz: 60,
        durationSeconds: 0,
        p95FrameMs: 0,
        droppedFramePercent: 100,
        inputToPresentPVsyncIntervals: 0,
      },
      memory: {
        bounded: false,
        surfaceRecreationCycles: 0,
        foregroundBackgroundCycles: 0,
      },
      contextLoss: {
        recoveredWithinVsyncs: 0,
        rasterFallbackPreservedAppRuntime: false,
      },
      rasterFallback: {
        automaticAfterRepeatedFailure: false,
      },
    },
  },
});

const timestamp = () => {
  const d = new Date();
  const pad = n => String(n).padStart(2, "0");
  return [
    d.getUTCFullYear(),
    pad(d.getUTCMonth() + 1),
    pad(d.getUTCDate()),
    "T",
    pad(d.getUTCHours()),
    pad(d.getUTCMinutes()),
    pad(d.getUTCSeconds()),
    "Z",
  ].join("");
};

const run = (cmd, args) =>
  spawnSync(cmd, args, {
    cwd: repoRoot,
    env: process.env,
    encoding: "utf8",
  });

const main = () => {
  let options;
  try {
    options = parseArgs(process.argv.slice(2));
  } catch (error) {
    console.error(String(error.message || error));
    console.error(usage);
    process.exit(2);
  }

  if (options.help) {
    process.stdout.write(usage);
    process.exit(0);
  }

  if (!options.platform || !PLATFORMS.includes(options.platform)) {
    console.error(`--platform must be one of: ${PLATFORMS.join(", ")}`);
    process.exit(2);
  }
  if (!["scaffold", "short-smoke", "performance", "full"].includes(options.mode)) {
    console.error("--mode must be scaffold, short-smoke, performance, or full");
    process.exit(2);
  }
  if (
    (options.mode === "short-smoke" || options.mode === "performance") &&
    options.platform !== "macos"
  ) {
    console.error(`${options.mode} is currently implemented for --platform macos only`);
    process.exit(2);
  }
  if (!Number.isFinite(options.durationSeconds) || options.durationSeconds <= 0) {
    console.error("--duration-seconds must be a positive integer");
    process.exit(2);
  }

  const outDir = normalizeRepoPath(
    options.outDir ||
      join("artifacts", "gpu-promotion", options.platform, timestamp()),
  );
  const relativeArtifact = outDir.startsWith(repoRoot)
    ? outDir.slice(repoRoot.length + 1)
    : outDir;
  const smokeLogPath = join(outDir, "macos-gpu-short-smoke.log");
  const recorderLogPath = join(outDir, "recorder.log");
  const manifestPath = join(outDir, "gpu-promotion-manifest.json");

  const plan = {
    platform: options.platform,
    mode: options.mode,
    outDir,
    tool: "tools/moui/gpu_promotion_scaffold",
    gpuPromoted: false,
  };

  if (options.dryRun) {
    process.stdout.write(`${JSON.stringify(plan, null, 2)}\n`);
    process.exit(0);
  }

  ensureDir(outDir);
  const logLines = [
    `platform=${options.platform}`,
    `mode=${options.mode}`,
    `outDir=${outDir}`,
    `started=${new Date().toISOString()}`,
  ];

  if (!options.skipStaticGuard) {
    const staticGuard = validateGpuWorkerNoReadback();
    logLines.push(`staticGuard.status=${staticGuard.status}`);
    if (staticGuard.status !== 0) {
      writeFileSync(recorderLogPath, `${logLines.join("\n")}\n`);
      console.error("validate-gpu-worker-no-readback failed; refusing to record");
      process.stderr.write(staticGuard.stdout + staticGuard.stderr);
      process.exit(staticGuard.status || 1);
    }
  }

  let shortSmoke = null;
  if (options.mode === "short-smoke") {
    const smoke = run("bash", [
      "scripts/macos-skia-renderer-smoke.sh",
      "--run-gpu-smoke",
      "--run-showcase-smoke",
      "--smoke-log",
      smokeLogPath,
      "--showcase-log",
      join(outDir, "macos-showcase-first-frame.log"),
    ]);
    const combined = [
      smoke.stdout || "",
      smoke.stderr || "",
      readOptionalText(smokeLogPath),
      readOptionalText(join(outDir, "macos-showcase-first-frame.log")),
    ].join("\n");
    writeFileSync(smokeLogPath, combined.endsWith("\n") ? combined : `${combined}\n`);
    shortSmoke = interpretMacosGpuSmokeLog(combined);
    logLines.push(
      `shortSmoke.exit=${smoke.status ?? "error"}`,
      `shortSmoke.shortPathOk=${shortSmoke.shortPathOk}`,
    );
  }

  let metricsJsonPath = options.metricsJson
    ? normalizeRepoPath(options.metricsJson)
    : "";
  if (options.mode === "performance") {
    const perf = run(process.execPath, [
      "scripts/run-macos-gpu-performance-smoke.mjs",
      "--duration-ms",
      String(Math.max(1000, options.durationSeconds * 1000)),
      "--out-dir",
      outDir,
      "--skip-scaffold",
      ...(options.skipStaticGuard ? ["--skip-static-guard"] : []),
    ]);
    logLines.push(`performance.exit=${perf.status ?? "error"}`);
    writeFileSync(
      join(outDir, "performance-runner.log"),
      `${perf.stdout || ""}\n${perf.stderr || ""}\n`,
    );
    metricsJsonPath = join(outDir, "metrics.json");
    if (perf.status !== 0) {
      writeFileSync(recorderLogPath, `${logLines.join("\n")}\n`);
      console.error("performance harness failed");
      process.stderr.write(perf.stdout + perf.stderr);
      process.exit(perf.status || 1);
    }
  }
  if (options.mode === "full") {
    const planPath = join(outDir, "full-plan.json");
    const metricsTemplatePath = join(outDir, "metrics-template.json");
    const plan = fullPlan({
      platform: options.platform,
      durationSeconds: options.durationSeconds,
      outDir: relativeArtifact,
    });
    writeFileSync(planPath, `${JSON.stringify(plan, null, 2)}\n`);
    writeFileSync(
      metricsTemplatePath,
      `${JSON.stringify(plan.metricsJsonTemplate, null, 2)}\n`,
    );
    logLines.push(
      "full mode harness is not implemented yet",
      `wrote ${planPath}`,
      `wrote ${metricsTemplatePath}`,
    );
    if (!metricsJsonPath) {
      metricsJsonPath = metricsTemplatePath;
    }
  }

  const scaffoldMode =
    options.mode === "performance" ? "full" : options.mode;
  const scaffold = runGpuPromotionScaffold({
    platform: options.platform,
    outDir,
    mode: scaffoldMode,
    smokeLog:
      options.mode === "short-smoke"
        ? smokeLogPath
        : options.mode === "performance"
          ? join(outDir, "macos-gpu-performance-smoke.log")
          : "",
    metricsJson: metricsJsonPath,
    runner:
      options.mode === "short-smoke"
        ? "scripts/record-gpu-promotion-smoke.mjs --mode short-smoke"
        : options.mode === "performance"
          ? "scripts/record-gpu-promotion-smoke.mjs --mode performance"
          : options.mode === "full"
            ? "scripts/record-gpu-promotion-smoke.mjs --mode full"
            : "scripts/record-gpu-promotion-smoke.mjs --mode scaffold",
    artifact: relativeArtifact,
    durationSeconds: options.durationSeconds,
    exitOnFailure: false,
  });
  logLines.push(`scaffold.status=${scaffold.status ?? "error"}`);
  if (scaffold.status !== 0) {
    writeFileSync(recorderLogPath, `${logLines.join("\n")}\n`);
    console.error("gpu_promotion_scaffold failed");
    process.exit(scaffold.status || 1);
  }

  const validation = validateGpuPromotionManifest(manifestPath, {
    requirePassed: options.requirePassed,
  });
  logLines.push(
    `validate.status=${validation.status}`,
    validation.stdout.trim(),
    validation.stderr.trim(),
    `finished=${new Date().toISOString()}`,
  );
  writeFileSync(recorderLogPath, `${logLines.filter(Boolean).join("\n")}\n`);

  process.stdout.write(
    [
      `wrote ${manifestPath}`,
      `wrote ${join(outDir, "gap-report.md")}`,
      `wrote ${join(outDir, "gate-inventory.json")}`,
      `gpuPromoted=false gatesComplete=false`,
      `validate_exit=${validation.status}`,
    ].join("\n") + "\n",
  );

  if (options.requirePassed && validation.status !== 0) {
    process.stderr.write(
      "manifest does not satisfy --require-passed (expected until full gates land)\n",
    );
    process.exit(validation.status || 1);
  }
  if (!options.requirePassed && validation.status !== 0) {
    process.stderr.write("schema validation failed\n");
    process.stderr.write(validation.stdout + validation.stderr);
    process.exit(validation.status || 1);
  }
  if (options.mode === "full") {
    process.stderr.write(
      "full GPU promotion harness still missing memory/context-loss/mailbox phases; scaffold written only\n",
    );
    process.exit(3);
  }
  if (options.mode === "short-smoke" && shortSmoke && !shortSmoke.shortPathOk) {
    process.stderr.write(
      "short-smoke completed but Metal GPU short-path markers were not observed\n",
    );
    process.exit(1);
  }
  process.exit(0);
};

main();
