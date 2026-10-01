#!/usr/bin/env node

import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools/moui/validate_dead_messages", [
  "--repo-root",
  process.cwd(),
  ...process.argv.slice(2),
]);
