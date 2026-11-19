#!/usr/bin/env node

import { repoRoot, runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools/moui/validate_tool_test_coverage", [
  "--repo-root",
  repoRoot,
]);
