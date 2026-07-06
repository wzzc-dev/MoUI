#!/usr/bin/env node

import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools/moui/validate_api_surface", [
  "--repo-root",
  process.cwd(),
]);
