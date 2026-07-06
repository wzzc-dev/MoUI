#!/usr/bin/env node

import { resolve } from "node:path";
import { runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

const invocationRoot = process.cwd();
const rootArg = process.argv[2] ?? ".";
const validationRoot = resolve(invocationRoot, rootArg);
const toolPackage = "tools/moui/validate_skia_entrypoints";

runMoonbitTool(toolPackage, [ validationRoot ], { failureStdoutToStderr: true });
