#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const invocationRoot = process.cwd();
const toolPackage = "tools/moui/validate_api_surface";
const toolExe = join(
  repoRoot,
  "_build/native/debug/build/wzzc-dev/moui_tools/moui/validate_api_surface/validate_api_surface.exe",
);

const run = (command, args, options = {}) => {
  const result = spawnSync(command, args, {
    cwd: options.cwd ?? repoRoot,
    stdio: "inherit",
  });
  if (result.error) {
    console.error(result.error.message);
    process.exit(1);
  }
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
};

run("moon", [ "build", toolPackage, "--target", "native" ]);
run(toolExe, [ "--repo-root", invocationRoot ]);
