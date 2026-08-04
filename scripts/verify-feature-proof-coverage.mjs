#!/usr/bin/env node

import {
  resolveToolPathArgs,
  runMoonbitTool,
} from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool(
  "tools/moui/verify_feature_proof_coverage",
  resolveToolPathArgs(process.argv.slice(2), ["--report"]),
);
