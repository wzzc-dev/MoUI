#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const generator = fileURLToPath(new URL("./generate-playground-assets.mjs", import.meta.url));
const result = spawnSync(process.execPath, [generator, ...process.argv.slice(2)], {
  cwd: process.cwd(),
  stdio: "inherit",
});
process.exit(result.status ?? 1);
