#!/usr/bin/env node

import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools/moui/validate_runtime_state_render_ownership", [
  "--repo-root",
  process.cwd(),
]);
