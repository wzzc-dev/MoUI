#!/usr/bin/env node

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { existsSync, readFileSync, statSync } from "node:fs";
import { join, resolve } from "node:path";
import { readPinnedToolchain } from "./lib/moonbit-tool-runner.mjs";

const rootArg = process.argv.indexOf("--root");
const root = resolve(rootArg >= 0 ? process.argv[rootArg + 1] : "dist/playground");
const pinnedToolchain = readPinnedToolchain();
const required = [
  "index.html",
  "playground.wasm",
  "runtime.js",
  "browser_runtime.js",
  "canvas2d_runtime.js",
  "host/compiler-worker.js",
  "host/playground-bridge.js",
  "host/preview-host.js",
  "assets/moonc-web.cjs",
  "assets/moonc-worker.js",
  "assets/moonbit-core/core.core",
  "assets/manifest.json",
  "lessons/catalog.json",
];
for (const path of required) assert.ok(existsSync(join(root, path)), `missing ${path}`);

const index = readFileSync(join(root, "index.html"), "utf8");
assert.equal(index.includes("_build"), false, "index contains a build path");
assert.ok(index.includes('sandbox="allow-scripts"'), "preview iframe sandbox changed");
assert.match(index, /playground\.wasm\?v=[0-9a-f]{16}/, "Playground Wasm URL is not content-versioned");
assert.match(index, /compiler-worker\.js\?v=[0-9a-f]{16}/, "Playground compiler Worker URL is not content-versioned");
assert.ok(index.includes("grid-template-columns: minmax(0, 1fr) minmax(0, 1fr)"), "desktop split layout is missing");
assert.ok(index.includes("begin_example_request"), "example selector host import is missing");
assert.ok(index.includes("finish_example_request"), "example selector host completion is missing");
assert.match(
  index,
  /\[role="menu"\]\[aria-expanded="true"\][\s\S]*height: 248px !important;[\s\S]*cursor: default;[\s\S]*z-index: 1;/,
  "expanded picker options do not own their cursor hit area",
);
const previewHost = readFileSync(join(root, "host/preview-host.js"), "utf8");
assert.ok(previewHost.includes('.moui-semantics-layer [role="button"]'), "preview buttons are not directly interactive");
assert.ok(previewHost.includes("pointer-events:auto!important"), "preview button pointer events are disabled");
const playgroundBridge = readFileSync(join(root, "host/playground-bridge.js"), "utf8");
assert.ok(playgroundBridge.includes("selectExample(id)"), "example selector bridge is missing");
const compilerWorker = readFileSync(join(root, "host/compiler-worker.js"), "utf8");
assert.ok(compilerWorker.includes("web_dispatch_pointer_input"), "preview Runner is missing the web pointer ABI export");
const hostSources = [
  index,
  ...required.filter(path => path.startsWith("host/")).map(path => readFileSync(join(root, path), "utf8")),
].join("\n");
assert.equal(/codemirror/i.test(hostSources), false, "Playground contains CodeMirror");
assert.equal(/https?:\/\/(?:cdn\.|unpkg\.|esm\.sh|jsdelivr\.)/i.test(hostSources), false, "Playground contains an unpinned CDN dependency");
const manifest = JSON.parse(readFileSync(join(root, "assets/manifest.json"), "utf8"));
assert.equal(manifest.target, "wasm-gc");
assert.equal(manifest.compiler.package, "@moonbit/moonc-worker");
assert.equal(manifest.compiler.version, pinnedToolchain.mooncWorker, "Playground compiler version must match .moonbit-toolchain");
assert.equal(manifest.compiler.integrity, pinnedToolchain.mooncWorkerIntegrity, "Playground compiler integrity must match .moonbit-toolchain");
assert.ok(manifest.allowedImports.includes("wzzc-dev/moui/views"));
assert.ok(manifest.lessons.lessons.length >= 6);
for (const asset of manifest.assets) {
  assert.equal(/\.tsx?$/.test(asset.path), false, `TypeScript asset found ${asset.path}`);
  const full = join(root, asset.path);
  assert.ok(existsSync(full), `manifest asset missing ${asset.path}`);
  const hash = `sha256-${createHash("sha256").update(readFileSync(full)).digest("hex")}`;
  assert.equal(hash, asset.hash, `hash mismatch for ${asset.path}`);
  assert.equal(statSync(full).size, asset.bytes, `size mismatch for ${asset.path}`);
}
console.log(`playground asset validation ok: ${root}`);
