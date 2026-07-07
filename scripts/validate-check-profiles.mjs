#!/usr/bin/env node

import { repoRoot, runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools/moui/validate_check_profiles", [
  "--repo-root",
  repoRoot,
]);
