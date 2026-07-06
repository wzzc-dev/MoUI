#!/usr/bin/env node

import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools/moui/validate_window_dependency", [
  "--repo-root",
  process.cwd(),
], { failureStdoutToStderr: true });
