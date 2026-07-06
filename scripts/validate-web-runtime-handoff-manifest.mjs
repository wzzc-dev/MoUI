#!/usr/bin/env node

import { resolve } from "node:path";
import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

const invocationRoot = process.cwd();
const toolPackage = "tools/moui/validate_web_runtime_handoff_manifest";

const originalArgs = process.argv.slice(2);
const toolArgs = [ ...originalArgs ];
if (
  toolArgs.length > 0 &&
  toolArgs[0] !== "-h" &&
  toolArgs[0] !== "--help" &&
  !toolArgs[0].startsWith("--")
) {
  const displayPath = toolArgs[0];
  toolArgs[0] = resolve(invocationRoot, displayPath);
  toolArgs.push("--display-path", displayPath);
}

runMoonbitTool(toolPackage, toolArgs, { failureStdoutToStderr: true });
