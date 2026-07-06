#!/usr/bin/env node

import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools/moui/validate_openseek_workbench", [
  "--repo-root",
  process.cwd(),
], { failureStdoutToStderr: true });
