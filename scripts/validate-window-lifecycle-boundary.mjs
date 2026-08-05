#!/usr/bin/env node

import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools/moui/validate_window_lifecycle_boundary", [
  "--repo-root",
  process.cwd(),
]);
