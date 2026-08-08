#!/usr/bin/env node

import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools/moui/validate_release_module_closures", [
  "--repo-root",
  process.cwd(),
]);
