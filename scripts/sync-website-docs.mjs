#!/usr/bin/env node
import { readdir, mkdir, readFile, writeFile } from "node:fs/promises";
import { join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = join(fileURLToPath(new URL(".", import.meta.url)), "..");

const usage = () => {
  console.error(`Usage: node scripts/sync-website-docs.mjs [--check] [--out <dir>]

Copies the Markdown files served by website/web_wasm into the website-local
docs/ directory for local preview. The Website app fetches these files at
runtime with same-origin paths such as docs/architecture.md; GitHub Pages
staging copies the same Markdown sources directly into dist/pages/docs/.`);
};

let check = false;
let outDir = join(repoRoot, "website", "web_wasm", "docs");

const args = process.argv.slice(2);
for (let i = 0; i < args.length; i += 1) {
  const arg = args[i];
  if (arg === "--check") {
    check = true;
  } else if (arg === "--out") {
    const value = args[i + 1];
    if (!value) {
      usage();
      process.exit(2);
    }
    outDir = resolve(repoRoot, value);
    i += 1;
  } else if (arg === "--help" || arg === "-h") {
    usage();
    process.exit(0);
  } else {
    console.error(`Unknown argument: ${arg}`);
    usage();
    process.exit(2);
  }
}

const docsDir = join(repoRoot, "docs");
const docNames = (await readdir(docsDir))
  .filter(name => name.endsWith(".md"))
  .sort();

const sources = [
  ...docNames.map(name => ({
    from: join(docsDir, name),
    to: name,
  })),
  {
    from: join(repoRoot, "README.mbt.md"),
    to: "moui-readme.md",
  },
  {
    from: join(repoRoot, "moui_skia", "README.mbt.md"),
    to: "moui-skia-readme.md",
  },
];

const rel = path => relative(repoRoot, path);
let stale = false;

if (!check) {
  await mkdir(outDir, { recursive: true });
}

for (const source of sources) {
  const text = await readFile(source.from, "utf8");
  const target = join(outDir, source.to);
  if (check) {
    let existing = "";
    try {
      existing = await readFile(target, "utf8");
    } catch {
      console.error(`website docs missing: ${rel(target)}`);
      stale = true;
      continue;
    }
    if (existing !== text) {
      console.error(`website docs stale: ${rel(target)} differs from ${rel(source.from)}`);
      stale = true;
    }
  } else {
    await writeFile(target, text);
  }
}

if (check && stale) {
  console.error("Run: node scripts/sync-website-docs.mjs");
  process.exit(1);
}

console.log(
  check
    ? `website docs are in sync: ${rel(outDir)}`
    : `website docs synced: ${rel(outDir)}`,
);
