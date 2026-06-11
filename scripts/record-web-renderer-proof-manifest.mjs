#!/usr/bin/env node

import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const invocationRoot = process.cwd();
const toolPackage = "tools/moui/record_web_renderer_proof_manifest";
const toolExe = join(
  repoRoot,
  "_build/native/debug/build/wzzc-dev/moui_tools/moui/record_web_renderer_proof_manifest/record_web_renderer_proof_manifest.exe",
);

const usage = () => {
  console.error(
    "Usage: node scripts/record-web-renderer-proof-manifest.mjs --web-presentation-manifest <web-runtime-presentation.json> --output <renderer-proof.json> [--require-passed]",
  );
};

const args = process.argv.slice(2);
if (args.includes("--help") || args.includes("-h")) {
  usage();
  process.exit(0);
}

let output = "artifacts/conformance/renderer-proof/webgpu-wasm-web.json";
let requirePassed = false;
for (let index = 0; index < args.length; index += 1) {
  const arg = args[index];
  if (arg === "--web-presentation-manifest") {
    index += 1;
  } else if (arg === "--output") {
    output = args[++index] ?? "";
  } else if (arg === "--require-passed") {
    requirePassed = true;
  } else {
    usage();
    process.exit(2);
  }
}

const run = (command, commandArgs, options = {}) => {
  const result = spawnSync(command, commandArgs, {
    cwd: options.cwd ?? repoRoot,
    encoding: "utf8",
  });
  if (result.stdout) {
    (options.stdoutToStderr ? process.stderr : process.stdout).write(result.stdout);
  }
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) {
    console.error(result.error.message);
    process.exit(1);
  }
  if (result.status !== 0) process.exit(result.status ?? 1);
};

run("moon", ["build", toolPackage, "--target", "native"]);
run(toolExe, args, { cwd: invocationRoot, stdoutToStderr: true });

const logPath = join(dirname(output), "webgpu-wasm-web.log");
const recorderArgs = [
  join(repoRoot, "scripts/record-renderer-proof-manifest.mjs"),
  "--backend",
  "webgpu-wasm",
  "--platform",
  "web",
  "--artifact-name",
  process.env.WEB_RUNTIME_PRESENTATION_ARTIFACT_NAME || "moui-web-runtime-presentation",
  "--output",
  output,
  "--log",
  logPath,
];
if (requirePassed) recorderArgs.push("--require-passed");

run(process.execPath, recorderArgs, { cwd: invocationRoot });
