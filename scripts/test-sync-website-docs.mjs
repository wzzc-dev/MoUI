#!/usr/bin/env node

import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { spawnSync } from "node:child_process";

const fixture = () => {
  const root = mkdtempSync(join(tmpdir(), "moui-website-docs-"));
  mkdirSync(join(root, "scripts/lib"), { recursive: true });
  mkdirSync(join(root, "website"), { recursive: true });
  mkdirSync(join(root, "docs"), { recursive: true });
  mkdirSync(join(root, "moui_skia"), { recursive: true });
  cpSync("scripts/check-website-docs.mjs", join(root, "scripts/check-website-docs.mjs"));
  cpSync("scripts/sync-website-docs.mjs", join(root, "scripts/sync-website-docs.mjs"));
  cpSync("scripts/lib/website-docs-catalog.mjs", join(root, "scripts/lib/website-docs-catalog.mjs"));
  writeFileSync(join(root, "docs/guide.md"), "# Guide\n");
  writeFileSync(join(root, "docs/private.md"), "# Private\n");
  writeFileSync(join(root, "README.mbt.md"), "# README\n");
  writeFileSync(join(root, "moui_skia/README.mbt.md"), "# Skia\n");
  const catalog = {
    schemaVersion: 1,
    siteUrl: "https://example.test/moui/",
    groups: [{ id: "guides", title: "Guides" }],
    entries: [
      { group: "guides", slug: "guide", title: "Guide", path: "docs/guide.md", summary: "Guide summary", keywords: ["guide"] },
      { group: "guides", slug: "moui-readme", title: "README", path: "docs/moui-readme.md", summary: "README summary", keywords: ["readme"] },
      { group: "guides", slug: "moui-skia-readme", title: "Skia", path: "docs/moui-skia-readme.md", summary: "Skia summary", keywords: ["skia"] },
    ],
    excluded: [{ path: "docs/private.md", reason: "Private fixture" }],
  };
  writeFileSync(join(root, "website/docs-catalog.json"), `${JSON.stringify(catalog, null, 2)}\n`);
  return { root, catalog };
};

const run = (root, ...args) =>
  spawnSync(process.execPath, [join(root, "scripts/sync-website-docs.mjs"), "--root", root, ...args], { encoding: "utf8" });

const runTemporaryCheck = root =>
  spawnSync(process.execPath, [join(root, "scripts/check-website-docs.mjs"), "--root", root], { encoding: "utf8" });

const expectPass = (label, result) => {
  if (result.status !== 0) {
    console.error(`${label}: expected pass\n${result.stderr}`);
    process.exit(1);
  }
};

const expectFail = (label, result, message) => {
  if (result.status === 0 || !result.stderr.includes(message)) {
    console.error(`${label}: expected failure containing '${message}'\n${result.stderr}`);
    process.exit(1);
  }
};

const updateCatalog = (root, mutate) => {
  const path = join(root, "website/docs-catalog.json");
  const value = JSON.parse(readFileSync(path, "utf8"));
  mutate(value);
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
};

{
  const { root } = fixture();
  expectPass("temporary output check", runTemporaryCheck(root));
  if (existsSync(join(root, "website/web_wasm/docs"))) {
    console.error("temporary output check should not write into the source checkout");
    process.exit(1);
  }
}

{
  const { root } = fixture();
  expectPass("valid catalog", run(root));
  expectPass("generated output check", run(root, "--check"));
  writeFileSync(join(root, "website/web_wasm/docs/stale.md"), "stale");
  expectFail("stale output check", run(root, "--check"), "stale output");
  expectPass("stale output cleanup", run(root));
}
{
  const { root } = fixture();
  updateCatalog(root, catalog => catalog.entries.push({ ...catalog.entries[0], path: "docs/duplicate.md" }));
  expectFail("duplicate slug", run(root), "duplicate slug");
}
{
  const { root } = fixture();
  updateCatalog(root, catalog => { catalog.entries[0].path = "docs/missing.md"; });
  expectFail("missing source", run(root), "published source is missing");
}
{
  const { root } = fixture();
  writeFileSync(join(root, "docs/new.md"), "# New\n");
  expectFail("unclassified source", run(root), "unclassified Markdown sources");
}
{
  const { root } = fixture();
  updateCatalog(root, catalog => { catalog.entries[0].path = "docs/../README.mbt.md"; });
  expectFail("directory traversal", run(root), "directory traversal");
}

console.log("website docs catalog tests: ok");
