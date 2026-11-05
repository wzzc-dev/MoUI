#!/usr/bin/env node

import {
  resolveToolPathArgs,
  runMoonbitTool,
} from "./lib/moonbit-tool-runner.mjs";

const args = resolveToolPathArgs(
  process.argv.slice(2),
  ["--repo-root"],
  { "--repo-root": "." },
);

runMoonbitTool("tools/moui/validate_portfolio_governance", args);
