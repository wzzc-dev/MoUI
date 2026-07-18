#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve } from "node:path";
import { repoRoot, runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

const formatGeneratedCatalog = (path) => {
  const result = spawnSync("moonfmt", ["-w", path], {
    cwd: repoRoot,
    stdio: "inherit",
  });
  if (result.status !== 0 || result.error) {
    process.exit(result.status ?? 1);
  }
};

const args = process.argv.slice(2);
const checkIndex = args.indexOf("--check");

if (checkIndex === -1) {
  const outputIndex = args.indexOf("--out");
  runMoonbitTool("tools/moui/generate_i18n_catalogs", args);
  if (outputIndex !== -1 && outputIndex + 1 < args.length) {
    formatGeneratedCatalog(resolve(repoRoot, args[outputIndex + 1]));
  }
} else {
  const outputIndex = args.indexOf("--out");
  if (outputIndex === -1 || outputIndex + 1 >= args.length) {
    runMoonbitTool("tools/moui/generate_i18n_catalogs", args);
  } else {
    const output = args[outputIndex + 1];
    const temporary = mkdtempSync(resolve(tmpdir(), "moui-i18n-catalog-"));
    const generated = resolve(temporary, "catalog.mbt");
    const writeArgs = args.filter((_, index) => index !== checkIndex);
    writeArgs[outputIndex] = "--out";
    writeArgs[outputIndex + 1] = generated;
    try {
      runMoonbitTool("tools/moui/generate_i18n_catalogs", writeArgs, {
        suppressSuccessStdout: true,
      });
      formatGeneratedCatalog(generated);
      const expected = readFileSync(generated, "utf8");
      const actual = readFileSync(resolve(repoRoot, output), "utf8");
      if (actual !== expected) {
        console.log(`${output}: generated i18n catalog source is out of date`);
        process.exitCode = 1;
      } else {
        console.log(`${output}: ok`);
      }
    } finally {
      rmSync(temporary, { force: true, recursive: true });
    }
  }
}
