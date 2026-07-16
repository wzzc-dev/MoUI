#!/usr/bin/env node

import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools/moui/check_mobile_app_config", [
  "--repo-root",
  process.cwd(),
  ...process.argv.slice(2),
]);
