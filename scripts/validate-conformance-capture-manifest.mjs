#!/usr/bin/env node

import { readFileSync } from "node:fs";

const usage = () => {
  console.error(
    "Usage: node scripts/validate-conformance-capture-manifest.mjs <manifest.json> [--mode golden|benchmark]",
  );
};

const args = process.argv.slice(2);
if (args.length < 1 || args.includes("--help") || args.includes("-h")) {
  usage();
  process.exit(args.length < 1 ? 2 : 0);
}

const manifestPath = args[0];
let expectedMode = "";

for (let i = 1; i < args.length; i += 1) {
  if (args[i] === "--mode") {
    expectedMode = args[i + 1] ?? "";
    i += 1;
  } else {
    console.error(`Unknown argument: ${args[i]}`);
    usage();
    process.exit(2);
  }
}

let failed = false;

const fail = message => {
  console.error(`${manifestPath}: ${message}`);
  failed = true;
};

let manifest;
try {
  manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
} catch (error) {
  console.error(`${manifestPath}: failed to read JSON: ${error.message}`);
  process.exit(1);
}

const requireString = (object, field, label = field) => {
  const value = object?.[field];
  if (typeof value !== "string" || value.trim() === "") {
    fail(`missing non-empty string field '${label}'`);
    return "";
  }
  return value;
};

const requireArray = (object, field, label = field) => {
  const value = object?.[field];
  if (!Array.isArray(value)) {
    fail(`field '${label}' must be an array`);
    return [];
  }
  return value;
};

const assertStringArray = (values, label) => {
  values.forEach((value, index) => {
    if (typeof value !== "string" || value.trim() === "") {
      fail(`${label}[${index}] must be a non-empty string`);
    }
  });
};

const assertIncludesAll = (values, expected, label) => {
  for (const value of expected) {
    if (!values.includes(value)) {
      fail(`${label} must include '${value}'`);
    }
  }
};

if (manifest.schemaVersion !== 1) {
  fail("schemaVersion must be 1");
}

const mode = requireString(manifest, "mode");
if (!mode || !["golden", "benchmark"].includes(mode)) {
  fail("mode must be 'golden' or 'benchmark'");
}
if (expectedMode && mode !== expectedMode) {
  fail(`mode must be '${expectedMode}'`);
}

const showcaseTarget = requireString(manifest, "showcaseTarget");
if (showcaseTarget !== "examples/showcase/web_wasm") {
  fail("showcaseTarget must be 'examples/showcase/web_wasm'");
}

const url = requireString(manifest, "url");
if (!url.endsWith("/examples/showcase/web_wasm/")) {
  fail("url must point at /examples/showcase/web_wasm/");
}

const expectedBenchmarkTargets = new Map([
  [
    "showcase-web-wasm",
    {
      target: "examples/showcase/web_wasm",
      url: "http://127.0.0.1:18080/examples/showcase/web_wasm/",
      metricsPath: "artifacts/benchmarks/showcase-web-wasm.json",
    },
  ],
  [
    "markdown-editor-web-wasm",
    {
      target: "examples/markdown_editor/web_wasm",
      url: "http://127.0.0.1:18080/examples/markdown_editor/web_wasm/",
      metricsPath: "artifacts/benchmarks/markdown-editor-web-wasm.json",
    },
  ],
]);

const benchmarkTargets =
  mode === "benchmark" || Array.isArray(manifest.benchmarkTargets)
    ? requireArray(manifest, "benchmarkTargets")
    : [];
const seenBenchmarkTargetNames = new Set();

benchmarkTargets.forEach((target, index) => {
  if (!target || typeof target !== "object" || Array.isArray(target)) {
    fail(`benchmarkTargets[${index}] must be an object`);
    return;
  }
  const label = `benchmarkTargets[${index}]`;
  const name = requireString(target, "name", `${label}.name`);
  const targetPath = requireString(target, "target", `${label}.target`);
  const targetUrl = requireString(target, "url", `${label}.url`);
  const metricsPath = requireString(
    target,
    "metricsPath",
    `${label}.metricsPath`,
  );

  if (seenBenchmarkTargetNames.has(name)) {
    fail(`duplicate benchmark target '${name}'`);
  }
  seenBenchmarkTargetNames.add(name);

  const expected = expectedBenchmarkTargets.get(name);
  if (expected) {
    if (targetPath !== expected.target) {
      fail(`${label}.target must be '${expected.target}' for '${name}'`);
    }
    if (targetUrl !== expected.url) {
      fail(`${label}.url must be '${expected.url}' for '${name}'`);
    }
    if (metricsPath !== expected.metricsPath) {
      fail(
        `${label}.metricsPath must be '${expected.metricsPath}' for '${name}'`,
      );
    }
  } else if (!metricsPath.startsWith("artifacts/benchmarks/")) {
    fail(`${label}.metricsPath must stay under artifacts/benchmarks/`);
  }
});

if (mode === "benchmark") {
  for (const name of expectedBenchmarkTargets.keys()) {
    if (!seenBenchmarkTargetNames.has(name)) {
      fail(`benchmarkTargets must include '${name}'`);
    }
  }
}

requireString(manifest, "renderInspectorSource");

const requiredCounters = [
  "command_count",
  "text_count",
  "image_count",
  "clip_depth",
  "open_clip_depth",
  "layer_depth",
  "open_layer_depth",
  "filter_depth",
  "open_filter_depth",
  "path_count",
  "shader_count",
  "unbalanced_pop_count",
];
const counters = requireArray(manifest, "renderInspectorCounters");
assertStringArray(counters, "renderInspectorCounters");
assertIncludesAll(counters, requiredCounters, "renderInspectorCounters");

const expectedScreenshots = new Map([
  [
    "desktop",
    {
      viewport: "1440x900",
      path: "artifacts/golden/showcase-web-wasm/desktop.png",
    },
  ],
  [
    "tablet",
    {
      viewport: "1024x768",
      path: "artifacts/golden/showcase-web-wasm/tablet.png",
    },
  ],
  [
    "mobile",
    {
      viewport: "390x844",
      path: "artifacts/golden/showcase-web-wasm/mobile.png",
    },
  ],
]);
const screenshotArtifacts = requireArray(manifest, "screenshotArtifacts");
const seenScreenshotNames = new Set();

screenshotArtifacts.forEach((artifact, index) => {
  if (!artifact || typeof artifact !== "object" || Array.isArray(artifact)) {
    fail(`screenshotArtifacts[${index}] must be an object`);
    return;
  }
  const label = `screenshotArtifacts[${index}]`;
  const name = requireString(artifact, "name", `${label}.name`);
  const viewport = requireString(artifact, "viewport", `${label}.viewport`);
  const path = requireString(artifact, "path", `${label}.path`);

  if (seenScreenshotNames.has(name)) {
    fail(`duplicate screenshot artifact '${name}'`);
  }
  seenScreenshotNames.add(name);

  const expected = expectedScreenshots.get(name);
  if (expected) {
    if (viewport !== expected.viewport) {
      fail(`${label}.viewport must be '${expected.viewport}' for '${name}'`);
    }
    if (path !== expected.path) {
      fail(`${label}.path must be '${expected.path}' for '${name}'`);
    }
  } else if (!path.startsWith("artifacts/golden/showcase-web-wasm/")) {
    fail(`${label}.path must stay under artifacts/golden/showcase-web-wasm/`);
  }
});

for (const name of expectedScreenshots.keys()) {
  if (!seenScreenshotNames.has(name)) {
    fail(`screenshotArtifacts must include '${name}'`);
  }
}

const requiredMetrics = [
  "startup_ms",
  "frame_time_ms",
  "dirty_count",
  "draw_command_count",
  "memory_bytes",
  "render_inspector_counters",
];
const metrics = requireArray(manifest, "benchmarkMetrics");
assertStringArray(metrics, "benchmarkMetrics");
assertIncludesAll(metrics, requiredMetrics, "benchmarkMetrics");

const notes = requireArray(manifest, "notes");
if (notes.length === 0) {
  fail("notes must include at least one handoff note");
}
assertStringArray(notes, "notes");

if (failed) {
  process.exit(1);
}

console.log(`${manifestPath}: ok (${mode} conformance capture manifest)`);
