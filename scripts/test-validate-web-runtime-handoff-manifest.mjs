#!/usr/bin/env node

import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const tmp = mkdtempSync(join(tmpdir(), "moui-web-runtime-handoff-manifest-"));
const validator = "scripts/validate-web-runtime-handoff-manifest.mjs";

const requiredExports = [
  "web_dispatch_event",
  "web_complete_async_clipboard_read",
  "web_complete_async_file_dialog",
];

const target = ({ name, packagePath, htmlPath, wasmPath }) => ({
  name,
  packagePath,
  htmlPath,
  wasmPath,
  requiredWasmExports: requiredExports,
  compiledWasmExports: [...requiredExports, "_start"],
  htmlRuntimeImport: "../../../moui/backend/web/runtime.js",
  canvasHostSelector: "#canvas-host",
  wasmBytes: 2048,
});

const validManifest = {
  schemaVersion: 1,
  mode: "web-runtime-handoff",
  generatedBy: "scripts/validate-web-runtime-handoff.mjs",
  root: ".",
  baseUrl: "",
  evidenceBoundary:
    "Static HTML/runtime/wasm delivery and compiled WebAssembly export audit only; not browser WebGPU device, wasm instantiation, canvas presentation, or pixel evidence.",
  runtimeAssets: [
    "moui/backend/web/runtime.js",
    "moui/backend/web/browser_runtime.js",
  ],
  targets: [
    target({
      name: "showcase-web-wasm",
      packagePath: "examples/showcase/web_wasm",
      htmlPath: "examples/showcase/web_wasm/index.html",
      wasmPath: "_build/wasm-gc/debug/build/examples/showcase/web_wasm/web_wasm.wasm",
    }),
    target({
      name: "markdown-editor-web-wasm",
      packagePath: "examples/markdown_editor/web_wasm",
      htmlPath: "examples/markdown_editor/web_wasm/index.html",
      wasmPath:
        "_build/wasm-gc/debug/build/examples/markdown_editor/web_wasm/web_wasm.wasm",
    }),
  ],
  checks: [
    { kind: "file", path: "moui/backend/web/runtime.js", bytes: 1024 },
    { kind: "file", path: "moui/backend/web/browser_runtime.js", bytes: 1024 },
    {
      kind: "file",
      path: "_build/wasm-gc/debug/build/examples/showcase/web_wasm/web_wasm.wasm",
      bytes: 2048,
    },
    {
      kind: "file",
      path: "_build/wasm-gc/debug/build/examples/markdown_editor/web_wasm/web_wasm.wasm",
      bytes: 2048,
    },
  ],
};

const writeFixture = (name, manifest) => {
  const path = join(tmp, name);
  writeFileSync(path, JSON.stringify(manifest, null, 2));
  return path;
};

const runValidator = path =>
  spawnSync(process.execPath, [validator, path], { encoding: "utf8" });

const expectPass = (label, result) => {
  if (result.status !== 0) {
    console.error(`${label}: expected validator to pass`);
    console.error(result.stderr);
    process.exit(1);
  }
};

const expectFail = (label, result, expectedMessage) => {
  if (result.status === 0) {
    console.error(`${label}: expected validator to fail`);
    process.exit(1);
  }
  if (!result.stderr.includes(expectedMessage)) {
    console.error(`${label}: expected stderr to include '${expectedMessage}'`);
    console.error(result.stderr);
    process.exit(1);
  }
};

expectPass(
  "valid web runtime handoff manifest",
  runValidator(writeFixture("valid.json", validManifest)),
);

expectFail(
  "missing markdown target",
  runValidator(
    writeFixture("missing-markdown.json", {
      ...validManifest,
      targets: validManifest.targets.filter(target => target.name !== "markdown-editor-web-wasm"),
    }),
  ),
  "targets must include 'markdown-editor-web-wasm'",
);

expectFail(
  "missing compiled export",
  runValidator(
    writeFixture("missing-export.json", {
      ...validManifest,
      targets: validManifest.targets.map(target =>
        target.name === "showcase-web-wasm"
          ? {
              ...target,
              compiledWasmExports: target.compiledWasmExports.filter(
                name => name !== "web_dispatch_event",
              ),
            }
          : target,
      ),
    }),
  ),
  "compiledWasmExports must include 'web_dispatch_event'",
);

expectFail(
  "weak evidence boundary",
  runValidator(
    writeFixture("weak-boundary.json", {
      ...validManifest,
      evidenceBoundary: "Static handoff evidence.",
    }),
  ),
  "evidenceBoundary must explicitly exclude browser WebGPU device",
);

expectFail(
  "nonlocal http URL",
  runValidator(
    writeFixture("nonlocal-http.json", {
      ...validManifest,
      checks: [
        ...validManifest.checks,
        {
          kind: "http",
          label: "external",
          path: "examples/showcase/web_wasm/index.html",
          url: "https://example.com/examples/showcase/web_wasm/index.html",
          bytes: 2048,
        },
      ],
    }),
  ),
  "url must be a local HTTP URL",
);

console.log("web runtime handoff manifest validator tests: ok");
