#!/usr/bin/env node

import { repoRoot, runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools/moui/validate_doc_budget", [
  "--repo-root",
  repoRoot,
]);
