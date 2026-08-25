///|
fn escape_xml(value : String) -> String {
  let builder = StringBuilder()
  for ch in value {
    if ch == '&' {
      builder.write_string("&amp;")
    } else if ch == '<' {
      builder.write_string("&lt;")
    } else if ch == '>' {
      builder.write_string("&gt;")
    } else if ch == '"' {
      builder.write_string("&quot;")
    } else if ch == '\'' {
      builder.write_string("&apos;")
    } else {
      builder.write_char(ch)
    }
  }
  builder.to_string()
}

///|
fn encode_uri_component(value : String) -> String {
  // slug is already URL-safe (a-z0-9-); only encode '/' for docs/<slug>
  let builder = StringBuilder()
  for ch in value {
    if (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      ch.is_ascii_digit() ||
      ch == '-' ||
      ch == '_' ||
      ch == '.' ||
      ch == '~' {
      builder.write_char(ch)
    } else if ch == '/' {
      builder.write_string("%2F")
    } else {
      // fallback percent-encode code unit as UTF-8 single-byte for ASCII extras
      let code = ch.to_int()
      if code < 128 {
        builder.write_string("%")
        builder.write_string(to_hex2(code))
      } else {
        builder.write_char(ch)
      }
    }
  }
  builder.to_string()
}

///|
fn to_hex2(value : Int) -> String {
  let digits : Array[Char] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
  ]
  String::from_array([digits[value / 16], digits[value % 16]])
}

///|
fn join_url(base : String, relative : String) -> String {
  // base ends with /
  if relative.has_prefix("http://") || relative.has_prefix("https://") {
    relative
  } else if relative.has_prefix("?") {
    // strip trailing path segments? JS URL(base) with ? replaces search on path
    // new URL("?section=x", "https://host/path/") => https://host/path/?section=x
    base + relative
  } else {
    base + relative
  }
}

///|
fn generated_website_catalog_json(catalog : WebsiteDocsCatalog) -> String {
  let groups : Array[Json] = []
  for group in catalog.groups {
    let object : Map[String, Json] = Map([])
    object["id"] = Json::string(group.id)
    object["title"] = Json::string(group.title)
    groups.push(Json::object(object))
  }
  let entries : Array[Json] = []
  for entry in catalog.entries {
    let object : Map[String, Json] = Map([])
    object["group"] = Json::string(entry.group)
    object["slug"] = Json::string(entry.slug)
    object["title"] = Json::string(entry.title)
    object["path"] = Json::string(entry.path)
    object["summary"] = Json::string(entry.summary)
    object["keywords"] = Json::array(
      entry.keywords.map(keyword => Json::string(keyword)),
    )
    entries.push(Json::object(object))
  }
  let object : Map[String, Json] = Map([])
  object["schemaVersion"] = Json::number(
    catalog.schema_version.to_double(),
    repr=catalog.schema_version.to_string(),
  )
  object["siteUrl"] = Json::string(catalog.site_url)
  object["groups"] = Json::array(groups)
  object["entries"] = Json::array(entries)
  Json::object(object).stringify(indent=2) + "\n"
}

///|
fn generated_localized_website_catalog_json(
  catalog : WebsiteDocsCatalog,
  locale : ValidatedLocale,
) -> String {
  let groups : Array[Json] = []
  for group in locale.groups {
    let object : Map[String, Json] = Map([])
    object["id"] = Json::string(group.id)
    object["title"] = Json::string(group.title)
    groups.push(Json::object(object))
  }
  let entries : Array[Json] = []
  for entry in locale.entries {
    let object : Map[String, Json] = Map([])
    object["group"] = Json::string(entry.group)
    object["slug"] = Json::string(entry.slug)
    object["title"] = Json::string(entry.title)
    object["path"] = Json::string(
      "docs/" + locale.tag + "/" + entry.output_name,
    )
    object["summary"] = Json::string(entry.summary)
    object["keywords"] = Json::array(
      entry.keywords.map(keyword => Json::string(keyword)),
    )
    entries.push(Json::object(object))
  }
  let object : Map[String, Json] = Map([])
  object["schemaVersion"] = Json::number(
    catalog.schema_version.to_double(),
    repr=catalog.schema_version.to_string(),
  )
  object["siteUrl"] = Json::string(catalog.site_url)
  object["groups"] = Json::array(groups)
  object["entries"] = Json::array(entries)
  Json::object(object).stringify(indent=2) + "\n"
}

///|
fn website_robots(catalog : WebsiteDocsCatalog) -> String {
  let sitemap = join_url(catalog.site_url, "sitemap.xml")
  "User-agent: *\nAllow: /\nSitemap: " + sitemap + "\n"
}

///|
fn website_sitemap(catalog : WebsiteDocsCatalog) -> String {
  let urls : Array[String] = [
    catalog.site_url,
    join_url(catalog.site_url, "?section=showcases"),
  ]
  for entry in catalog.entries {
    let section = "docs/" + entry.slug
    urls.push(
      join_url(catalog.site_url, "?section=" + encode_uri_component(section)),
    )
  }
  for locale in catalog.locales {
    let locale_parameter = "&lang=" + encode_uri_component(locale.tag)
    urls.push(join_url(catalog.site_url, "?section=home" + locale_parameter))
    urls.push(
      join_url(catalog.site_url, "?section=showcases" + locale_parameter),
    )
    for entry in locale.entries {
      let section = "docs/" + entry.slug
      urls.push(
        join_url(
          catalog.site_url,
          "?section=" +
          encode_uri_component(section) +
          "&lang=" +
          encode_uri_component(locale.tag),
        ),
      )
    }
  }
  let lines : Array[String] = [
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>", "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">",
  ]
  for url in urls {
    lines.push("  <url><loc>" + escape_xml(url) + "</loc></url>")
  }
  lines.push("</urlset>")
  lines.push("")
  lines.join("\n")
}

///|
fn parent_dir(path : String) -> String {
  let normalized = path.replace(old="\\", new="/")
  let mut slash = -1
  for i = 0; i < normalized.length(); i = i + 1 {
    if normalized[i] == '/' {
      slash = i
    }
  }
  if slash <= 0 {
    if normalized.has_prefix("/") {
      "/"
    } else {
      "."
    }
  } else {
    normalized[:slash].to_owned()
  }
}

///|
fn create_dir_if_missing(path : String) -> Result[Unit, String] {
  if path == "" || @tools.directory_exists(path) {
    return Ok(())
  }
  @fs.create_dir(path) catch {
    _ => return Err("could not create directory: " + path)
  }
  Ok(())
}

///|
fn mkdir_p(path : String) -> Result[Unit, String] {
  if path == "" || @tools.directory_exists(path) {
    return Ok(())
  }
  let normalized = path.replace(old="\\", new="/")
  let current = Ref(if normalized.has_prefix("/") { "/" } else { "" })
  for part in normalized.split("/") {
    if part == "" {
      continue
    }
    let part = part.to_owned()
    if current.val == "" || current.val == "/" {
      current.val = current.val + part
    } else {
      current.val = current.val + "/" + part
    }
    match create_dir_if_missing(current.val) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(())
}

///|
fn write_text(path : String, text : String) -> Result[Unit, String] {
  match mkdir_p(parent_dir(path)) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  @tools.write_text_file(path, text, path)
}

///|
fn relative_to_repo(repo_root : String, path : String) -> String {
  let root = if repo_root.has_suffix("/") { repo_root } else { repo_root + "/" }
  if path.has_prefix(root) {
    path[root.length():].to_owned()
  } else if path == repo_root {
    "."
  } else {
    path
  }
}

///|
/// The website README is served from a generated copy. Keep the repository
/// README's original screenshots intact, but use the WebP assets published in
/// this repository when rendering that copy on the website.
fn website_readme_screenshot_url(asset : String) -> String {
  "https://raw.githubusercontent.com/wzzc-dev/MoUI/refs/heads/main/website/web_wasm/assets/screenshots/" +
  asset +
  ".webp"
}

///|
fn website_readme_markdown_content(content : String) -> String {
  let mut rewritten = content
  let screenshots = [
    ("showcase.png", "showcase"),
    ("markdown_editor.png", "markdown_editor"),
    ("mo_workbench.png", "mo_workbench"),
    ("excel.png", "excel"),
    ("webview.png", "webview"),
    ("ios-componentgallery.png", "ios-componentgallery"),
    ("harmonyos-componentgallery.png", "harmonyos-componentgallery"),
    ("android-componentgallery.jpg", "android-componentgallery"),
  ]
  for screenshot in screenshots {
    let (source_name, asset) = screenshot
    let source = "resource/screenshots/" + source_name
    let replacement = "src=\"" + website_readme_screenshot_url(asset) + "\""
    rewritten = rewritten.replace_all(
      old="src=\"" + source + "\"",
      new=replacement,
    )
    rewritten = rewritten.replace_all(
      old="src=\"../../" + source + "\"",
      new=replacement,
    )
  }
  rewritten
}

///|
fn website_generated_markdown_content(
  slug : String,
  content : String,
) -> String {
  if slug == "moui-readme" {
    website_readme_markdown_content(content)
  } else {
    content
  }
}

///|
struct GeneratedFile {
  path : String
  content : String
}

///|
fn build_generated_files(
  repo_root : String,
  out_dir : String,
  validated : ValidatedCatalog,
) -> Result[Array[GeneratedFile], String] {
  let files : Array[GeneratedFile] = []
  for entry in validated.entries {
    match
      @tools.read_required_text(
        @tools.resolve_path(repo_root, entry.source_path),
        entry.source_path,
      ) {
      Ok(content) =>
        files.push({
          path: @tools.join_path(out_dir, entry.output_name),
          content: website_generated_markdown_content(entry.slug, content),
        })
      Err(message) => return Err(message)
    }
  }
  files.push({
    path: @tools.join_path(out_dir, "catalog.json"),
    content: generated_website_catalog_json(validated.catalog),
  })
  for locale in validated.locales {
    let locale_out_dir = @tools.join_path(out_dir, locale.tag)
    for entry in locale.entries {
      match
        @tools.read_required_text(
          @tools.resolve_path(repo_root, entry.source_path),
          entry.source_path,
        ) {
        Ok(content) =>
          files.push({
            path: @tools.join_path(locale_out_dir, entry.output_name),
            content: website_generated_markdown_content(entry.slug, content),
          })
        Err(message) => return Err(message)
      }
    }
    files.push({
      path: @tools.join_path(locale_out_dir, "catalog.json"),
      content: generated_localized_website_catalog_json(
        validated.catalog,
        locale,
      ),
    })
  }
  let site_out_dir = parent_dir(out_dir)
  files.push({
    path: @tools.join_path(site_out_dir, "robots.txt"),
    content: website_robots(validated.catalog),
  })
  files.push({
    path: @tools.join_path(site_out_dir, "sitemap.xml"),
    content: website_sitemap(validated.catalog),
  })
  Ok(files)
}

///|
fn expected_md_names(
  files : Array[GeneratedFile],
  out_dir : String,
) -> Array[String] {
  let names : Array[String] = []
  let prefix = if out_dir.has_suffix("/") { out_dir } else { out_dir + "/" }
  for file in files {
    if file.path.has_prefix(prefix) {
      let name = file.path[prefix.length():].to_owned()
      if name.has_suffix(".md") {
        names.push(name)
      }
    }
  }
  names
}

///|
fn expected_locale_names(
  files : Array[GeneratedFile],
  out_dir : String,
) -> Array[String] {
  let names : Array[String] = []
  let prefix = if out_dir.has_suffix("/") { out_dir } else { out_dir + "/" }
  for file in files {
    if file.path.has_prefix(prefix) {
      let name = file.path[prefix.length():].to_owned()
      if !name.contains("/") &&
        (name.has_suffix(".md") || name == "catalog.json") {
        names.push(name)
      }
    }
  }
  names
}

///|
fn sync_locale_dir(
  repo_root : String,
  locale_dir : String,
  expected : Array[String],
  check : Bool,
  failures : Array[String],
) -> Unit {
  if @tools.directory_exists(locale_dir) {
    let names : Array[String] = @fs.read_dir(locale_dir) catch {
      _ => {
        if check {
          failures.push(
            "website docs locale output directory unreadable: " +
            relative_to_repo(repo_root, locale_dir),
          )
        }
        []
      }
    }
    for name in names {
      if (name.has_suffix(".md") || name == "catalog.json") &&
        !array_contains(expected, name) {
        let target = @tools.join_path(locale_dir, name)
        if check {
          failures.push(
            "website docs stale localized output: " +
            relative_to_repo(repo_root, target),
          )
        } else {
          @fs.remove_file(target) catch {
            _ =>
              failures.push(
                "could not remove stale localized output: " + target,
              )
          }
        }
      }
    }
  } else if check {
    failures.push(
      "website docs locale output directory missing: " +
      relative_to_repo(repo_root, locale_dir),
    )
  }
}

///|
fn sync_or_check(
  repo_root : String,
  out_dir : String,
  validated : ValidatedCatalog,
  check : Bool,
) -> Result[Unit, Array[String]] {
  let files = match build_generated_files(repo_root, out_dir, validated) {
    Ok(value) => value
    Err(message) => return Err([message])
  }
  let failures : Array[String] = []
  if !check {
    match mkdir_p(out_dir) {
      Ok(_) => ()
      Err(message) => return Err([message])
    }
  }
  for file in files {
    if check {
      match @tools.read_required_text(file.path, file.path) {
        Ok(existing) =>
          if existing != file.content {
            failures.push(
              "website generated file stale: " +
              relative_to_repo(repo_root, file.path),
            )
          }
        Err(_) =>
          failures.push(
            "website generated file missing: " +
            relative_to_repo(repo_root, file.path),
          )
      }
    } else {
      match write_text(file.path, file.content) {
        Ok(_) => ()
        Err(message) => failures.push(message)
      }
    }
  }
  let expected = expected_md_names(files, out_dir)
  let locale_names : Array[String] = []
  for locale in validated.locales {
    locale_names.push(locale.tag)
  }
  if @tools.directory_exists(out_dir) {
    let entries : Array[String] = @fs.read_dir(out_dir) catch {
      _ => {
        if check {
          failures.push(
            "website docs output directory unreadable: " +
            relative_to_repo(repo_root, out_dir),
          )
        }
        []
      }
    }
    for name in entries {
      if name.has_suffix(".md") && !array_contains(expected, name) {
        let target = @tools.join_path(out_dir, name)
        if check {
          failures.push(
            "website docs stale output: " + relative_to_repo(repo_root, target),
          )
        } else {
          @fs.remove_file(target) catch {
            _ => failures.push("could not remove stale output: " + target)
          }
        }
      }
      if !validated.locales.is_empty() &&
        is_valid_locale_tag(name) &&
        @tools.directory_exists(@tools.join_path(out_dir, name)) &&
        !array_contains(locale_names, name) {
        let target = @tools.join_path(out_dir, name)
        if check {
          failures.push(
            "website docs stale locale output: " +
            relative_to_repo(repo_root, target),
          )
        } else {
          let stale_names : Array[String] = @fs.read_dir(target) catch {
            _ => []
          }
          let mut removable = true
          for stale_name in stale_names {
            let stale_path = @tools.join_path(target, stale_name)
            if @tools.directory_exists(stale_path) {
              removable = false
            } else {
              @fs.remove_file(stale_path) catch {
                _ => removable = false
              }
            }
          }
          if removable {
            @fs.remove_dir(target) catch {
              _ =>
                failures.push("could not remove stale locale output: " + target)
            }
          } else {
            failures.push("could not remove stale locale output: " + target)
          }
        }
      }
    }
  } else if check {
    failures.push(
      "website docs output directory missing: " +
      relative_to_repo(repo_root, out_dir),
    )
  }
  for locale in validated.locales {
    let locale_dir = @tools.join_path(out_dir, locale.tag)
    let expected = expected_locale_names(files, locale_dir)
    sync_locale_dir(repo_root, locale_dir, expected, check, failures)
  }
  if failures.is_empty() {
    Ok(())
  } else {
    Err(failures)
  }
}
