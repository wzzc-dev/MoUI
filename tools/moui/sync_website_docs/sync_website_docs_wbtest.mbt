///|
test "validates slugs and repo paths" {
  debug_inspect(is_valid_slug("getting-started"), content="true")
  debug_inspect(is_valid_slug("Bad_Slug"), content="false")
  debug_inspect(is_valid_slug("-leading"), content="false")
  match validate_repo_path("docs/guide.md", "path") {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match validate_repo_path("docs/../README.mbt.md", "path") {
    Ok(_) => fail("expected traversal error")
    Err(message) =>
      debug_inspect(message.contains("directory traversal"), content="true")
  }
}

///|
test "readme source mapping" {
  debug_inspect(readme_source_for("docs/moui-readme.md"), content="\"README.mbt.md\"")
  debug_inspect(
    readme_source_for("docs/moui-skia-readme.md"),
    content="\"moui_skia/README.mbt.md\"",
  )
  debug_inspect(readme_source_for("docs/guide.md"), content="\"docs/guide.md\"")
}

///|
test "generates robots and sitemap from catalog" {
  let catalog = {
    schema_version: 1,
    site_url: "https://example.test/moui/",
    groups: [{ id: "guides", title: "Guides" }],
    entries: [
      {
        group: "guides",
        slug: "guide",
        title: "Guide",
        path: "docs/guide.md",
        summary: "Guide summary",
        keywords: ["guide"],
      },
    ],
    excluded: [],
  }
  let robots = website_robots(catalog)
  debug_inspect(robots.contains("User-agent: *"), content="true")
  debug_inspect(robots.contains("Sitemap: https://example.test/moui/sitemap.xml"), content="true")
  let sitemap = website_sitemap(catalog)
  debug_inspect(sitemap.contains("?section=showcases"), content="true")
  debug_inspect(sitemap.contains("docs%2Fguide"), content="true")
  debug_inspect(sitemap.contains("<urlset"), content="true")
}

///|
test "parses catalog json and rejects bad schema" {
  let text =
    #|{
    #|  "schemaVersion": 1,
    #|  "siteUrl": "https://example.test/moui/",
    #|  "groups": [{"id": "guides", "title": "Guides"}],
    #|  "entries": [{
    #|    "group": "guides",
    #|    "slug": "guide",
    #|    "title": "Guide",
    #|    "path": "docs/guide.md",
    #|    "summary": "Guide summary",
    #|    "keywords": ["guide"]
    #|  }],
    #|  "excluded": []
    #|}
    #|
  match parse_catalog(text) {
    Ok(catalog) => {
      debug_inspect(catalog.entries.length(), content="1")
      debug_inspect(catalog.site_url.has_suffix("/"), content="true")
    }
    Err(message) => fail(message)
  }
  match parse_catalog("{\"schemaVersion\":2,\"siteUrl\":\"https://x/\",\"groups\":[],\"entries\":[],\"excluded\":[]}") {
    Ok(_) => fail("expected schema error")
    Err(message) =>
      debug_inspect(message.contains("schemaVersion must be 1"), content="true")
  }
}
