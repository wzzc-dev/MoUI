#!/usr/bin/env node

import {
  buildWebPackage,
  collectBundleSize,
  parseCommonArgs,
  printBundleTable,
} from "./web-bundle-tools.mjs";

const usage = `Usage: node scripts/web-bundle-size.mjs <web-package> [--json] [--no-build]

Builds a wasm-gc Web package in release+strip mode unless --no-build is set,
then reports raw/gzip/brotli sizes for the app wasm, MoUI Web runtime assets,
and the package-local assets/ directory.`;

try {
  const options = parseCommonArgs(process.argv.slice(2), usage);
  if (!options.noBuild) {
    buildWebPackage(options.packagePath);
  }
  const manifest = collectBundleSize(options.packagePath);
  if (options.json) {
    console.log(JSON.stringify(manifest, null, 2));
  } else {
    printBundleTable(manifest);
  }
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
