#!/usr/bin/env node

import { readFileSync } from "node:fs";

const usage = () => {
  console.error(
    "Usage: node scripts/validate-web-runtime-handoff-manifest.mjs <web-runtime-handoff.json>",
  );
};

const args = process.argv.slice(2);
if (args.length < 1 || args.includes("--help") || args.includes("-h")) {
  usage();
  process.exit(args.length < 1 ? 2 : 0);
}

const manifestPath = args[0];
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

const requiredExports = [
  "web_dispatch_event",
  "web_complete_async_clipboard_read",
  "web_complete_async_file_dialog",
];

const expectedTargets = new Map([
  [
    "showcase-web-wasm",
    {
      packagePath: "examples/showcase/web_wasm",
      htmlPath: "examples/showcase/web_wasm/index.html",
      wasmPath: "_build/wasm-gc/debug/build/examples/showcase/web_wasm/web_wasm.wasm",
    },
  ],
  [
    "markdown-editor-web-wasm",
    {
      packagePath: "examples/markdown_editor/web_wasm",
      htmlPath: "examples/markdown_editor/web_wasm/index.html",
      wasmPath:
        "_build/wasm-gc/debug/build/examples/markdown_editor/web_wasm/web_wasm.wasm",
    },
  ],
]);

if (manifest.schemaVersion !== 1) {
  fail("schemaVersion must be 1");
}

const mode = requireString(manifest, "mode");
if (mode !== "web-runtime-handoff") {
  fail("mode must be 'web-runtime-handoff'");
}

const generatedBy = requireString(manifest, "generatedBy");
if (generatedBy !== "scripts/validate-web-runtime-handoff.mjs") {
  fail("generatedBy must be scripts/validate-web-runtime-handoff.mjs");
}

requireString(manifest, "root");
if (typeof manifest.baseUrl !== "string") {
  fail("baseUrl must be a string");
}

const evidenceBoundary = requireString(manifest, "evidenceBoundary");
if (
  !evidenceBoundary.includes("not browser WebGPU device") ||
  !evidenceBoundary.includes("wasm instantiation") ||
  !evidenceBoundary.includes("pixel evidence")
) {
  fail(
    "evidenceBoundary must explicitly exclude browser WebGPU device, wasm instantiation, and pixel evidence",
  );
}

const runtimeAssets = requireArray(manifest, "runtimeAssets");
assertStringArray(runtimeAssets, "runtimeAssets");
assertIncludesAll(
  runtimeAssets,
  ["moui/backend/web/runtime.js", "moui/backend/web/browser_runtime.js"],
  "runtimeAssets",
);

const targets = requireArray(manifest, "targets");
const seenTargets = new Set();

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
  for (const field of ["packagePath", "htmlPath", "wasmPath"]) {
    const value = requireString(target, field, `${label}.${field}`);
    if (value !== expected[field]) {
      fail(`${label}.${field} must be '${expected[field]}' for '${name}'`);
    }
  }
  const requiredWasmExports = requireArray(
    target,
    "requiredWasmExports",
    `${label}.requiredWasmExports`,
  );
  const compiledWasmExports = requireArray(
    target,
    "compiledWasmExports",
    `${label}.compiledWasmExports`,
  );
  assertStringArray(requiredWasmExports, `${label}.requiredWasmExports`);
  assertStringArray(compiledWasmExports, `${label}.compiledWasmExports`);
  assertIncludesAll(requiredWasmExports, requiredExports, `${label}.requiredWasmExports`);
  assertIncludesAll(compiledWasmExports, requiredExports, `${label}.compiledWasmExports`);
  if (requireString(target, "htmlRuntimeImport", `${label}.htmlRuntimeImport`) !== "../../../moui/backend/web/runtime.js") {
    fail(`${label}.htmlRuntimeImport must be '../../../moui/backend/web/runtime.js'`);
  }
  if (requireString(target, "canvasHostSelector", `${label}.canvasHostSelector`) !== "#canvas-host") {
    fail(`${label}.canvasHostSelector must be '#canvas-host'`);
  }
  const wasmBytes = requireNumber(target, "wasmBytes", `${label}.wasmBytes`);
  if (wasmBytes < 1024) {
    fail(`${label}.wasmBytes must be at least 1024`);
  }
});

for (const name of expectedTargets.keys()) {
  if (!seenTargets.has(name)) {
    fail(`targets must include '${name}'`);
  }
}

const checks = requireArray(manifest, "checks");
if (checks.length === 0) {
  fail("checks must include at least one file or http check");
}

checks.forEach((check, index) => {
  if (!check || typeof check !== "object" || Array.isArray(check)) {
    fail(`checks[${index}] must be an object`);
    return;
  }
  const label = `checks[${index}]`;
  const kind = requireString(check, "kind", `${label}.kind`);
  if (!["file", "http"].includes(kind)) {
    fail(`${label}.kind must be file or http`);
  }
  const path = requireString(check, "path", `${label}.path`);
  const bytes = requireNumber(check, "bytes", `${label}.bytes`);
  if (bytes <= 0) {
    fail(`${label}.bytes must be positive`);
  }
  if (kind === "file") {
    const allowed = [
      "moui/backend/web/runtime.js",
      "moui/backend/web/browser_runtime.js",
      ...[...expectedTargets.values()].map(target => target.wasmPath),
    ];
    if (!allowed.includes(path)) {
      fail(`${label}.path is not an expected file check path`);
    }
  }
  if (kind === "http") {
    requireString(check, "label", `${label}.label`);
    const url = requireString(check, "url", `${label}.url`);
    if (!url.startsWith("http://127.0.0.1:") && !url.startsWith("http://localhost:")) {
      fail(`${label}.url must be a local HTTP URL`);
    }
  }
});

if (failed) {
  process.exit(1);
}

console.log(`${manifestPath}: ok (web runtime handoff manifest)`);
