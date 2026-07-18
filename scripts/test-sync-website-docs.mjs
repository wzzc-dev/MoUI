#!/usr/bin/env node

import { existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const repoRoot = process.cwd();

const fixture = ({ locales = false } = {}) => {
  const root = mkdtempSync(join(tmpdir(), "moui-website-docs-"));
  mkdirSync(join(root, "website"), { recursive: true });
  mkdirSync(join(root, "docs"), { recursive: true });
  mkdirSync(join(root, "moui_skia"), { recursive: true });
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
  if (locales) {
    mkdirSync(join(root, "docs/zh-Hans"), { recursive: true });
    writeFileSync(join(root, "docs/zh-Hans/guide.md"), "# 指南\n");
    writeFileSync(join(root, "docs/zh-Hans/moui-readme.md"), "# 中文 README\n");
    writeFileSync(join(root, "docs/zh-Hans/moui-skia-readme.md"), "# 中文 Skia\n");
    catalog.locales = {
      "zh-Hans": {
        groups: [{ id: "guides", title: "指南" }],
        entries: [
          { group: "guides", slug: "guide", title: "指南", summary: "指南摘要", keywords: ["指南"] },
          { group: "guides", slug: "moui-readme", title: "README", summary: "README 摘要", keywords: ["README"], localizedPath: "docs/zh-Hans/moui-readme.md" },
          { group: "guides", slug: "moui-skia-readme", title: "Skia", summary: "Skia 摘要", keywords: ["Skia"] },
        ],
      },
    };
  }
  writeFileSync(join(root, "website/docs-catalog.json"), `${JSON.stringify(catalog, null, 2)}\n`);
  return { root, catalog };
};

// Use the repo-checked scripts + MoonBit tool (not copies of scripts alone).
const run = (root, ...args) =>
  spawnSync(
    process.execPath,
    [join(repoRoot, "scripts/sync-website-docs.mjs"), "--root", root, ...args],
    { encoding: "utf8", cwd: repoRoot },
  );

const runTemporaryCheck = root =>
  spawnSync(
    process.execPath,
    [join(repoRoot, "scripts/check-website-docs.mjs"), "--root", root],
    { encoding: "utf8", cwd: repoRoot },
  );

const combined = result => `${result.stdout || ""}${result.stderr || ""}`;

const expectPass = (label, result) => {
  if (result.status !== 0) {
    console.error(`${label}: expected pass\n${combined(result)}`);
    process.exit(1);
  }
};

const expectFail = (label, result, message) => {
  const text = combined(result);
  if (result.status === 0 || !text.includes(message)) {
    console.error(`${label}: expected failure containing '${message}'\n${text}`);
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
  updateCatalog(root, catalog => {
    catalog.entries[0].path = "docs/missing.md";
  });
  expectFail("missing source", run(root), "published source is missing");
}
{
  const { root } = fixture();
  writeFileSync(join(root, "docs/new.md"), "# New\n");
  expectFail("unclassified source", run(root), "unclassified Markdown sources");
}
{
  const { root } = fixture();
  updateCatalog(root, catalog => {
    catalog.entries[0].path = "docs/../README.mbt.md";
  });
  expectFail("directory traversal", run(root), "directory traversal");
}

{
  const { root } = fixture({ locales: true });
  expectPass("localized catalog", run(root));
  expectPass("localized generated output check", run(root, "--check"));
  const localeOut = join(root, "website/web_wasm/docs/zh-Hans");
  if (readFileSync(join(localeOut, "guide.md"), "utf8") !== "# 指南\n") {
    console.error("localized Markdown was not copied");
    process.exit(1);
  }
  const localizedCatalog = JSON.parse(readFileSync(join(localeOut, "catalog.json"), "utf8"));
  if (localizedCatalog.entries[0].path !== "docs/zh-Hans/guide.md" || localizedCatalog.groups[0].title !== "指南") {
    console.error("localized catalog metadata was not generated");
    process.exit(1);
  }
  const sitemap = readFileSync(join(root, "website/web_wasm/sitemap.xml"), "utf8");
  if (!sitemap.includes("?section=docs%2Fguide&amp;lang=zh-Hans")) {
    console.error("localized sitemap route was not generated");
    process.exit(1);
  }
}
{
  const { root } = fixture({ locales: true });
  updateCatalog(root, catalog => {
    catalog.locales["zh-Hans"].entries.pop();
  });
  expectFail("localized entry parity", run(root), "localized entries missing stable slug");
}
{
  const { root } = fixture({ locales: true });
  updateCatalog(root, catalog => {
    catalog.locales["zh-Hans"].groups[0].id = "other";
  });
  expectFail("localized group parity", run(root), "localized groups missing stable id");
}
{
  const { root } = fixture({ locales: true });
  updateCatalog(root, catalog => {
    catalog.locales["zh-Hans"].entries[0].localizedPath = "docs/zh-Hans/missing.md";
  });
  expectFail("missing localized source", run(root), "localized source is missing");
}

console.log("website docs catalog tests: ok");
