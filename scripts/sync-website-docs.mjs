#!/usr/bin/env node

import { mkdir, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  generatedWebsiteCatalog,
  readWebsiteDocsCatalog,
  validateWebsiteDocsCatalog,
  websiteRobots,
  websiteSitemap,
} from "./lib/website-docs-catalog.mjs";

const defaultRepoRoot = join(fileURLToPath(new URL(".", import.meta.url)), "..");

const usage = () => {
  console.error(`Usage: node scripts/sync-website-docs.mjs [--check] [--out <dir>] [--root <dir>]

Validates website/docs-catalog.json, copies only cataloged public Markdown into
the website docs directory, removes stale Markdown, and generates catalog.json,
robots.txt, and sitemap.xml.`);
};

let check = false;
let repoRoot = defaultRepoRoot;
let outArg;
const args = process.argv.slice(2);
for (let index = 0; index < args.length; index += 1) {
  const arg = args[index];
  if (arg === "--check") {
    check = true;
  } else if (arg === "--out" || arg === "--root") {
    const value = args[index + 1];
    if (!value) {
      usage();
      process.exit(2);
    }
    if (arg === "--out") outArg = value;
    else repoRoot = resolve(value);
    index += 1;
  } else if (arg === "--help" || arg === "-h") {
    usage();
    process.exit(0);
  } else {
    console.error(`Unknown argument: ${arg}`);
    usage();
    process.exit(2);
  }
}

const outDir = outArg
  ? resolve(repoRoot, outArg)
  : join(repoRoot, "website", "web_wasm", "docs");
const siteOutDir = dirname(outDir);
const rel = path => relative(repoRoot, path);

let validated;
try {
  const catalog = await readWebsiteDocsCatalog(repoRoot);
  validated = await validateWebsiteDocsCatalog(repoRoot, catalog);
} catch (error) {
  console.error(`website docs catalog invalid: ${error.message}`);
  process.exit(1);
}

const generated = new Map();
for (const entry of validated.entries) {
  generated.set(join(outDir, entry.outputName), await readFile(join(repoRoot, entry.sourcePath), "utf8"));
}
generated.set(
  join(outDir, "catalog.json"),
  `${JSON.stringify(generatedWebsiteCatalog(validated.catalog), null, 2)}\n`,
);
generated.set(join(siteOutDir, "robots.txt"), websiteRobots(validated.catalog));
generated.set(join(siteOutDir, "sitemap.xml"), websiteSitemap(validated.catalog));

let stale = false;
if (!check) {
  await mkdir(outDir, { recursive: true });
}

for (const [target, content] of generated) {
  if (check) {
    let existing;
    try {
      existing = await readFile(target, "utf8");
    } catch {
      console.error(`website generated file missing: ${rel(target)}`);
      stale = true;
      continue;
    }
    if (existing !== content) {
      console.error(`website generated file stale: ${rel(target)}`);
      stale = true;
    }
  } else {
    await writeFile(target, content);
  }
}

let outputEntries = [];
try {
  outputEntries = await readdir(outDir, { withFileTypes: true });
} catch {
  if (check) stale = true;
}
const expectedNames = new Set([...generated.keys()].map(path => path.startsWith(`${outDir}/`) ? path.slice(outDir.length + 1) : ""));
for (const entry of outputEntries) {
  if (entry.isFile() && entry.name.endsWith(".md") && !expectedNames.has(entry.name)) {
    const target = join(outDir, entry.name);
    if (check) {
      console.error(`website docs stale output: ${rel(target)}`);
      stale = true;
    } else {
      await rm(target);
    }
  }
}

if (check && stale) {
  console.error("Run: node scripts/sync-website-docs.mjs");
  process.exit(1);
}

console.log(
  check
    ? `website docs catalog and generated files are in sync: ${rel(outDir)}`
    : `website docs synced (${validated.entries.length} public entries): ${rel(outDir)}`,
);
