import { readdir, readFile } from "node:fs/promises";
import { basename, join, normalize, relative, sep } from "node:path";

const README_SOURCES = new Map([
  ["docs/moui-readme.md", "README.mbt.md"],
  ["docs/moui-skia-readme.md", "moui_skia/README.mbt.md"],
]);

const isPlainObject = value =>
  value !== null && typeof value === "object" && !Array.isArray(value);

const assertString = (value, label) => {
  if (typeof value !== "string" || value.trim() === "") {
    throw new Error(`${label} must be a non-empty string`);
  }
};

const validateRepoPath = (path, label) => {
  assertString(path, label);
  if (path.startsWith("/") || path.includes("\\")) {
    throw new Error(`${label} must be a repository-relative POSIX path: ${path}`);
  }
  const normalized = normalize(path).split(sep).join("/");
  if (normalized !== path || path.split("/").includes("..")) {
    throw new Error(`${label} contains directory traversal: ${path}`);
  }
};

const sourcePathForEntry = entry =>
  README_SOURCES.get(entry.path) ?? entry.path;

export const readWebsiteDocsCatalog = async (repoRoot, catalogPath = "website/docs-catalog.json") => {
  const path = join(repoRoot, catalogPath);
  let catalog;
  try {
    catalog = JSON.parse(await readFile(path, "utf8"));
  } catch (error) {
    throw new Error(`unable to read ${catalogPath}: ${error.message}`);
  }
  return catalog;
};

export const validateWebsiteDocsCatalog = async (repoRoot, catalog) => {
  if (!isPlainObject(catalog) || catalog.schemaVersion !== 1) {
    throw new Error("docs catalog schemaVersion must be 1");
  }
  assertString(catalog.siteUrl, "siteUrl");
  let siteUrl;
  try {
    siteUrl = new URL(catalog.siteUrl);
  } catch {
    throw new Error(`siteUrl must be an absolute URL: ${catalog.siteUrl}`);
  }
  if (!siteUrl.pathname.endsWith("/")) {
    throw new Error("siteUrl must end with '/'");
  }
  if (!Array.isArray(catalog.groups) || catalog.groups.length === 0) {
    throw new Error("docs catalog groups must be a non-empty array");
  }
  if (!Array.isArray(catalog.entries) || catalog.entries.length === 0) {
    throw new Error("docs catalog entries must be a non-empty array");
  }
  if (!Array.isArray(catalog.excluded)) {
    throw new Error("docs catalog excluded must be an array");
  }

  const groupIds = new Set();
  for (const [index, group] of catalog.groups.entries()) {
    if (!isPlainObject(group)) throw new Error(`groups[${index}] must be an object`);
    assertString(group.id, `groups[${index}].id`);
    assertString(group.title, `groups[${index}].title`);
    if (groupIds.has(group.id)) throw new Error(`duplicate group id: ${group.id}`);
    groupIds.add(group.id);
  }

  const slugs = new Set();
  const outputPaths = new Set();
  const classifiedSources = new Set();
  for (const [index, entry] of catalog.entries.entries()) {
    if (!isPlainObject(entry)) throw new Error(`entries[${index}] must be an object`);
    for (const field of ["group", "slug", "title", "path", "summary"]) {
      assertString(entry[field], `entries[${index}].${field}`);
    }
    if (!Array.isArray(entry.keywords) || entry.keywords.length === 0) {
      throw new Error(`entries[${index}].keywords must be a non-empty array`);
    }
    entry.keywords.forEach((keyword, keywordIndex) =>
      assertString(keyword, `entries[${index}].keywords[${keywordIndex}]`));
    if (!groupIds.has(entry.group)) throw new Error(`unknown group '${entry.group}' for slug '${entry.slug}'`);
    if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(entry.slug)) {
      throw new Error(`invalid slug: ${entry.slug}`);
    }
    if (slugs.has(entry.slug)) throw new Error(`duplicate slug: ${entry.slug}`);
    slugs.add(entry.slug);
    validateRepoPath(entry.path, `path for '${entry.slug}'`);
    if (!entry.path.startsWith("docs/") || basename(entry.path) === "catalog.json") {
      throw new Error(`published path must be a Markdown file below docs/: ${entry.path}`);
    }
    if (!entry.path.endsWith(".md")) throw new Error(`published path must end in .md: ${entry.path}`);
    if (outputPaths.has(entry.path)) throw new Error(`duplicate published path: ${entry.path}`);
    outputPaths.add(entry.path);
    const sourcePath = sourcePathForEntry(entry);
    validateRepoPath(sourcePath, `source path for '${entry.slug}'`);
    classifiedSources.add(sourcePath);
    try {
      await readFile(join(repoRoot, sourcePath), "utf8");
    } catch {
      throw new Error(`published source is missing: ${sourcePath}`);
    }
  }

  for (const [index, excluded] of catalog.excluded.entries()) {
    if (!isPlainObject(excluded)) throw new Error(`excluded[${index}] must be an object`);
    assertString(excluded.path, `excluded[${index}].path`);
    assertString(excluded.reason, `excluded[${index}].reason`);
    validateRepoPath(excluded.path, `excluded[${index}].path`);
    if (!excluded.path.startsWith("docs/") || !excluded.path.endsWith(".md")) {
      throw new Error(`excluded path must be a root docs Markdown path: ${excluded.path}`);
    }
    if (classifiedSources.has(excluded.path)) {
      throw new Error(`source is both published and excluded: ${excluded.path}`);
    }
    classifiedSources.add(excluded.path);
    try {
      await readFile(join(repoRoot, excluded.path), "utf8");
    } catch {
      throw new Error(`excluded source is missing: ${excluded.path}`);
    }
  }

  const rootDocs = (await readdir(join(repoRoot, "docs"), { withFileTypes: true }))
    .filter(entry => entry.isFile() && entry.name.endsWith(".md"))
    .map(entry => `docs/${entry.name}`)
    .sort();
  const expectedSources = [...rootDocs, ...README_SOURCES.values()].sort();
  const unclassified = expectedSources.filter(path => !classifiedSources.has(path));
  const unexpected = [...classifiedSources].filter(path => !expectedSources.includes(path)).sort();
  if (unclassified.length > 0) {
    throw new Error(`unclassified Markdown sources: ${unclassified.join(", ")}`);
  }
  if (unexpected.length > 0) {
    throw new Error(`catalog classifies non-public source paths: ${unexpected.join(", ")}`);
  }
  return {
    catalog,
    entries: catalog.entries.map(entry => ({
      ...entry,
      sourcePath: sourcePathForEntry(entry),
      outputName: basename(entry.path),
    })),
  };
};

export const generatedWebsiteCatalog = catalog => ({
  schemaVersion: catalog.schemaVersion,
  siteUrl: catalog.siteUrl,
  groups: catalog.groups,
  entries: catalog.entries,
});

export const websiteSitemap = catalog => {
  const urls = [catalog.siteUrl, new URL("?section=showcases", catalog.siteUrl).href];
  for (const entry of catalog.entries) {
    urls.push(new URL(`?section=${encodeURIComponent(`docs/${entry.slug}`)}`, catalog.siteUrl).href);
  }
  const escapeXml = value => value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
  return `<?xml version="1.0" encoding="UTF-8"?>\n` +
    `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n` +
    urls.map(url => `  <url><loc>${escapeXml(url)}</loc></url>`).join("\n") +
    `\n</urlset>\n`;
};

export const websiteRobots = catalog =>
  `User-agent: *\nAllow: /\nSitemap: ${new URL("sitemap.xml", catalog.siteUrl).href}\n`;

export const relativeToRepo = (repoRoot, path) => relative(repoRoot, path);
