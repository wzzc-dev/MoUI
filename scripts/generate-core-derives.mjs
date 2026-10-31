#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve } from "node:path";
import { repoRoot, runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

const generatedRelative = "moui/core/derives.generated.mbt";

const formatGenerated = (path) => {
  const result = spawnSync("moonfmt", ["-w", path], {
    cwd: repoRoot,
    stdio: "inherit",
  });
  if (result.status !== 0 || result.error) {
    process.exit(result.status ?? 1);
  }
};

const args = process.argv.slice(2);
if (args.includes("--check")) {
  const temporary = mkdtempSync(resolve(tmpdir(), "moui-core-derives-"));
  const generated = resolve(temporary, "derives.generated.mbt");
  try {
    runMoonbitTool("tools/moui/generate_core_derives", [
      "--repo-root",
      repoRoot,
      "--output",
      generated,
    ], { suppressSuccessStdout: true });
    formatGenerated(generated);
    const expected = readFileSync(generated, "utf8");
    const actual = readFileSync(resolve(repoRoot, generatedRelative), "utf8");
    if (actual !== expected) {
      console.log(
        `${generatedRelative}: generated core derives source is out of date`,
      );
      console.log(
        "  regenerate with: node scripts/generate-core-derives.mjs",
      );
      process.exitCode = 1;
    } else {
      console.log(`${generatedRelative}: ok`);
    }
  } finally {
    rmSync(temporary, { force: true, recursive: true });
  }
} else {
  runMoonbitTool("tools/moui/generate_core_derives", [
    "--repo-root",
    repoRoot,
  ]);
  formatGenerated(resolve(repoRoot, generatedRelative));
}
