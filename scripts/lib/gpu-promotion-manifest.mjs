/**
 * Thin Node helpers around the MoonBit GPU promotion scaffold/validator tools.
 * Schema construction and log interpretation live in
 * tools/moui/gpu_promotion_scaffold; validation lives in
 * tools/moui/validate_gpu_promotion_manifest.
 */

import { existsSync, mkdirSync, readFileSync } from "node:fs";
import { dirname, isAbsolute, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { runMoonbitTool } from "./moonbit-tool-runner.mjs";

export const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

export const PLATFORMS = [
  "macos",
  "windows",
  "linux",
  "android",
  "ios",
  "harmonyos",
  "web",
];

export const normalizeRepoPath = path =>
  isAbsolute(path) ? path : resolve(repoRoot, path);

export const ensureDir = path => {
  mkdirSync(path, { recursive: true });
  return path;
};

export const readOptionalText = path => {
  if (!existsSync(path)) return "";
  return readFileSync(path, "utf8");
};

/**
 * Run tools/moui/gpu_promotion_scaffold via moon.
 * @param {object} options
 * @param {string} options.platform
 * @param {string} options.outDir absolute or repo-relative
 * @param {string} [options.mode]
 * @param {string} [options.smokeLog]
 * @param {string} [options.metricsJson]
 * @param {string} [options.runner]
 * @param {string} [options.artifact]
 * @param {number} [options.durationSeconds]
 * @param {boolean} [options.exitOnFailure]
 */
export function runGpuPromotionScaffold(options) {
  const outDir = normalizeRepoPath(options.outDir);
  ensureDir(outDir);
  const args = [
    "--platform",
    options.platform,
    "--out-dir",
    outDir,
    "--mode",
    options.mode || "scaffold",
    "--duration-seconds",
    String(options.durationSeconds ?? 600),
  ];
  if (options.smokeLog) {
    args.push("--smoke-log", normalizeRepoPath(options.smokeLog));
  }
  if (options.metricsJson) {
    args.push("--metrics-json", normalizeRepoPath(options.metricsJson));
  }
  if (options.runner) {
    args.push("--runner", options.runner);
  }
  if (options.artifact) {
    args.push("--artifact", options.artifact);
  }
  return runMoonbitTool("tools/moui/gpu_promotion_scaffold", args, {
    exitOnFailure: options.exitOnFailure === true,
    failureStdoutToStderr: true,
  });
}

export function validateGpuPromotionManifest(manifestPath, { requirePassed = false } = {}) {
  const args = [normalizeRepoPath(manifestPath)];
  if (requirePassed) args.push("--require-passed");
  const result = spawnSync(
    process.execPath,
    [join(repoRoot, "scripts/validate-gpu-promotion-manifest.mjs"), ...args],
    {
      cwd: repoRoot,
      encoding: "utf8",
    },
  );
  return {
    status: result.status ?? 1,
    stdout: result.stdout || "",
    stderr: result.stderr || "",
    error: result.error,
  };
}

export function validateGpuWorkerNoReadback() {
  const result = spawnSync(
    process.execPath,
    [join(repoRoot, "scripts/validate-gpu-worker-no-readback.mjs")],
    {
      cwd: repoRoot,
      encoding: "utf8",
    },
  );
  return {
    status: result.status ?? 1,
    stdout: result.stdout || "",
    stderr: result.stderr || "",
    error: result.error,
  };
}

/** Heuristic only for Node-side short-smoke success checks. */
export function interpretMacosGpuSmokeLog(logText) {
  const text = logText || "";
  const metalRoute =
    /surface_route=metal-gpu/i.test(text) ||
    /route=metal-gpu/i.test(text) ||
    /MOUI_MACOS_SKIA_SURFACE_ROUTE=metal-gpu/i.test(text);
  const surfaceGpu = /surface_gpu=true/i.test(text);
  const gpuSmokePassed = /MoUI Skia GPU Metal renderer smoke passed/i.test(text);
  const presentCountMatch = text.match(/present_count=(\d+)/i);
  const presentCount = presentCountMatch
    ? Number.parseInt(presentCountMatch[1], 10)
    : 0;
  const workerOwned =
    /worker-owned/i.test(text) ||
    /Picture worker/i.test(text) ||
    /native worker/i.test(text) ||
    gpuSmokePassed;
  return {
    metalRoute,
    surfaceGpu,
    gpuSmokePassed,
    presentCount: Number.isFinite(presentCount) ? presentCount : 0,
    workerOwned,
    shortPathOk: Boolean(
      (metalRoute || gpuSmokePassed) &&
        (surfaceGpu || presentCount > 0 || gpuSmokePassed),
    ),
  };
}
