#!/usr/bin/env node

import { join } from "node:path";
import { repoRoot, runCommand, runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

const invocationRoot = process.cwd();
const toolPackage = "tools/moui/validate_web_runtime_handoff";

const usage = () => {
  console.error(
    "Usage: node scripts/validate-web-runtime-handoff.mjs [--base-url http://127.0.0.1:18080] [--manifest artifacts/conformance/web-runtime-handoff.json]",
  );
};

let baseUrl = "";
let manifestPath = "";
const rootDir = process.env.MOUI_WEB_RUNTIME_HANDOFF_ROOT || ".";
const originalArgs = process.argv.slice(2);

for (let i = 0; i < originalArgs.length; i += 1) {
  const arg = originalArgs[i];
  if (arg === "--base-url") {
    if (i + 1 >= originalArgs.length) {
      console.error("Missing value for --base-url");
      usage();
      process.exit(2);
    }
    baseUrl = originalArgs[i + 1];
    i += 1;
  } else if (arg === "--manifest") {
    if (i + 1 >= originalArgs.length) {
      console.error("Missing value for --manifest");
      usage();
      process.exit(2);
    }
    manifestPath = originalArgs[i + 1];
    i += 1;
  } else if (arg === "--help" || arg === "-h") {
    usage();
    process.exit(0);
  } else {
    console.error(`Unknown argument: ${arg}`);
    usage();
    process.exit(2);
  }
}

const targets = [
  {
    name: "showcase-web-wasm",
    packagePath: "examples/showcase/web_wasm",
    wasmPath: "_build/wasm-gc/debug/build/examples/showcase/web_wasm/web_wasm.wasm",
  },
  {
    name: "markdown-editor-web-wasm",
    packagePath: "examples/markdown_editor/web_wasm",
    wasmPath:
      "_build/wasm-gc/debug/build/examples/markdown_editor/web_wasm/web_wasm.wasm",
  },
];

const normalizeBaseUrl = url => url.replace(/\/+$/, "");

const checkHttp = async (path, label, httpChecks, httpFailures) => {
  const url = `${normalizeBaseUrl(baseUrl)}/${path}`;
  let response;
  try {
    response = await fetch(url, { method: "GET" });
  } catch (error) {
    httpFailures.push(`${label}: failed to fetch ${url}: ${error.message}`);
    return;
  }
  if (!response.ok) {
    httpFailures.push(`${label}: ${url} returned ${response.status} ${response.statusText}`);
    return;
  }
  const bytes = (await response.arrayBuffer()).byteLength;
  if (bytes === 0) {
    httpFailures.push(`${label}: ${url} returned an empty body`);
    return;
  }
  httpChecks.push({ label, path, url, bytes });
};

const collectHttpChecks = async () => {
  const httpChecks = [];
  const httpFailures = [];
  if (!baseUrl) {
    return { httpChecks, httpFailures };
  }
  if (typeof fetch !== "function") {
    return {
      httpChecks,
      httpFailures: ["Node fetch API is unavailable; cannot run --base-url checks"],
    };
  }
  for (const target of targets) {
    await checkHttp(
      `${target.packagePath}/index.html`,
      `${target.name} html`,
      httpChecks,
      httpFailures,
    );
    await checkHttp(target.wasmPath, `${target.name} wasm`, httpChecks, httpFailures);
  }
  await checkHttp("moui/render/webgpu_adapter/runtime.js", "web runtime.js", httpChecks, httpFailures);
  await checkHttp(
    "moui/backend/web/browser_runtime.js",
    "browser_runtime.js",
    httpChecks,
    httpFailures,
  );
  return { httpChecks, httpFailures };
};

const { httpChecks, httpFailures } = await collectHttpChecks();

const toolArgs = ["--root", rootDir];
if (baseUrl) {
  toolArgs.push("--base-url", baseUrl);
}
if (manifestPath && httpFailures.length === 0) {
  toolArgs.push("--manifest", manifestPath);
}
for (const check of httpChecks) {
  toolArgs.push(
    "--http-check",
    check.label,
    check.path,
    check.url,
    String(check.bytes),
  );
}

const toolResult = runMoonbitTool(toolPackage, toolArgs, {
  cwd: invocationRoot,
  exitOnFailure: false,
  failureStdoutToStderr: true,
  suppressSuccessStdout: httpFailures.length > 0,
});

let exitStatus = toolResult.status ?? 1;
for (const failure of httpFailures) {
  console.error(`web runtime handoff: ${failure}`);
}
if (httpFailures.length > 0 && exitStatus === 0) {
  exitStatus = 1;
}
if (exitStatus !== 0) {
  process.exit(exitStatus);
}

if (manifestPath) {
  runCommand(
    process.execPath,
    [join(repoRoot, "scripts/validate-web-runtime-handoff-manifest.mjs"), manifestPath],
    { cwd: invocationRoot },
  );
}
