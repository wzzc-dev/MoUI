// Compatibility re-export surface for older imports.
// Catalog validation and generation now live in tools/moui/sync_website_docs.
// Prefer: node scripts/sync-website-docs.mjs

export const README_SOURCES = new Map([
  ["docs/moui-readme.md", "README.md"],
  ["docs/moui-skia-readme.md", "moui_skia/README.mbt.md"],
]);

export const readWebsiteDocsCatalog = async () => {
  throw new Error(
    "website docs catalog validation moved to tools/moui/sync_website_docs; use node scripts/sync-website-docs.mjs",
  );
};

export const validateWebsiteDocsCatalog = async () => {
  throw new Error(
    "website docs catalog validation moved to tools/moui/sync_website_docs; use node scripts/sync-website-docs.mjs",
  );
};

export const generatedWebsiteCatalog = () => {
  throw new Error(
    "website docs catalog generation moved to tools/moui/sync_website_docs; use node scripts/sync-website-docs.mjs",
  );
};

export const websiteSitemap = () => {
  throw new Error(
    "website sitemap generation moved to tools/moui/sync_website_docs; use node scripts/sync-website-docs.mjs",
  );
};

export const websiteRobots = () => {
  throw new Error(
    "website robots generation moved to tools/moui/sync_website_docs; use node scripts/sync-website-docs.mjs",
  );
};
