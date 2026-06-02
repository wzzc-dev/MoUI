#!/usr/bin/env node

import { readFileSync } from "node:fs";

const usage = () => {
  console.error(
    "Usage: node scripts/validate-web-runtime-presentation-manifest.mjs <web-runtime-presentation.json> [--require-passed]",
  );
};

const args = process.argv.slice(2);
if (args.length < 1 || args.includes("--help") || args.includes("-h")) {
  usage();
  process.exit(args.length < 1 ? 2 : 0);
}

const manifestPath = args[0];
let requirePassed = false;

for (let i = 1; i < args.length; i += 1) {
  if (args[i] === "--require-passed") {
    requirePassed = true;
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

const requireNumber = (object, field, label = field) => {
  const value = object?.[field];
  if (typeof value !== "number" || !Number.isFinite(value)) {
    fail(`missing finite number field '${label}'`);
    return 0;
  }
  return value;
};

const requireBoolean = (object, field, label = field) => {
  const value = object?.[field];
  if (typeof value !== "boolean") {
    fail(`missing boolean field '${label}'`);
    return false;
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

const requireObject = (object, field, label = field) => {
  const value = object?.[field];
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    fail(`field '${label}' must be an object`);
    return {};
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

const expectedTargets = new Map([
  [
    "showcase-web-wasm",
    {
      packagePath: "examples/showcase/web_wasm",
      path: "examples/showcase/web_wasm/index.html",
    },
  ],
  [
    "markdown-editor-web-wasm",
    {
      packagePath: "examples/markdown_editor/web_wasm",
      path: "examples/markdown_editor/web_wasm/index.html",
    },
  ],
]);

const observationKeys = [
  "pageLoaded",
  "webGpuAvailable",
  "adapterRequested",
  "deviceRequested",
  "wasmStarted",
  "statusRunning",
  "canvasCreated",
  "canvasSized",
  "nonblankScreenshot",
  "cleanConsole",
];

const localUrlPattern = /^http:\/\/(127\.0\.0\.1|localhost):\d+\//;

if (manifest.schemaVersion !== 1) {
  fail("schemaVersion must be 1");
}

const mode = requireString(manifest, "mode");
if (mode !== "web-runtime-presentation") {
  fail("mode must be 'web-runtime-presentation'");
}

const generatedBy = requireString(manifest, "generatedBy");
if (generatedBy !== "scripts/record-web-runtime-presentation.mjs") {
  fail("generatedBy must be scripts/record-web-runtime-presentation.mjs");
}

const overallStatus = requireString(manifest, "overallStatus");
if (!["passed", "failed"].includes(overallStatus)) {
  fail("overallStatus must be passed or failed");
}
if (requirePassed && overallStatus !== "passed") {
  fail("overallStatus must be passed when --require-passed is used");
}

const baseUrl = requireString(manifest, "baseUrl");
if (!localUrlPattern.test(`${baseUrl.replace(/\/+$/, "")}/`)) {
  fail("baseUrl must be a local HTTP URL");
}

const cdpUrl = requireString(manifest, "cdpUrl");
if (!localUrlPattern.test(`${cdpUrl.replace(/\/+$/, "")}/`)) {
  fail("cdpUrl must be a local HTTP URL");
}

const evidenceBoundary = requireString(manifest, "evidenceBoundary");
for (const token of ["WebGPU", "wasm app startup", "screenshot", "not prove cross-browser"]) {
  if (!evidenceBoundary.includes(token)) {
    fail(`evidenceBoundary must include '${token}'`);
  }
}

const browser = requireObject(manifest, "browser");
requireString(browser, "product", "browser.product");
requireString(browser, "userAgent", "browser.userAgent");
requireString(browser, "protocolVersion", "browser.protocolVersion");

const targets = requireArray(manifest, "targets");
const seenTargets = new Set();
let passedCount = 0;

targets.forEach((target, index) => {
  if (!target || typeof target !== "object" || Array.isArray(target)) {
    fail(`targets[${index}] must be an object`);
    return;
  }

  const label = `targets[${index}]`;
  const name = requireString(target, "name", `${label}.name`);
  if (seenTargets.has(name)) {
    fail(`duplicate target '${name}'`);
  }
  seenTargets.add(name);

  const expected = expectedTargets.get(name);
  if (!expected) {
    fail(`${label}.name must be one of ${[...expectedTargets.keys()].join(", ")}`);
    return;
  }

  if (requireString(target, "packagePath", `${label}.packagePath`) !== expected.packagePath) {
    fail(`${label}.packagePath must be '${expected.packagePath}' for '${name}'`);
  }
  if (requireString(target, "path", `${label}.path`) !== expected.path) {
    fail(`${label}.path must be '${expected.path}' for '${name}'`);
  }
  const url = requireString(target, "url", `${label}.url`);
  if (!localUrlPattern.test(url)) {
    fail(`${label}.url must be a local HTTP URL`);
  }

  const status = requireString(target, "status", `${label}.status`);
  if (!["passed", "failed"].includes(status)) {
    fail(`${label}.status must be passed or failed`);
  }
  if (status === "passed") passedCount += 1;
  if (requirePassed && status !== "passed") {
    fail(`${label}.status must be passed when --require-passed is used`);
  }

  requireString(target, "title", `${label}.title`);
  requireString(target, "statusText", `${label}.statusText`);
  requireBoolean(target, "bodyFailed", `${label}.bodyFailed`);
  requireBoolean(target, "navigatorGpu", `${label}.navigatorGpu`);

  const canvas = requireObject(target, "canvas", `${label}.canvas`);
  const canvasCount = requireNumber(canvas, "count", `${label}.canvas.count`);
  const hostWidth = requireNumber(canvas, "hostWidth", `${label}.canvas.hostWidth`);
  const hostHeight = requireNumber(canvas, "hostHeight", `${label}.canvas.hostHeight`);
  const canvasWidth = requireNumber(canvas, "canvasWidth", `${label}.canvas.canvasWidth`);
  const canvasHeight = requireNumber(canvas, "canvasHeight", `${label}.canvas.canvasHeight`);

  const runtimeSignals = requireObject(
    target,
    "runtimeSignals",
    `${label}.runtimeSignals`,
  );
  for (const key of ["adapterRequested", "deviceRequested", "wasmStarted", "running"]) {
    requireBoolean(runtimeSignals, key, `${label}.runtimeSignals.${key}`);
  }

  const screenshot = requireObject(target, "screenshot", `${label}.screenshot`);
  const artifact = requireString(screenshot, "artifact", `${label}.screenshot.artifact`);
  if (!artifact.endsWith(".png")) {
    fail(`${label}.screenshot.artifact must end with .png`);
  }
  const screenshotWidth = requireNumber(screenshot, "width", `${label}.screenshot.width`);
  const screenshotHeight = requireNumber(screenshot, "height", `${label}.screenshot.height`);
  const totalPixels = requireNumber(screenshot, "totalPixels", `${label}.screenshot.totalPixels`);
  const contentPixels = requireNumber(
    screenshot,
    "contentPixels",
    `${label}.screenshot.contentPixels`,
  );
  const distinctColorBuckets = requireNumber(
    screenshot,
    "distinctColorBuckets",
    `${label}.screenshot.distinctColorBuckets`,
  );

  const observations = requireObject(target, "observations", `${label}.observations`);
  for (const key of observationKeys) {
    const value = observations[key];
    if (!["yes", "no"].includes(value)) {
      fail(`${label}.observations.${key} must be yes or no`);
    }
  }

  const consoleErrors = requireArray(target, "consoleErrors", `${label}.consoleErrors`);
  assertStringArray(consoleErrors, `${label}.consoleErrors`);
  const notes = requireArray(target, "notes", `${label}.notes`);
  assertStringArray(notes, `${label}.notes`);

  if (status === "passed") {
    if (target.statusText !== "Running") {
      fail(`${label}.statusText must be Running for passed evidence`);
    }
    if (target.bodyFailed !== false || target.navigatorGpu !== true) {
      fail(`${label} passed evidence requires bodyFailed=false and navigatorGpu=true`);
    }
    if (canvasCount < 1 || hostWidth <= 0 || hostHeight <= 0 || canvasWidth <= 0 || canvasHeight <= 0) {
      fail(`${label} passed evidence requires a sized canvas`);
    }
    if (screenshotWidth <= 0 || screenshotHeight <= 0 || totalPixels <= 0) {
      fail(`${label} passed evidence requires a non-empty screenshot`);
    }
    if (contentPixels < 500 || distinctColorBuckets < 6) {
      fail(`${label} passed evidence requires a nonblank screenshot`);
    }
    if (consoleErrors.length !== 0) {
      fail(`${label} passed evidence must not contain console errors`);
    }
    for (const key of observationKeys) {
      if (observations[key] !== "yes") {
        fail(`${label}.observations.${key} must be yes for passed evidence`);
      }
    }
  } else {
    if (!observationKeys.some(key => observations[key] === "no")) {
      fail(`${label} failed evidence must include at least one no observation`);
    }
  }
});

for (const name of expectedTargets.keys()) {
  if (!seenTargets.has(name)) {
    fail(`targets must include '${name}'`);
  }
}

if (targets.length !== expectedTargets.size) {
  fail(`targets must contain exactly ${expectedTargets.size} entries`);
}

if (overallStatus === "passed" && passedCount !== expectedTargets.size) {
  fail("overallStatus passed requires all target entries to pass");
}
if (overallStatus === "failed" && passedCount === expectedTargets.size) {
  fail("overallStatus failed requires at least one failed target entry");
}

if (failed) {
  process.exit(1);
}

console.log(`${manifestPath}: ok (web runtime presentation manifest)`);
