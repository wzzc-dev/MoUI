#!/usr/bin/env node

import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools/moui/validate_platform_matrix", [
  "--repo-root",
  process.cwd(),
]);
