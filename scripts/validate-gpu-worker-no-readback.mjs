#!/usr/bin/env node

import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools/moui/validate_gpu_worker_no_readback", [
  "--repo-root",
  process.cwd(),
  ...process.argv.slice(2),
]);
