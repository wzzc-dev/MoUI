#!/usr/bin/env node

import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools/moui/validate_renderer_capability_consistency", [
  "--repo-root",
  process.cwd(),
  ...process.argv.slice(2),
]);
