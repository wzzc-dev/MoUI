#!/usr/bin/env node

import { repoRoot, runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

const args = process.argv.slice(2);
const toolArgs = args.includes("--root") ? args : ["--root", repoRoot, ...args];

runMoonbitTool("tools/moui/sync_website_docs", toolArgs);
