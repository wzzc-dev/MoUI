#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const invocationRoot = process.cwd();
const rootArg = process.argv[2] ?? ".";
const validationRoot = resolve(invocationRoot, rootArg);
const toolPackage = "tools/moui/validate_skia_entrypoints";
const toolExe = join(
  repoRoot,
  "_build/native/debug/build/wzzc-dev/moui_tools/moui/validate_skia_entrypoints/validate_skia_entrypoints.exe",
);

const run = (command, args, options = {}) => {
  const result = spawnSync(command, args, {
    cwd: repoRoot,
    encoding: "utf8",
  });
  if (result.stdout && !(options.failureStdoutToStderr && result.status !== 0)) {
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

run("moon", [ "build", toolPackage, "--target", "native" ]);
run(toolExe, [ validationRoot ], { failureStdoutToStderr: true });
