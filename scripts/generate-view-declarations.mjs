#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve } from "node:path";
import { repoRoot, runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

const formatGenerated = (path) => {
  const result = spawnSync("moonfmt", ["-w", path], {
    cwd: repoRoot,
    stdio: "inherit",
  });
  if (result.status !== 0 || result.error) {
    process.exit(result.status ?? 1);
  }
};

const collectWrittenPaths = (output) =>
  output
    .split("\n")
    .filter((line) => line.startsWith("wrote "))
    .map((line) => line.slice("wrote ".length).trim());

const args = process.argv.slice(2);
if (args.includes("--check")) {
  const temporary = mkdtempSync(resolve(tmpdir(), "moui-view-declarations-"));
  const outputRoot = resolve(temporary, "generated");
  try {
    const result = runMoonbitTool("tools/moui/generate_view_declarations", [
      "--repo-root",
      repoRoot,
      "--output-root",
      outputRoot,
    ], { suppressSuccessStdout: true, exitOnFailure: false });
    if (result.status !== 0) {
      process.exit(result.status ?? 1);
    }
    const written = collectWrittenPaths(result.stdout ?? "");
    if (written.length === 0) {
      console.log("generate-view-declarations: no outputs reported");
      process.exitCode = 1;
    }
    for (const generated of written) {
      const relative = generated.slice(outputRoot.length + 1);
      formatGenerated(generated);
      const committed = resolve(repoRoot, relative);
      let actual;
      try {
        actual = readFileSync(committed, "utf8");
      } catch {
        console.log(`${relative}: missing generated declaration source`);
        process.exitCode = 1;
        continue;
      }
      const expected = readFileSync(generated, "utf8");
      if (actual !== expected) {
        console.log(
          `${relative}: generated ViewNode declaration source is out of date`,
        );
        console.log("  regenerate with: node scripts/generate-view-declarations.mjs");
        process.exitCode = 1;
      } else {
        console.log(`${relative}: ok`);
      }
    }
  } finally {
    rmSync(temporary, { force: true, recursive: true });
  }
} else {
  const outputRoot = repoRoot;
  const result = runMoonbitTool("tools/moui/generate_view_declarations", [
    "--repo-root",
    repoRoot,
    "--output-root",
    outputRoot,
  ], { exitOnFailure: false });
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
  for (const generated of collectWrittenPaths(result.stdout ?? "")) {
    formatGenerated(generated);
  }
}
