#!/usr/bin/env node

import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools/moui/validate_source_file_policy", [
  "--repo-root",
  process.cwd(),
]);

