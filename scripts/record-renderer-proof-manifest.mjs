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
    required: ["high-saturation-pixels", "glyph-or-raster", "font-metadata", "glyph-metadata"],
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
  selectionRects: {
    required: ["selection-rects", "line-range"],
    marker: "MoUI renderer proof selectionRects passed",
  },
  graphemeEditing: {
    required: ["grapheme-boundaries", "edit-actions"],
    marker: "MoUI renderer proof graphemeEditing passed",
  },
  imeCandidateAnchor: {
    required: ["candidate-anchor", "surrounding-text"],
    marker: "MoUI renderer proof imeCandidateAnchor passed",
  },
  imeCompositionVisual: {
    required: ["composition-range", "preedit-pixels"],
    marker: "MoUI renderer proof imeCompositionVisual passed",
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

const parseMetadataFields = prefix => {
  const line = combinedLog
    .split(/\r?\n/)
    .find(item => item.startsWith(prefix));
  if (!line) return null;
  const fields = {};
  for (const token of line.slice(prefix.length).trim().split(/\s+/)) {
    const separator = token.indexOf("=");
    if (separator <= 0) continue;
    fields[token.slice(0, separator)] = token.slice(separator + 1);
  }
  return fields;
};

const parseNumber = value => {
  const number = Number(value);
  return Number.isFinite(number) ? number : 0;
};

const colorEmojiMetadata = () => {
  const fields = parseMetadataFields("MoUI renderer proof colorEmojiPixels metadata ");
  if (!fields) return null;
  const glyph = {
    format: fields.glyph_format || "unknown",
    glyphCount: parseNumber(fields.glyph_count),
    clusterCount: parseNumber(fields.cluster_count),
    highSaturationPixels: parseNumber(fields.high_saturation_pixels),
    alphaPixels: parseNumber(fields.alpha_pixels),
  };
  if (fields.glyph_key) glyph.key = fields.glyph_key;
  if (fields.glyph_width) glyph.width = parseNumber(fields.glyph_width);
  if (fields.glyph_height) glyph.height = parseNumber(fields.glyph_height);
  return {
    font: {
      family: fields.font_family || "unknown",
      source: fields.font_source || "unknown",
      textSystem: fields.text_system || "unknown",
      shaper: fields.shaper || "unknown",
    },
    glyph,
  };
};

const colorEmojiMetadataReady = metadata => {
  if (!metadata) return false;
  const font = metadata.font || {};
  const glyph = metadata.glyph || {};
  return (
    typeof font.family === "string" &&
    font.family.trim() !== "" &&
    font.family !== "unknown" &&
    typeof font.source === "string" &&
    font.source.trim() !== "" &&
    font.source !== "unknown" &&
    typeof font.textSystem === "string" &&
    font.textSystem.trim() !== "" &&
    font.textSystem !== "unknown" &&
    glyph.format === "rgba" &&
    Number(glyph.glyphCount) >= 1 &&
    Number(glyph.clusterCount) >= 1 &&
    typeof glyph.key === "string" &&
    glyph.key.trim() !== "" &&
    Number(glyph.width) > 0 &&
    Number(glyph.height) > 0 &&
    Number(glyph.highSaturationPixels) >= 8 &&
    Number(glyph.alphaPixels) > 0
  );
};

const observationFor = ([key, config]) => {
  const hasMarker = combinedLog.includes(config.marker);
  const hasEvidence = config.required.every(token => combinedLog.includes(token));
  const metadata = key === "colorEmojiPixels" ? colorEmojiMetadata() : null;
  const passed =
    hasMarker &&
    hasEvidence &&
    (key !== "colorEmojiPixels" || colorEmojiMetadataReady(metadata));
  return [
    key,
    {
      status: passed ? "passed" : "failed",
      evidence: passed ? config.required : [],
      artifacts: relLogs,
      ...(metadata ? { metadata } : {}),
    },
  ];
};

const observations = Object.fromEntries(Object.entries(markerConfig).map(observationFor));
const observationsPassed = Object.values(observations).every(
  observation => observation.status === "passed",
);
const isGithubActions = process.env.GITHUB_ACTIONS === "true";
const status = observationsPassed && isGithubActions ? "passed" : "failed";

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
    kind: isGithubActions ? "github-actions" : "matching-host-artifact",
    workflow: process.env.GITHUB_WORKFLOW || "local",
    job: process.env.GITHUB_JOB || "local",
    runId,
    runUrl: `${serverUrl}/${repository}/actions/runs/${runId}`,
    runner: process.env.RUNNER_NAME || process.env.RUNNER_OS || "local",
    artifactName,
  },
  artifacts: relLogs.concat([artifactPath(output)]),
  observations,
  notes: observationsPassed && !isGithubActions
    ? [
        "All renderer observations passed locally, but renderer-proof manifests require GitHub Actions provenance before status can be passed.",
      ]
    : [],
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
