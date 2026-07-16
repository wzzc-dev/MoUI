#!/usr/bin/env node

import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

const args = process.argv.slice(2);
if (!args.includes("--timestamp")) {
  args.push("--timestamp", new Date().toISOString());
}

runMoonbitTool("tools/moui/generate_feature_proof_report", args);
