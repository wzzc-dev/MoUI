#!/usr/bin/env node

import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools/moui/validate_harness_invariants", [
  "--repo-root",
  process.cwd(),
  ...process.argv.slice(2),
]);
