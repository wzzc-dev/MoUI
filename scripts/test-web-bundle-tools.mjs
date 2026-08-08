#!/usr/bin/env node

import { existsSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  buildWebPackage,
  collectBundleSize,
  cleanOutputDir,
  collectAssetFiles,
  copyDirectory,
  writeCompressedSiblings,
  rewriteIndexForPackage,
  rewriteRuntimeForPackage,
} from "./web-bundle-tools.mjs";

const assert = (condition, message) => {
  if (!condition) {
    console.error(message);
    process.exit(1);
  }
};

buildWebPackage("examples/counter/web_wasm");
const manifest = collectBundleSize("examples/counter/web_wasm");
assert(manifest.schemaVersion === 1, "bundle manifest schema version mismatch");
assert(manifest.package === "examples/counter/web_wasm", "bundle package mismatch");
assert(manifest.assets.some(asset => asset.name === "web_wasm.wasm" && asset.group === "app"), "missing wasm asset");
assert(manifest.assets.some(asset => asset.name === "runtime.js" && asset.group === "runtime"), "missing runtime.js asset");
assert(manifest.assets.some(asset => asset.name === "browser_runtime.js" && asset.group === "runtime"), "missing browser_runtime.js asset");
assert(manifest.assets.some(asset => asset.name === "canvas2d_runtime.js" && asset.group === "runtime"), "missing canvas2d_runtime.js asset");
assert(manifest.assets.some(asset => asset.name === "assets/readme.txt" && asset.group === "assets"), "missing copied asset fixture in size manifest");
assert(manifest.groupTotals.assets.rawBytes > 0, "asset group total should include fixture bytes");
assert(manifest.totals.rawBytes >= manifest.groupTotals.app.rawBytes + manifest.groupTotals.runtime.rawBytes, "bundle total should include app and runtime groups");

const html = `import { bootMouiWasmGcApp } from "../../../moui_web_renderer/runtime.js";
bootMouiWasmGcApp({
  wasmUrl: new URL(
    "../../../_build/wasm-gc/debug/build/examples/counter/web_wasm/web_wasm.wasm",
    import.meta.url,
  ),
});`;
const rewritten = rewriteIndexForPackage(html, "web_wasm.wasm");
assert(rewritten.includes('from "./runtime.js"'), "packaged index should import local runtime.js");
assert(rewritten.includes('"./web_wasm.wasm"'), "packaged index should reference local wasm");
assert(!rewritten.includes("_build/wasm-gc"), "packaged index should not reference build tree");

const runtimeSource = readFileSync("moui_web_renderer/runtime.js", "utf8");
assert(!runtimeSource.includes('from "./canvas2d_runtime.js"'), "runtime.js should not statically import Canvas2D fallback");
assert(runtimeSource.includes('await import("./canvas2d_runtime.js")'), "runtime.js should dynamically import Canvas2D fallback");
const packagedRuntime = rewriteRuntimeForPackage(runtimeSource);
assert(packagedRuntime.includes('from "./browser_runtime.js"'), "packaged runtime should import local browser_runtime.js");
assert(!packagedRuntime.includes("../moui/backend/web/browser_runtime.js"), "packaged runtime should not reference the source tree");

const tmp = mkdtempSync(join(tmpdir(), "moui-web-bundle-tools-"));
writeFileSync(join(tmp, "manifest.json"), JSON.stringify(manifest, null, 2));
const assetOutput = cleanOutputDir(join(tmp, "assets-out"));
copyDirectory("examples/counter/web_wasm/assets", join(assetOutput, "assets"));
for (const asset of collectAssetFiles(join(assetOutput, "assets"))) {
  writeCompressedSiblings(asset.fullPath);
}
assert(existsSync(join(assetOutput, "assets", "readme.txt.gz")), "packaged asset gzip sibling missing");
assert(existsSync(join(assetOutput, "assets", "readme.txt.br")), "packaged asset brotli sibling missing");
console.log("web bundle tool tests: ok");
