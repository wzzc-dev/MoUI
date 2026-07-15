#!/usr/bin/env node

/**
 * Run Showcase on macOS Skia with GPU performance smoke env vars, parse the
 * summary line, and write metrics.json for gpu_promotion_scaffold merge.
 *
 * Skia/Metal flags come from moui_skia prebuild. Never flips gpu_promoted.
 */

import { spawn, spawnSync } from "node:child_process";
import { createWriteStream, existsSync, mkdirSync, writeFileSync } from "node:fs";
import { dirname, isAbsolute, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  buildPerformanceMetricsOverlay,
  parsePerformanceSmokeSummary,
} from "./lib/gpu-performance-metrics.mjs";
import {
  runGpuPromotionScaffold,
  validateGpuPromotionManifest,
  validateGpuWorkerNoReadback,
} from "./lib/gpu-promotion-manifest.mjs";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const usage = `Usage: scripts/run-macos-gpu-performance-smoke.mjs [options]

Options:
  --duration-ms N        Measured window after warm-up (default 15000; use 600000 for ADR gate)
  --warm-up-presents N   Presents skipped before sampling (default 30)
  --refresh-hz N         60 or 120 budget (default 60)
  --promotion-lifecycle  After performance, run resize/fg-bg/context-loss gates
  --surface-cycles N     Surface recreate cycles (default 100)
  --fg-bg-cycles N       Foreground/background cycles (default 100)
  --context-loss N       Injected context-loss events (default 1)
  --out-dir PATH         Default artifacts/gpu-promotion/macos/perf-<timestamp>
  --prepare              Deprecated no-op (prebuild injects Skia/Metal flags)
  --skip-static-guard    Skip no-readback static guard
  --skip-scaffold        Only write metrics/log; do not run MoonBit scaffold
  --dry-run              Print plan
  -h, --help
`;

const parseArgs = argv => {
  const options = {
    durationMs: 15000,
    warmUpPresents: 30,
    refreshHz: 60,
    promotionLifecycle: false,
    surfaceCycles: 100,
    fgBgCycles: 100,
    contextLoss: 1,
    outDir: "",
    prepare: false,
    skipStaticGuard: false,
    skipScaffold: false,
    dryRun: false,
    help: false,
  };
  for (let index = 0; index < argv.length; ) {
    const arg = argv[index];
    if (arg === "--duration-ms") {
      options.durationMs = Number.parseInt(argv[index + 1] || "", 10);
      index += 2;
    } else if (arg === "--warm-up-presents") {
      options.warmUpPresents = Number.parseInt(argv[index + 1] || "", 10);
      index += 2;
    } else if (arg === "--refresh-hz") {
      options.refreshHz = Number.parseInt(argv[index + 1] || "", 10);
      index += 2;
    } else if (arg === "--promotion-lifecycle") {
      options.promotionLifecycle = true;
      index += 1;
    } else if (arg === "--surface-cycles") {
      options.surfaceCycles = Number.parseInt(argv[index + 1] || "", 10);
      index += 2;
    } else if (arg === "--fg-bg-cycles") {
      options.fgBgCycles = Number.parseInt(argv[index + 1] || "", 10);
      index += 2;
    } else if (arg === "--context-loss") {
      options.contextLoss = Number.parseInt(argv[index + 1] || "", 10);
      index += 2;
    } else if (arg === "--out-dir") {
      options.outDir = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--prepare") {
      options.prepare = true;
      index += 1;
    } else if (arg === "--skip-static-guard") {
      options.skipStaticGuard = true;
      index += 1;
    } else if (arg === "--skip-scaffold") {
      options.skipScaffold = true;
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

const normalize = path => (isAbsolute(path) ? path : resolve(repoRoot, path));

const main = async () => {
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
  for (const [name, value] of [
    ["--duration-ms", options.durationMs],
    ["--warm-up-presents", options.warmUpPresents],
    ["--refresh-hz", options.refreshHz],
  ]) {
    if (!Number.isFinite(value) || value <= 0) {
      console.error(`${name} must be a positive integer`);
      process.exit(2);
    }
  }

  const outDir = normalize(
    options.outDir ||
      join("artifacts", "gpu-promotion", "macos", `perf-${timestamp()}`),
  );
  const logPath = join(outDir, "macos-gpu-performance-smoke.log");
  const metricsPath = join(outDir, "metrics.json");
  const relativeArtifact = outDir.startsWith(repoRoot)
    ? outDir.slice(repoRoot.length + 1)
    : outDir;

  if (options.dryRun) {
    process.stdout.write(
      `${JSON.stringify({ outDir, durationMs: options.durationMs, prepare: options.prepare }, null, 2)}\n`,
    );
    process.exit(0);
  }

  mkdirSync(outDir, { recursive: true });

  if (!options.skipStaticGuard) {
    const guard = validateGpuWorkerNoReadback();
    if (guard.status !== 0) {
      process.stderr.write(guard.stdout + guard.stderr);
      process.exit(guard.status || 1);
    }
  }

  if (options.prepare) {
    process.stderr.write(
      "note: --prepare is a no-op; moui_skia prebuild injects Skia/Metal link flags\n",
    );
  }

  const env = {
    ...process.env,
    MOUI_MACOS_SKIA_SURFACE_ROUTE: "metal-gpu",
    MOUI_SKIA_RENDERER: "skia-gpu",
    MOUI_MACOS_SKIA_PERF_DURATION_MS: String(options.durationMs),
    MOUI_MACOS_SKIA_PERF_WARM_UP_PRESENTS: String(options.warmUpPresents),
    MOUI_MACOS_SKIA_PERF_REFRESH_HZ: String(options.refreshHz),
    // Ensure first-frame auto-exit is not also set.
    MOUI_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT: "0",
    MOUI_MARKDOWN_EDITOR_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT: "0",
  };
  if (options.promotionLifecycle) {
    env.MOUI_MACOS_SKIA_PROMOTION_LIFECYCLE = "1";
    env.MOUI_MACOS_SKIA_PROMOTION_SURFACE_CYCLES = String(options.surfaceCycles);
    env.MOUI_MACOS_SKIA_PROMOTION_FG_BG_CYCLES = String(options.fgBgCycles);
    env.MOUI_MACOS_SKIA_PROMOTION_CONTEXT_LOSS = String(options.contextLoss);
  }

  // Stream logs continuously so long runs survive tool disconnects and leave
  // checkpoint lines on disk even if the process is interrupted.
  const logStream = createWriteStream(logPath, { flags: "w" });
  const chunks = [];
  const child = spawn(
    "moon",
    ["run", "examples/showcase/macos_skia", "--target", "native"],
    {
      cwd: repoRoot,
      env,
      stdio: ["ignore", "pipe", "pipe"],
    },
  );
  const onChunk = chunk => {
    const text = chunk.toString("utf8");
    chunks.push(text);
    logStream.write(text);
    process.stdout.write(text);
  };
  child.stdout.on("data", onChunk);
  child.stderr.on("data", onChunk);
  const runStatus = await new Promise(resolveStatus => {
    child.on("error", err => {
      const msg = `failed to spawn moon: ${err.message}\n`;
      chunks.push(msg);
      logStream.write(msg);
      resolveStatus(1);
    });
    child.on("close", code => resolveStatus(code ?? 1));
  });
  await new Promise(resolveClose => logStream.end(resolveClose));
  const combined = chunks.join("");

  const summary = parsePerformanceSmokeSummary(combined);
  if (!summary) {
    console.error(
      "performance summary marker not found; see",
      logPath,
      "(need Skia/Metal prebuild flags; ensure moui_skia prebuild can resolve Skia)",
    );
    process.exit(runStatus === 0 ? 1 : runStatus || 1);
  }

  const metalUnavailable =
    /Metal GPU route requested but Ganesh Metal runtime is unavailable/i.test(
      combined,
    ) || /falling back to raster/i.test(combined);
  if (metalUnavailable) {
    process.stderr.write(
      "warning: performance smoke ran with Metal unavailable (raster fallback); metrics are not GPU-present evidence\n",
    );
  }

  const metrics = buildPerformanceMetricsOverlay(summary, {
    notes: metalUnavailable
      ? "macOS performance smoke fell back to raster (Metal unavailable); not GPU-present evidence."
      : "macOS present-to-present performance smoke; input latency is interval/budget proxy, not pointer-to-present.",
  });
  writeFileSync(metricsPath, `${JSON.stringify(metrics, null, 2)}\n`);
  process.stdout.write(
    [
      `status=${summary.status}`,
      `samples=${summary.samples}`,
      `p95_frame_ms=${summary.p95FrameMs}`,
      `dropped_frame_percent=${summary.droppedFramePercent}`,
      `duration_ms=${summary.durationMs}`,
      `wrote ${metricsPath}`,
      `wrote ${logPath}`,
    ].join("\n") + "\n",
  );

  if (!options.skipScaffold) {
    const scaffold = runGpuPromotionScaffold({
      platform: "macos",
      outDir,
      mode: "full",
      metricsJson: metricsPath,
      smokeLog: logPath,
      runner: "scripts/run-macos-gpu-performance-smoke.mjs",
      artifact: relativeArtifact,
      durationSeconds: Math.max(1, Math.round(options.durationMs / 1000)),
      exitOnFailure: false,
    });
    if (scaffold.status !== 0) {
      console.error("scaffold failed");
      process.exit(scaffold.status || 1);
    }
    const validation = validateGpuPromotionManifest(
      join(outDir, "gpu-promotion-manifest.json"),
      { requirePassed: false },
    );
    process.stdout.write(`validate_exit=${validation.status}\n`);
    if (validation.status !== 0) {
      process.stderr.write(validation.stdout + validation.stderr);
      process.exit(validation.status || 1);
    }
  }

  if (summary.status !== "completed") {
    process.exit(1);
  }
  // Performance-only run is partial evidence; exit 0 on completed measurement.
  process.exit(0);
};

// Ensure timed-out summaries fail even if scaffold validate passed.
// (main already exits 1 above when status != completed.)
main().catch(error => {
  console.error(String(error && error.stack ? error.stack : error));
  process.exit(1);
});
