#!/usr/bin/env node

import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools/moui/validate_platform_adapter_duplication", [
  "--repo-root",
  process.cwd(),
  "--today",
  new Date().toISOString().slice(0, 10),
]);
