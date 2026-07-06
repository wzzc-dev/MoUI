#!/usr/bin/env node

import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools/moui/validate_renderer_provider_manifests", [
  "--repo-root",
  process.cwd(),
]);
