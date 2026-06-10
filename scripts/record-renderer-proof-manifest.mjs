#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const invocationRoot = process.cwd();
const toolPackage = "tools/moui/record_renderer_proof_manifest";
const toolExe = join(
  repoRoot,
  "_build/native/debug/build/wzzc-dev/moui_tools/moui/record_renderer_proof_manifest/record_renderer_proof_manifest.exe",
);

const usage = () => {
  console.error(
    "Usage: node scripts/record-renderer-proof-manifest.mjs --backend <wgpu-native|skia-native|webgpu-wasm> --platform <macos|windows|linux|web> --artifact-name <name> --output <path> --log <path> [--log <path> ...] [--require-passed]",
  );
};

const args = process.argv.slice(2);
let output = "";
let requirePassed = false;

for (let index = 0; index < args.length; index += 1) {
  const arg = args[index];
  if (
    arg === "--backend" ||
    arg === "--platform" ||
    arg === "--artifact-name" ||
    arg === "--log"
  ) {
    if (index + 1 >= args.length) {
      console.error(`Missing value for ${arg}`);
      usage();
      process.exit(2);
    }
    index += 1;
  } else if (arg === "--output") {
    if (index + 1 >= args.length) {
      console.error("Missing value for --output");
      usage();
      process.exit(2);
    }
    output = args[index + 1];
    index += 1;
  } else if (arg === "--require-passed") {
    requirePassed = true;
  } else if (arg === "--help" || arg === "-h") {
    usage();
    process.exit(0);
  } else {
    console.error(`Unknown argument: ${arg}`);
    usage();
    process.exit(2);
  }
}

const run = (command, commandArgs, options = {}) => {
  const result = spawnSync(command, commandArgs, {
    cwd: options.cwd ?? repoRoot,
    encoding: "utf8",
  });
  if (
    result.stdout &&
    !(options.failureStdoutToStderr && result.status !== 0)
  ) {
    process.stdout.write(result.stdout);
  }
  if (result.stdout && options.failureStdoutToStderr && result.status !== 0) {
    process.stderr.write(result.stdout);
  }
  if (result.stderr) {
    process.stderr.write(result.stderr);
  }
  if (result.error) {
    console.error(result.error.message);
    process.exit(1);
  }
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
};

run("moon", ["build", toolPackage, "--target", "native"]);
run(toolExe, args, {
  cwd: invocationRoot,
  failureStdoutToStderr: true,
});

if (output) {
  const validationArgs = [
    join(repoRoot, "scripts/validate-renderer-proof-manifest.mjs"),
    output,
  ];
  if (requirePassed) validationArgs.push("--require-passed");
  run(process.execPath, validationArgs, { cwd: invocationRoot });
}
