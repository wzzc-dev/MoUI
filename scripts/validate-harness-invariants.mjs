#!/usr/bin/env node

import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools/moui/validate_harness_invariants", [
  "--repo-root",
  process.cwd(),
  // Example entrypoint scans are opt-in (run the MoonBit tool directly) so
  // app iteration does not trip repo-level composition budgets.
  "--skip-examples",
  ...process.argv.slice(2),
]);
