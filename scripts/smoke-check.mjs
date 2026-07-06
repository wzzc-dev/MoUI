#!/usr/bin/env node

import { repoRoot, runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools/moui/validate_smoke_catalog", [
  "--repo-root",
  repoRoot,
  ...process.argv.slice(2),
]);
