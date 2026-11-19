// White-box tests for tools/moui/sync_website_docs decision logic.
// They pin source-path mapping, slug/path/locale validation, XML and URI
// escaping, URL joining, CLI parsing, and output-directory resolution.

///|
test "readme_source_for maps generated pages back to repository sources" {
  assert_eq(readme_source_for("docs/moui-readme.md"), "README.md")
  assert_eq(
    readme_source_for("docs/moui-skia-readme.md"),
    "moui_skia/README.mbt.md",
  )
  assert_eq(readme_source_for("docs/guide.md"), "docs/guide.md")
  assert_eq(basename("docs/guide.md"), "guide.md")
  assert_eq(basename("docs\\guide.md"), "guide.md")
  assert_eq(basename("guide.md"), "guide.md")
}

///|
test "is_valid_slug requires lowercase alphanumeric hyphenated segments" {
  assert_true(is_valid_slug("guide"))
  assert_true(is_valid_slug("a1"))
  assert_true(is_valid_slug("a-b-c"))
  assert_false(is_valid_slug(""))
  assert_false(is_valid_slug("-a"))
  assert_false(is_valid_slug("a-"))
  assert_false(is_valid_slug("Guide"))
  assert_false(is_valid_slug("a_b"))
  assert_false(is_valid_slug("a--b"))
}

///|
test "validate_repo_path rejects absolute, Windows, and traversal paths" {
  match validate_repo_path("docs/guide.md", "entries[0].path") {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match validate_repo_path("", "entries[0].path") {
    Err(message) =>
      assert_eq(message, "entries[0].path must be a non-empty string")
    Ok(_) => fail("empty path must be rejected")
  }
  match validate_repo_path("/abs.md", "entries[0].path") {
    Err(message) =>
      assert_eq(
        message, "entries[0].path must be a repository-relative POSIX path: /abs.md",
      )
    Ok(_) => fail("absolute path must be rejected")
  }
  match validate_repo_path("a\\b.md", "entries[0].path") {
    Err(message) =>
      assert_eq(
        message, "entries[0].path must be a repository-relative POSIX path: a\\b.md",
      )
    Ok(_) => fail("Windows separator must be rejected")
  }
  match validate_repo_path("a/../b.md", "entries[0].path") {
    Err(message) =>
      assert_eq(
        message, "entries[0].path contains directory traversal: a/../b.md",
      )
    Ok(_) => fail("traversal must be rejected")
  }
  match validate_repo_path("a//b.md", "entries[0].path") {
    Err(message) =>
      assert_eq(
        message, "entries[0].path contains directory traversal: a//b.md",
      )
    Ok(_) => fail("empty path segment must be rejected")
  }
  match validate_repo_path("./a.md", "entries[0].path") {
    Err(message) =>
      assert_eq(message, "entries[0].path contains directory traversal: ./a.md")
    Ok(_) => fail("dot path segment must be rejected")
  }
}

///|
test "is_valid_locale_tag enforces 2-8 character subtags" {
  assert_true(is_valid_locale_tag("en"))
  assert_true(is_valid_locale_tag("zh-Hans"))
  assert_true(is_valid_locale_tag("en-US"))
  assert_true(is_valid_locale_tag("zh-Hans-419"))
  assert_false(is_valid_locale_tag(""))
  assert_false(is_valid_locale_tag("e"))
  assert_false(is_valid_locale_tag("en--US"))
  assert_false(is_valid_locale_tag("en-verylongpart"))
  assert_false(is_valid_locale_tag("en_US"))
}

///|
test "escape_xml and encode_uri_component produce stable output" {
  assert_eq(escape_xml("a&<b>\"c'"), "a&amp;&lt;b&gt;&quot;c&apos;")
  assert_eq(escape_xml("plain"), "plain")
  assert_eq(encode_uri_component("docs/My File.md"), "docs%2FMy%20File.md")
  assert_eq(encode_uri_component("a-b_c.d~e"), "a-b_c.d~e")
  assert_eq(to_hex2(32), "20")
  assert_eq(to_hex2(255), "FF")
}

///|
test "join_url keeps absolute URLs and joins relative routes" {
  assert_eq(
    join_url("https://example.test/docs/", "a.md"),
    "https://example.test/docs/a.md",
  )
  assert_eq(
    join_url("https://example.test/docs/", "https://other.test/x"),
    "https://other.test/x",
  )
  assert_eq(
    join_url("https://example.test/p/", "?q=1"),
    "https://example.test/p/?q=1",
  )
  assert_eq(
    website_readme_screenshot_url("showcase"),
    "https://raw.githubusercontent.com/wzzc-dev/MoUI/refs/heads/main/website/web_wasm/assets/screenshots/showcase.webp",
  )
}

///|
test "parent_dir and relative_to_repo agree on separators and roots" {
  assert_eq(parent_dir("a/b/c.json"), "a/b")
  assert_eq(parent_dir("x.json"), ".")
  assert_eq(parent_dir("/x.json"), "/")
  assert_eq(parent_dir("a\\b.json"), "a")
  assert_eq(relative_to_repo("/repo", "/repo/docs/a.md"), "docs/a.md")
  assert_eq(relative_to_repo("/repo/", "/repo/docs/a.md"), "docs/a.md")
  assert_eq(relative_to_repo("/repo", "/repo"), ".")
  assert_eq(relative_to_repo("/repo", "/other/a.md"), "/other/a.md")
}

///|
test "parse_cli and resolve_out_dir agree on output location" {
  match parse_cli(["--check", "--root", "/repo", "--out", "site"]) {
    Ok(options) => {
      assert_true(options.check)
      assert_eq(options.repo_root, "/repo")
      assert_eq(options.out_dir, Some("site"))
      assert_false(options.help)
    }
    Err(message) => fail(message)
  }
  match parse_cli([]) {
    Ok(options) => {
      assert_false(options.check)
      assert_eq(options.out_dir, None)
      assert_false(options.help)
    }
    Err(message) => fail(message)
  }
  match parse_cli(["--out"]) {
    Err(message) => assert_eq(message, "missing value for --out")
    Ok(_) => fail("missing --out value must be rejected")
  }
  match parse_cli(["--wat"]) {
    Err(message) => assert_eq(message, "Unknown argument: --wat")
    Ok(_) => fail("unknown option must be rejected")
  }
  assert_eq(resolve_out_dir("/repo", Some("site")), "/repo/site")
  assert_eq(resolve_out_dir("/repo", None), "/repo/website/web_wasm/docs")
  assert_eq(resolve_out_dir("/repo", Some("/abs")), "/abs")
}

///|
test "parse_keywords rejects empty and non-string keyword lists" {
  match parse_keywords(Map([]), "entries[0]") {
    Err(message) =>
      assert_eq(message, "entries[0].keywords must be a non-empty array")
    Ok(_) => fail("missing keywords must be rejected")
  }
  let empty : Map[String, Json] = Map([])
  empty["keywords"] = Json::array([])
  match parse_keywords(empty, "entries[0]") {
    Err(message) =>
      assert_eq(message, "entries[0].keywords must be a non-empty array")
    Ok(_) => fail("empty keywords must be rejected")
  }
  let mixed : Map[String, Json] = Map([])
  mixed["keywords"] = Json::array([
    Json::string("moonbit"),
    Json::number(1.0, repr="1"),
  ])
  match parse_keywords(mixed, "entries[0]") {
    Err(message) =>
      assert_eq(message, "entries[0].keywords[1] must be a non-empty string")
    Ok(_) => fail("non-string keyword must be rejected")
  }
  let valid : Map[String, Json] = Map([])
  valid["keywords"] = Json::array([Json::string("moonbit"), Json::string("ui")])
  match parse_keywords(valid, "entries[0]") {
    Ok(keywords) => assert_eq(keywords, ["moonbit", "ui"])
    Err(message) => fail(message)
  }
}
