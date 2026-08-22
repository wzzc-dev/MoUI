#!/usr/bin/env node

import { resolve } from "node:path";
import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

const invocationRoot = process.cwd();
const args = process.argv.slice(2);
const resolved = [];
for (let index = 0; index < args.length; index += 1) {
  const arg = args[index];
  resolved.push(arg);
  if (arg === "--catalog" || arg === "--results" || arg === "--repo-root") {
    const value = args[index + 1];
    if (value) {
      resolved.push(resolve(invocationRoot, value));
      index += 1;
    }
  }
}
if (!resolved.includes("--repo-root")) {
  resolved.push("--repo-root", invocationRoot);
}

runMoonbitTool("tools/moui/validate_performance_budgets", resolved, {
  failureStdoutToStderr: true,
});
