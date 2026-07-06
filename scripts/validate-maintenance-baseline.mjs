#!/usr/bin/env node

import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools/moui/validate_maintenance_baseline", [
  "--repo-root",
  process.cwd(),
]);
