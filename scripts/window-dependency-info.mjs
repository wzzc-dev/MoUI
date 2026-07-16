#!/usr/bin/env node

import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools/moui/window_dependency_info", [
  "--repo-root",
  process.cwd(),
  ...process.argv.slice(2),
]);
