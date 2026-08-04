#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import {
  repoRoot,
  resolveToolPathArgs,
  runMoonbitTool,
} from "./lib/moonbit-tool-runner.mjs";

const usage = () => {
  console.error("Usage: node scripts/conformance-capture-scaffold.mjs --mode golden|benchmark");
};

let mode = "";
const args = process.argv.slice(2);
for (let index = 0; index < args.length; index += 1) {
  if (args[index] === "--mode") {
    mode = args[index + 1] ?? "";
    index += 1;
  } else if (args[index] === "--help" || args[index] === "-h") {
    usage();
    process.exit(0);
  } else {
    console.error(`Unknown argument: ${args[index]}`);
    usage();
    process.exit(2);
  }
}

if (!["golden", "benchmark"].includes(mode)) {
  usage();
  process.exit(2);
}

const run = argv => {
  console.log(`\n==> ${argv.join(" ")}`);
  const result = spawnSync(argv[0], argv.slice(1), {
    cwd: repoRoot,
    stdio: "inherit",
  });
  if (result.status !== 0 || result.error) {
    if (result.error) console.error(result.error.message);
    process.exit(result.status ?? 1);
  }
};

const manifestPath =
  mode === "golden"
    ? "artifacts/conformance/showcase-golden-capture.json"
    : "artifacts/conformance/showcase-benchmark-capture.json";

run(["moon", "build", "examples/showcase/web_wasm", "--target", "wasm-gc"]);
if (mode === "benchmark") {
  run(["moon", "build", "examples/markdown_editor/web_wasm", "--target", "wasm-gc"]);
  run([
    "node",
    "scripts/validate-web-runtime-handoff.mjs",
    "--manifest",
    "artifacts/conformance/web-runtime-handoff.json",
  ]);
}

runMoonbitTool(
  "tools/moui/conformance_capture_scaffold",
  resolveToolPathArgs(
    ["--mode", mode, "--output", manifestPath],
    ["--output"],
  ),
);
run([
  "node",
  "scripts/validate-conformance-capture-manifest.mjs",
  manifestPath,
  "--mode",
  mode,
]);

console.log(`\n${mode} capture scaffold complete.`);
