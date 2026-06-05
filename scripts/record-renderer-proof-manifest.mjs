#!/usr/bin/env node

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import { spawnSync } from "node:child_process";

const usage = () => {
  console.error(
    "Usage: node scripts/record-renderer-proof-manifest.mjs --backend <wgpu-native|skia-native|webgpu-wasm> --platform <macos|windows|linux|web> --artifact-name <name> --output <path> --log <path> [--log <path> ...] [--require-passed]",
  );
  process.exit(2);
};

const args = process.argv.slice(2);
let backend = "";
let platform = "";
let artifactName = "";
let output = "";
const logs = [];
let requirePassed = false;

for (let index = 0; index < args.length; index += 1) {
  const arg = args[index];
  if (arg === "--backend") backend = args[++index] ?? "";
  else if (arg === "--platform") platform = args[++index] ?? "";
  else if (arg === "--artifact-name") artifactName = args[++index] ?? "";
  else if (arg === "--output") output = args[++index] ?? "";
  else if (arg === "--log") logs.push(args[++index] ?? "");
  else if (arg === "--require-passed") requirePassed = true;
  else usage();
}

if (!backend || !platform || !artifactName || !output || logs.length === 0) usage();

const markerConfig = {
  radialGradient: {
    required: ["center-mid-edge-pixels", "shader-payload"],
    marker: "MoUI renderer proof radialGradient passed",
  },
  transformPixels: {
    required: ["pixel-markers"],
    marker: "MoUI renderer proof transformPixels passed",
  },
  colorEmojiPixels: {
    required: ["high-saturation-pixels", "glyph-or-raster"],
    marker: "MoUI renderer proof colorEmojiPixels passed",
  },
  zwjGrapheme: {
    required: ["single-grapheme-cluster", "no-interior-caret"],
    marker: "MoUI renderer proof zwjGrapheme passed",
  },
  bidiLayout: {
    required: ["visual-order"],
    marker: "MoUI renderer proof bidiLayout passed",
  },
  paragraphWrapping: {
    required: ["line-metrics", "later-line-pixels"],
    marker: "MoUI renderer proof paragraphWrapping passed",
  },
  asyncImageSecondFrame: {
    required: ["late-completion", "repaint-request", "second-frame-pixels"],
    marker: "MoUI renderer proof asyncImageSecondFrame passed",
  },
};

const readLog = path => {
  try {
    return readFileSync(path, "utf8");
  } catch (error) {
    return `\nMoUI renderer proof log read failed: ${path}: ${error.message}\n`;
  }
};

const artifactPath = path => {
  const normalized = path.replace(/\\/g, "/");
  const marker = "/artifacts/";
  const markerIndex = normalized.indexOf(marker);
  if (markerIndex >= 0) return normalized.slice(markerIndex + 1);
  if (normalized.startsWith("artifacts/")) return normalized;
  return normalized;
};

const combinedLog = logs.map(readLog).join("\n");
const relLogs = logs.map(artifactPath);

const observationFor = ([key, config]) => {
  const hasMarker = combinedLog.includes(config.marker);
  const hasEvidence = config.required.every(token => combinedLog.includes(token));
  const passed = hasMarker && hasEvidence;
  return [
    key,
    {
      status: passed ? "passed" : "failed",
      evidence: passed ? config.required : [],
      artifacts: relLogs,
    },
  ];
};

const observations = Object.fromEntries(Object.entries(markerConfig).map(observationFor));
const status = Object.values(observations).every(observation => observation.status === "passed")
  ? "passed"
  : "failed";

const repository = process.env.GITHUB_REPOSITORY || "unknown/unknown";
const runId = process.env.GITHUB_RUN_ID || "local";
const serverUrl = process.env.GITHUB_SERVER_URL || "https://github.com";
const manifest = {
  schemaVersion: 1,
  mode: "renderer-proof",
  generatedBy: "scripts/record-renderer-proof-manifest.mjs",
  backend,
  platform,
  status,
  provenance: {
    kind: process.env.GITHUB_ACTIONS === "true" ? "github-actions" : "matching-host-artifact",
    workflow: process.env.GITHUB_WORKFLOW || "local",
    job: process.env.GITHUB_JOB || "local",
    runId,
    runUrl: `${serverUrl}/${repository}/actions/runs/${runId}`,
    runner: process.env.RUNNER_NAME || process.env.RUNNER_OS || "local",
    artifactName,
  },
  artifacts: relLogs.concat([artifactPath(output)]),
  observations,
};

mkdirSync(dirname(output), { recursive: true });
writeFileSync(output, `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`renderer proof manifest: ${output} (${status})`);

const validationArgs = ["scripts/validate-renderer-proof-manifest.mjs", output];
if (requirePassed) validationArgs.push("--require-passed");
const validation = spawnSync(process.execPath, validationArgs, { encoding: "utf8" });
if (validation.stdout) process.stdout.write(validation.stdout);
if (validation.stderr) process.stderr.write(validation.stderr);
if (validation.status !== 0) process.exit(validation.status ?? 1);
