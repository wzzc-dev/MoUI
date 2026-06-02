#!/usr/bin/env node

import { cpSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { spawnSync } from "node:child_process";

const validator = "scripts/validate-web-runtime-handoff.mjs";
const tmp = mkdtempSync(join(tmpdir(), "moui-web-runtime-handoff-"));

const fixtureFiles = [
  "examples/showcase/web_wasm/index.html",
  "examples/markdown_editor/web_wasm/index.html",
  "moui/backend/web/runtime.js",
  "moui/backend/web/browser_runtime.js",
  "_build/wasm-gc/debug/build/examples/showcase/web_wasm/web_wasm.wasm",
  "_build/wasm-gc/debug/build/examples/markdown_editor/web_wasm/web_wasm.wasm",
];

const copyFixture = name => {
  const root = join(tmp, name);
  for (const file of fixtureFiles) {
    const output = join(root, file);
    mkdirSync(dirname(output), { recursive: true });
    cpSync(file, output);
  }
  return root;
};

const runValidator = (root, extraArgs = []) =>
  spawnSync(process.execPath, [validator, ...extraArgs], {
    encoding: "utf8",
    env: { ...process.env, MOUI_WEB_RUNTIME_HANDOFF_ROOT: root },
  });

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

const replaceInFixture = (root, file, search, replacement) => {
  const path = join(root, file);
  const content = readFileSync(path, "utf8");
  writeFileSync(path, content.replace(search, replacement));
};

const validRoot = copyFixture("valid");
const validManifestPath = join(tmp, "valid-web-runtime-handoff.json");
expectPass(
  "valid web runtime handoff fixture",
  runValidator(validRoot, ["--manifest", validManifestPath]),
);
const validManifest = JSON.parse(readFileSync(validManifestPath, "utf8"));
if (validManifest.schemaVersion !== 1 || validManifest.mode !== "web-runtime-handoff") {
  console.error("valid web runtime handoff fixture: manifest schema was not written");
  process.exit(1);
}
if (validManifest.targets?.length !== 2) {
  console.error("valid web runtime handoff fixture: manifest must include both Web targets");
  process.exit(1);
}
const showcaseTarget = validManifest.targets.find(target => target.name === "showcase-web-wasm");
if (!showcaseTarget?.compiledWasmExports?.includes("web_dispatch_event")) {
  console.error("valid web runtime handoff fixture: manifest must record compiled wasm exports");
  process.exit(1);
}
if (!validManifest.evidenceBoundary.includes("not browser WebGPU")) {
  console.error("valid web runtime handoff fixture: manifest must keep evidence boundary explicit");
  process.exit(1);
}

const brokenHtml = copyFixture("broken-html");
replaceInFixture(
  brokenHtml,
  "examples/showcase/web_wasm/index.html",
  "../../../moui/backend/web/runtime.js",
  "../../../moui/backend/web/missing-runtime.js",
);
expectFail(
  "broken html runtime import",
  runValidator(brokenHtml),
  "examples/showcase/web_wasm/index.html must include '../../../moui/backend/web/runtime.js'",
);

const brokenRuntime = copyFixture("broken-runtime");
replaceInFixture(
  brokenRuntime,
  "moui/backend/web/runtime.js",
  "Browser WebGPU is required",
  "Browser renderer unavailable",
);
expectFail(
  "broken browser webgpu diagnostic",
  runValidator(brokenRuntime),
  "moui/backend/web/runtime.js must include 'Browser WebGPU is required'",
);

const brokenWasm = copyFixture("broken-wasm");
writeFileSync(
  join(brokenWasm, "_build/wasm-gc/debug/build/examples/showcase/web_wasm/web_wasm.wasm"),
  Buffer.from("not a wasm module"),
);
expectFail(
  "broken wasm compile",
  runValidator(brokenWasm),
  "failed to compile wasm module for export audit",
);

console.log("web runtime handoff validator tests: ok");
