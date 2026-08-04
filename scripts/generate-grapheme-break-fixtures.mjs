#!/usr/bin/env node

import {
  resolveToolPathArgs,
  runMoonbitTool,
} from "./lib/moonbit-tool-runner.mjs";

const defaultInput = "moui/core/unicode/testdata/grapheme_break_samples.txt";
const args = process.argv.slice(2);
const inputIndex = args.indexOf("--input");
const displayInput =
  inputIndex !== -1 && inputIndex + 1 < args.length
    ? args[inputIndex + 1]
    : defaultInput;
const toolArgs = resolveToolPathArgs(args, ["--input", "--output"], {
  "--input": defaultInput,
  "--output": "moui/core/unicode/grapheme_break_fixtures_wbtest.mbt",
});
if (!args.includes("--display-input")) {
  toolArgs.push("--display-input", displayInput);
}

runMoonbitTool(
  "tools/moui/generate_grapheme_break_fixtures",
  toolArgs,
);
