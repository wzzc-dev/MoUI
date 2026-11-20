#!/usr/bin/env node

// The tool imports `moui_metal_renderer`, so its native executable links the Metal
// `.mm` stubs; it builds on macOS only. Hooks outside macOS print a skip line.
import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools_product/moui/validate_renderer_capability_consistency", [
  "--repo-root",
  process.cwd(),
  ...process.argv.slice(2),
], { host: "darwin" });
