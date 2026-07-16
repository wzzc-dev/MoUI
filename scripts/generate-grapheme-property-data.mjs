#!/usr/bin/env node

import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool(
  "tools/moui/generate_grapheme_property_data",
  process.argv.slice(2),
);
