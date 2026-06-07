#!/usr/bin/env node

import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { basename, join } from "node:path";

const usage = () => {
  console.error(
    "Usage: node scripts/validate-renderer-proof-manifest.mjs <renderer-proof.json> [--require-passed] [--artifact-root <dir>]",
  );
  process.exit(2);
};

const args = process.argv.slice(2);
if (args.length < 1) usage();

let manifestPath = "";
let requirePassed = false;
let artifactRoot = "";

for (let index = 0; index < args.length; index += 1) {
  const arg = args[index];
  if (arg === "--require-passed") {
    requirePassed = true;
  } else if (arg === "--artifact-root") {
    artifactRoot = args[++index] ?? "";
  } else if (!manifestPath) {
    manifestPath = arg;
  } else {
    usage();
  }
}

if (!manifestPath) usage();

const fail = message => {
  console.error(`${manifestPath}: ${message}`);
  process.exit(1);
};

let manifest;
try {
  manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
} catch (error) {
  fail(`failed to read JSON: ${error.message}`);
}

const requiredObservationEvidence = {
  radialGradient: ["center-mid-edge-pixels", "shader-payload"],
  transformPixels: ["pixel-markers"],
  colorEmojiPixels: ["high-saturation-pixels", "glyph-or-raster", "font-metadata", "glyph-metadata"],
  zwjGrapheme: ["single-grapheme-cluster", "no-interior-caret"],
  bidiLayout: ["visual-order"],
  paragraphWrapping: ["line-metrics", "later-line-pixels"],
  asyncImageSecondFrame: ["late-completion", "repaint-request", "second-frame-pixels"],
};

const allowedBackends = new Set(["wgpu-native", "skia-native", "webgpu-wasm"]);
const allowedPlatforms = new Set(["macos", "windows", "linux", "web"]);
const allowedStatus = new Set(["passed", "failed", "pending"]);

const requireObject = (value, label) => {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    fail(`${label} must be an object`);
  }
  return value;
};

const requireString = (object, key, label) => {
  const value = object[key];
  if (typeof value !== "string" || value.trim() === "") {
    fail(`${label}.${key} must be a non-empty string`);
  }
  return value;
};

const requireArray = (object, key, label) => {
  const value = object[key];
  if (!Array.isArray(value)) {
    fail(`${label}.${key} must be an array`);
  }
  return value;
};

const requireNumber = (object, key, label) => {
  const value = object[key];
  if (typeof value !== "number" || !Number.isFinite(value)) {
    fail(`${label}.${key} must be a finite number`);
  }
  return value;
};

const requireArtifactPaths = (paths, label) => {
  if (paths.length === 0) fail(`${label} must include at least one artifact path`);
  for (const [index, artifact] of paths.entries()) {
    if (typeof artifact !== "string" || artifact.trim() === "") {
      fail(`${label}[${index}] must be a non-empty string`);
    }
    if (!artifact.startsWith("artifacts/")) {
      fail(`${label}[${index}] must stay under artifacts/`);
    }
  }
};

const listFiles = root => {
  const out = [];
  const visit = dir => {
    for (const entry of readdirSync(dir)) {
      const path = join(dir, entry);
      const stat = statSync(path);
      if (stat.isDirectory()) {
        visit(path);
      } else if (stat.isFile()) {
        out.push(path.replace(/\\/g, "/"));
      }
    }
  };
  visit(root);
  return out;
};

let artifactFiles;
const artifactFileExists = artifact => {
  if (!artifactRoot) return true;
  if (!existsSync(artifactRoot)) {
    fail(`artifact root does not exist: ${artifactRoot}`);
  }
  const normalized = artifact.replace(/\\/g, "/");
  if (existsSync(join(artifactRoot, normalized))) return true;
  artifactFiles ??= listFiles(artifactRoot);
  return artifactFiles.some(path => path.endsWith(`/${normalized}`)) ||
    artifactFiles.some(path => basename(path) === basename(normalized));
};

const requireArtifactFilesExist = (paths, label) => {
  if (!artifactRoot) return;
  for (const artifact of paths) {
    if (!artifactFileExists(artifact)) {
      fail(`${label} missing uploaded artifact file: ${artifact}`);
    }
  }
};

const schemaVersion = manifest.schemaVersion;
if (schemaVersion !== 1) fail("schemaVersion must be 1");
if (manifest.mode !== "renderer-proof") fail("mode must be 'renderer-proof'");

const backend = requireString(manifest, "backend", "manifest");
if (!allowedBackends.has(backend)) fail(`backend '${backend}' is not recognized`);

const platform = requireString(manifest, "platform", "manifest");
if (!allowedPlatforms.has(platform)) fail(`platform '${platform}' is not recognized`);
if (backend === "webgpu-wasm" && platform !== "web") {
  fail("webgpu-wasm renderer proof must use platform 'web'");
}
if (backend !== "webgpu-wasm" && platform === "web") {
  fail(`${backend} renderer proof must use a native platform`);
}

const status = requireString(manifest, "status", "manifest");
if (!allowedStatus.has(status)) fail(`status '${status}' is not recognized`);
if (requirePassed && status !== "passed") {
  fail("status must be passed when --require-passed is set");
}

const provenance = requireObject(manifest.provenance, "provenance");
const provenanceKind = requireString(provenance, "kind", "provenance");
if (status === "passed" && provenanceKind !== "github-actions") {
  fail("passed renderer proof requires github-actions provenance");
}
for (const key of ["workflow", "job", "runId", "runUrl", "runner", "artifactName"]) {
  requireString(provenance, key, "provenance");
}
if (provenance.runUrl && !provenance.runUrl.startsWith("https://github.com/")) {
  fail("provenance.runUrl must be a GitHub Actions URL");
}

const artifacts = requireArray(manifest, "artifacts", "manifest");
requireArtifactPaths(artifacts, "manifest.artifacts");
if (status === "passed") requireArtifactFilesExist(artifacts, "manifest.artifacts");

const observations = requireObject(manifest.observations, "observations");
const actualObservationKeys = Object.keys(observations).sort();
const expectedObservationKeys = Object.keys(requiredObservationEvidence).sort();
if (JSON.stringify(actualObservationKeys) !== JSON.stringify(expectedObservationKeys)) {
  fail(`observations must contain exactly: ${expectedObservationKeys.join(", ")}`);
}

for (const key of expectedObservationKeys) {
  const observation = requireObject(observations[key], `observations.${key}`);
  const observationStatus = requireString(observation, "status", `observations.${key}`);
  if (!allowedStatus.has(observationStatus)) {
    fail(`observations.${key}.status '${observationStatus}' is not recognized`);
  }
  const evidence = requireArray(observation, "evidence", `observations.${key}`);
  const observationArtifacts = requireArray(observation, "artifacts", `observations.${key}`);
  requireArtifactPaths(observationArtifacts, `observations.${key}.artifacts`);
  if (status === "passed" || observationStatus === "passed") {
    requireArtifactFilesExist(observationArtifacts, `observations.${key}.artifacts`);
  }
  for (const [index, item] of evidence.entries()) {
    if (typeof item !== "string" || item.trim() === "") {
      fail(`observations.${key}.evidence[${index}] must be a non-empty string`);
    }
    if (item.includes("caret-only") || item.includes("coverage-only")) {
      fail(`observations.${key}.evidence must not use caret-only or coverage-only proof`);
    }
  }
  if (status === "passed" || observationStatus === "passed") {
    if (observationStatus !== "passed") {
      fail(`observations.${key}.status must be passed for passed renderer proof`);
    }
    for (const required of requiredObservationEvidence[key]) {
      if (!evidence.includes(required)) {
        fail(`observations.${key}.evidence must include '${required}'`);
      }
    }
    if (key === "colorEmojiPixels") {
      const metadata = requireObject(observation.metadata, "observations.colorEmojiPixels.metadata");
      const font = requireObject(metadata.font, "observations.colorEmojiPixels.metadata.font");
      requireString(font, "family", "observations.colorEmojiPixels.metadata.font");
      requireString(font, "source", "observations.colorEmojiPixels.metadata.font");
      requireString(font, "textSystem", "observations.colorEmojiPixels.metadata.font");
      const glyph = requireObject(metadata.glyph, "observations.colorEmojiPixels.metadata.glyph");
      const glyphFormat = requireString(glyph, "format", "observations.colorEmojiPixels.metadata.glyph");
      if (glyphFormat !== "rgba") {
        fail("observations.colorEmojiPixels.metadata.glyph.format must be rgba");
      }
      if (requireNumber(glyph, "glyphCount", "observations.colorEmojiPixels.metadata.glyph") < 1) {
        fail("observations.colorEmojiPixels.metadata.glyph.glyphCount must be at least 1");
      }
      if (requireNumber(glyph, "clusterCount", "observations.colorEmojiPixels.metadata.glyph") < 1) {
        fail("observations.colorEmojiPixels.metadata.glyph.clusterCount must be at least 1");
      }
      if (
        requireNumber(
          glyph,
          "highSaturationPixels",
          "observations.colorEmojiPixels.metadata.glyph",
        ) < 8
      ) {
        fail("observations.colorEmojiPixels.metadata.glyph.highSaturationPixels must be at least 8");
      }
      requireNumber(glyph, "alphaPixels", "observations.colorEmojiPixels.metadata.glyph");
    }
  }
}

console.log(`${manifestPath}: ok (renderer proof manifest)`);
