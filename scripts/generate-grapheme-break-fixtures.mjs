#!/usr/bin/env node

import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool(
  "tools/moui/generate_grapheme_break_fixtures",
  process.argv.slice(2),
);
