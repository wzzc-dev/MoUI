#!/usr/bin/env node

import {
  resolveToolPathArgs,
  runMoonbitTool,
} from "./lib/moonbit-tool-runner.mjs";

runMoonbitTool(
  "tools/moui/generate_grapheme_property_data",
  resolveToolPathArgs(
    process.argv.slice(2),
    [
      "--grapheme-property",
      "--emoji-data",
      "--derived-core-properties",
      "--output",
    ],
    { "--output": "moui/core/unicode/grapheme_data.mbt" },
  ),
);
