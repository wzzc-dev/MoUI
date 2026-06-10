#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const invocationRoot = process.cwd();
const toolPackage = "tools/moui/validate_web_runtime_presentation_manifest";
const toolExe = join(
  repoRoot,
  "_build/native/debug/build/wzzc-dev/moui_tools/moui/validate_web_runtime_presentation_manifest/validate_web_runtime_presentation_manifest.exe",
);

const originalArgs = process.argv.slice(2);
const toolArgs = [ ...originalArgs ];
if (
  toolArgs.length > 0 &&
  toolArgs[0] !== "-h" &&
  toolArgs[0] !== "--help" &&
  !toolArgs[0].startsWith("--")
) {
  const displayPath = toolArgs[0];
  toolArgs[0] = resolve(invocationRoot, displayPath);
  toolArgs.push("--display-path", displayPath);
}

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
run(toolExe, toolArgs, { failureStdoutToStderr: true });
