#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { mkdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { dirname } from "node:path";

const usage = () => {
  console.error(
    "Usage: node scripts/validate-web-runtime-handoff.mjs [--base-url http://127.0.0.1:18080] [--manifest artifacts/conformance/web-runtime-handoff.json]",
  );
};

let baseUrl = "";
let manifestPath = "";
const rootDir = process.env.MOUI_WEB_RUNTIME_HANDOFF_ROOT || ".";
const args = process.argv.slice(2);
for (let i = 0; i < args.length; i += 1) {
  if (args[i] === "--base-url") {
    baseUrl = args[i + 1] ?? "";
    i += 1;
  } else if (args[i] === "--manifest") {
    manifestPath = args[i + 1] ?? "";
    i += 1;
  } else if (args[i] === "--help" || args[i] === "-h") {
    usage();
    process.exit(0);
  } else {
    console.error(`Unknown argument: ${args[i]}`);
    usage();
    process.exit(2);
  }
}

const targets = [
  {
    name: "showcase-web-wasm",
    packagePath: "examples/showcase/web_wasm",
    htmlPath: "examples/showcase/web_wasm/index.html",
    wasmPath: "_build/wasm-gc/debug/build/examples/showcase/web_wasm/web_wasm.wasm",
  },
  {
    name: "markdown-editor-web-wasm",
    packagePath: "examples/markdown_editor/web_wasm",
    htmlPath: "examples/markdown_editor/web_wasm/index.html",
    wasmPath:
      "_build/wasm-gc/debug/build/examples/markdown_editor/web_wasm/web_wasm.wasm",
  },
];

let failed = false;
const checks = [];

const fail = message => {
  console.error(`web runtime handoff: ${message}`);
  failed = true;
};

const recordCheck = check => {
  checks.push(check);
};

const readText = path => {
  try {
    return readFileSync(join(rootDir, path), "utf8");
  } catch (error) {
    fail(`${path}: failed to read: ${error.message}`);
    return "";
  }
};

const requireFile = path => {
  try {
    const stats = statSync(join(rootDir, path));
    if (!stats.isFile()) {
      fail(`${path}: must be a file`);
      return 0;
    }
    const size = stats.size;
    recordCheck({ kind: "file", path, bytes: size });
    return size;
  } catch (error) {
    fail(`${path}: missing file`);
    return 0;
  }
};

const assertIncludes = (content, needle, label) => {
  if (!content.includes(needle)) {
    fail(`${label} must include '${needle}'`);
  }
};

const requiredWasmExports = [
  "web_dispatch_event",
  "web_complete_async_clipboard_read",
  "web_complete_async_file_dialog",
];

const validateWasmExports = async (path, bytes) => {
  let module;
  try {
    module = await WebAssembly.compile(bytes);
  } catch (error) {
    fail(`${path}: failed to compile wasm module for export audit: ${error.message}`);
    return;
  }
  const exports = WebAssembly.Module.exports(module).map(entry => entry.name);
  const exportSet = new Set(exports);
  for (const exportName of requiredWasmExports) {
    if (!exportSet.has(exportName)) {
      fail(`${path}: missing required wasm export '${exportName}'`);
    }
  }
  return exports;
};

const normalizeBaseUrl = url => url.replace(/\/+$/, "");

const checkHttp = async (path, label) => {
  if (!baseUrl) return;
  const url = `${normalizeBaseUrl(baseUrl)}/${path}`;
  let response;
  try {
    response = await fetch(url, { method: "GET" });
  } catch (error) {
    fail(`${label}: failed to fetch ${url}: ${error.message}`);
    return;
  }
  if (!response.ok) {
    fail(`${label}: ${url} returned ${response.status} ${response.statusText}`);
    return;
  }
  const bytes = (await response.arrayBuffer()).byteLength;
  if (bytes === 0) {
    fail(`${label}: ${url} returned an empty body`);
  }
  recordCheck({ kind: "http", label, path, url, bytes });
};

requireFile("moui/backend/web/runtime.js");
requireFile("moui/backend/web/browser_runtime.js");

const runtimeJs = readText("moui/backend/web/runtime.js");
assertIncludes(runtimeJs, "Browser WebGPU is required", "moui/backend/web/runtime.js");
assertIncludes(runtimeJs, "bootMouiWasmGcApp", "moui/backend/web/runtime.js");

const browserRuntimeJs = readText("moui/backend/web/browser_runtime.js");
assertIncludes(browserRuntimeJs, "install_canvas_events", "moui/backend/web/browser_runtime.js");
assertIncludes(browserRuntimeJs, "create_canvas", "moui/backend/web/browser_runtime.js");

const targetManifests = [];

for (const target of targets) {
  const html = readText(target.htmlPath);
  assertIncludes(html, "bootMouiWasmGcApp", `${target.htmlPath}`);
  assertIncludes(html, "../../../moui/backend/web/runtime.js", `${target.htmlPath}`);
  assertIncludes(html, "#canvas-host", `${target.htmlPath}`);
  assertIncludes(html, "Loading wasm-gc", `${target.htmlPath}`);
  assertIncludes(html, "Running", `${target.htmlPath}`);
  assertIncludes(html, target.wasmPath.replace("_build", "../../../_build"), `${target.htmlPath}`);

  const targetManifest = {
    name: target.name,
    packagePath: target.packagePath,
    htmlPath: target.htmlPath,
    wasmPath: target.wasmPath,
    requiredWasmExports,
    compiledWasmExports: [],
    htmlRuntimeImport: "../../../moui/backend/web/runtime.js",
    canvasHostSelector: "#canvas-host",
  };

  const wasmSize = requireFile(target.wasmPath);
  if (wasmSize > 0 && wasmSize < 1024) {
    fail(`${target.wasmPath}: wasm artifact is unexpectedly small (${wasmSize} bytes)`);
  }
  const wasmBytes = wasmSize ? readFileSync(join(rootDir, target.wasmPath)) : Buffer.alloc(0);
  if (wasmBytes.length > 0) {
    targetManifest.compiledWasmExports = await validateWasmExports(target.wasmPath, wasmBytes) ?? [];
  }
  targetManifest.wasmBytes = wasmSize;

  await checkHttp(`${target.packagePath}/index.html`, `${target.name} html`);
  await checkHttp(target.wasmPath, `${target.name} wasm`);
  targetManifests.push(targetManifest);
}

await checkHttp("moui/backend/web/runtime.js", "web runtime.js");
await checkHttp("moui/backend/web/browser_runtime.js", "browser_runtime.js");

if (failed) {
  process.exit(1);
}

if (manifestPath) {
  const manifest = {
    schemaVersion: 1,
    mode: "web-runtime-handoff",
    generatedBy: "scripts/validate-web-runtime-handoff.mjs",
    root: rootDir,
    baseUrl: baseUrl || "",
    evidenceBoundary:
      "Static HTML/runtime/wasm delivery and compiled WebAssembly export audit only; not browser WebGPU device, wasm instantiation, canvas presentation, or pixel evidence.",
    runtimeAssets: [
      "moui/backend/web/runtime.js",
      "moui/backend/web/browser_runtime.js",
    ],
    targets: targetManifests,
    checks,
  };
  mkdirSync(dirname(manifestPath), { recursive: true });
  writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
  console.log(`web runtime handoff manifest: ${manifestPath}`);
  const validation = spawnSync(
    process.execPath,
    ["scripts/validate-web-runtime-handoff-manifest.mjs", manifestPath],
    { encoding: "utf8" },
  );
  if (validation.stdout) process.stdout.write(validation.stdout);
  if (validation.stderr) process.stderr.write(validation.stderr);
  if (validation.status !== 0) {
    process.exit(validation.status ?? 1);
  }
}

console.log("web runtime handoff: ok");
