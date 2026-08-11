#!/usr/bin/env node

import { basename, join } from "node:path";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import {
  buildWebPackage,
  cleanOutputDir,
  collectBundleSize,
  collectAssetFiles,
  copyDirectory,
  copyFileEnsuringDir,
  packageRoot,
  parseCommonArgs,
  rewriteIndexForPackage,
  rewriteRuntimeForPackage,
  runtimeAssetPaths,
  usageAndExit,
  wasmArtifactPath,
  writeCompressedSiblings,
} from "./web-bundle-tools.mjs";
import { repoRoot } from "./lib/moonbit-tool-runner.mjs";

const usage = `Usage: node scripts/package-web-app.mjs <web-package> --out <dir> [--no-build]

Builds a wasm-gc Web package in release+strip mode unless --no-build is set,
then writes index.html, wasm, MoUI Web runtime JS, package-local assets/, gzip
and brotli siblings, and bundle-size.json into the output directory.`;

try {
  const options = parseCommonArgs(process.argv.slice(2), usage);
  if (!options.outDir) {
    usageAndExit("Missing required --out <dir>.", usage);
  }
  if (!options.noBuild) {
    buildWebPackage(options.packagePath);
  }

  const sourceRoot = packageRoot(options.packagePath);
  const indexPath = join(sourceRoot, "index.html");
  if (!existsSync(indexPath)) {
    throw new Error(`Web package index.html not found: ${indexPath}`);
  }

  const outDir = cleanOutputDir(options.outDir);
  const copiedFiles = [];
  const copyTracked = (source, destinationName) => {
    const destination = join(outDir, destinationName);
    copyFileEnsuringDir(source, destination);
    copiedFiles.push(destination);
  };

  const wasmPath = wasmArtifactPath(options.packagePath);
  const wasmFileName = basename(wasmPath);
  const packagedIndexPath = join(outDir, "index.html");
  writeFileSync(
    packagedIndexPath,
    rewriteIndexForPackage(readFileSync(indexPath, "utf8"), wasmFileName),
  );
  copiedFiles.push(packagedIndexPath);
  copyTracked(wasmPath, wasmFileName);
  const fallbackIndexPath = join(sourceRoot, "fallback.js");
  if (existsSync(fallbackIndexPath)) {
    copyTracked(fallbackIndexPath, "fallback.js");
  }
  for (const assetPath of runtimeAssetPaths) {
    if (basename(assetPath) === "runtime.js") {
      const destination = join(outDir, "runtime.js");
      writeFileSync(
        destination,
        rewriteRuntimeForPackage(readFileSync(join(repoRoot, assetPath), "utf8")),
      );
      copiedFiles.push(destination);
    } else {
      copyTracked(join(repoRoot, assetPath), basename(assetPath));
    }
  }
  const packagedAssetsRoot = join(outDir, "assets");
  copyDirectory(join(sourceRoot, "assets"), packagedAssetsRoot);
  const packagedDocsRoot = join(outDir, "docs");
  copyDirectory(join(sourceRoot, "docs"), packagedDocsRoot);

  for (const filePath of copiedFiles) {
    writeCompressedSiblings(filePath);
  }
  for (const asset of collectAssetFiles(packagedAssetsRoot)) {
    writeCompressedSiblings(asset.fullPath);
  }
  for (const asset of collectAssetFiles(packagedDocsRoot)) {
    writeCompressedSiblings(asset.fullPath);
  }
  const manifest = collectBundleSize(options.packagePath);
  writeFileSync(join(outDir, "bundle-size.json"), `${JSON.stringify(manifest, null, 2)}\n`);
  console.log(`Wrote ${outDir}`);
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
