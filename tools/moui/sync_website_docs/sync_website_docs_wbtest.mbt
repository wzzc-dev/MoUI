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
  debug_inspect(
    readme_source_for("docs/moui-readme.md"),
    content="\"README.mbt.md\"",
  )
  debug_inspect(
    readme_source_for("docs/moui-skia-readme.md"),
    content="\"moui_skia/README.mbt.md\"",
  )
  debug_inspect(readme_source_for("docs/guide.md"), content="\"docs/guide.md\"")
}

///|
test "website README screenshot rewrite uses GitHub WebP assets only" {
  let content =
    #|<img src="resource/screenshots/showcase.png"/>
    #|<img src="resource/screenshots/markdown_editor.png"/>
    #|<img src="resource/screenshots/mo_workbench.png"/>
    #|<img src="resource/screenshots/excel.png"/>
    #|<img src="resource/screenshots/webview.png"/>
    #|<img src="resource/screenshots/ios-componentgallery.png"/>
    #|<img src="resource/screenshots/harmonyos-componentgallery.png"/>
    #|<img src="../../resource/screenshots/android-componentgallery.jpg"/>
  let rewritten = website_generated_markdown_content("moui-readme", content)
  for
    asset in [
      "showcase", "markdown_editor", "mo_workbench", "excel", "webview", "ios-componentgallery",
      "harmonyos-componentgallery", "android-componentgallery",
    ] {
    debug_inspect(
      rewritten.contains(website_readme_screenshot_url(asset)),
      content="true",
    )
  }
  debug_inspect(rewritten.contains("resource/screenshots/"), content="false")
  debug_inspect(
    website_generated_markdown_content("guide", content) == content,
    content="true",
  )
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
    locales: [],
  }
  let robots = website_robots(catalog)
  debug_inspect(robots.contains("User-agent: *"), content="true")
  debug_inspect(
    robots.contains("Sitemap: https://example.test/moui/sitemap.xml"),
    content="true",
  )
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
  match parse_catalog(text) {
    Ok(catalog) => {
      debug_inspect(catalog.entries.length(), content="1")
      debug_inspect(catalog.site_url.has_suffix("/"), content="true")
    }
    Err(message) => fail(message)
  }
  match
    parse_catalog(
      "{\"schemaVersion\":2,\"siteUrl\":\"https://x/\",\"groups\":[],\"entries\":[],\"excluded\":[]}",
    ) {
    Ok(_) => fail("expected schema error")
    Err(message) =>
      debug_inspect(message.contains("schemaVersion must be 1"), content="true")
  }
}

///|
test "parses localized catalog metadata and sitemap routes" {
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
    #|  "excluded": [],
    #|  "locales": {
    #|    "zh-Hans": {
    #|      "groups": [{"id": "guides", "title": "指南"}],
    #|      "entries": [{
    #|        "group": "guides",
    #|        "slug": "guide",
    #|        "title": "指南",
    #|        "summary": "指南摘要",
    #|        "keywords": ["指南"],
    #|        "localizedPath": "docs/zh-Hans/guide.md"
    #|      }]
    #|    }
    #|  }
    #|}
  match parse_catalog(text) {
    Ok(catalog) => {
      debug_inspect(catalog.locales.length(), content="1")
      debug_inspect(catalog.locales[0].tag, content="\"zh-Hans\"")
      debug_inspect(
        website_sitemap(catalog).contains("docs%2Fguide&amp;lang=zh-Hans"),
        content="true",
      )
    }
    Err(message) => fail(message)
  }
}

///|
test "rejects invalid locale tags" {
  debug_inspect(is_valid_locale_tag("zh-Hans"), content="true")
  debug_inspect(is_valid_locale_tag("zh_Hans"), content="false")
  debug_inspect(is_valid_locale_tag("-zh"), content="false")
}
