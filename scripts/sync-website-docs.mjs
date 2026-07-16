#!/usr/bin/env node

import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool("tools/moui/sync_website_docs", process.argv.slice(2));
