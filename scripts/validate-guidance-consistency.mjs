#!/usr/bin/env node

import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools/moui/validate_guidance_consistency", [
  "--repo-root",
  process.cwd(),
]);
