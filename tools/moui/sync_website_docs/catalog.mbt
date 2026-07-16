///|
struct CatalogGroup {
  id : String
  title : String
}

///|
struct CatalogEntry {
  group : String
  slug : String
  title : String
  path : String
  summary : String
  keywords : Array[String]
}

///|
struct CatalogExcluded {
  path : String
  reason : String
}

///|
struct WebsiteDocsCatalog {
  schema_version : Int
  site_url : String
  groups : Array[CatalogGroup]
  entries : Array[CatalogEntry]
  excluded : Array[CatalogExcluded]
}

///|
struct ValidatedEntry {
  group : String
  slug : String
  title : String
  path : String
  summary : String
  keywords : Array[String]
  source_path : String
  output_name : String
}

///|
struct ValidatedCatalog {
  catalog : WebsiteDocsCatalog
  entries : Array[ValidatedEntry]
}

///|
fn readme_source_for(path : String) -> String {
  if path == "docs/moui-readme.md" {
    "README.mbt.md"
  } else if path == "docs/moui-skia-readme.md" {
    "moui_skia/README.mbt.md"
  } else {
    path
  }
}

///|
fn basename(path : String) -> String {
  let mut slash = -1
  for i = 0; i < path.length(); i = i + 1 {
    if path[i] == '/' || path[i] == '\\' {
      slash = i
    }
  }
  if slash < 0 {
    path
  } else {
    path[slash + 1 :].to_owned()
  }
}

///|
fn is_valid_slug(slug : String) -> Bool {
  if slug == "" {
    return false
  }
  let mut expect_alnum = true
  for ch in slug {
    if expect_alnum {
      if !((ch >= 'a' && ch <= 'z') || ch.is_ascii_digit()) {
        return false
      }
      expect_alnum = false
    } else if ch == '-' {
      expect_alnum = true
    } else if (ch >= 'a' && ch <= 'z') || ch.is_ascii_digit() {
      ()
    } else {
      return false
    }
  }
  !expect_alnum
}

///|
fn validate_repo_path(path : String, label : String) -> Result[Unit, String] {
  if path == "" {
    return Err(label + " must be a non-empty string")
  }
  if path.has_prefix("/") || path.contains("\\") {
    return Err(
      label + " must be a repository-relative POSIX path: " + path,
    )
  }
  if path.contains("/../") ||
    path.has_prefix("../") ||
    path.has_suffix("/..") ||
    path == ".." {
    return Err(label + " contains directory traversal: " + path)
  }
  // reject normalize-changing paths like a//b
  let parts = path.split("/").map(part => part.to_owned())
  for part in parts {
    if part == "" || part == "." || part == ".." {
      return Err(label + " contains directory traversal: " + path)
    }
  }
  Ok(())
}

///|
fn json_string(value : Json?, label : String) -> Result[String, String] {
  match value {
    Some(Json::String(text)) if text.trim().to_owned() != "" => Ok(text)
    _ => Err(label + " must be a non-empty string")
  }
}

///|
fn json_object(value : Json?, label : String) -> Result[Map[String, Json], String] {
  match value {
    Some(Json::Object(fields)) => Ok(fields)
    _ => Err(label + " must be an object")
  }
}

///|
fn json_array(value : Json?, label : String) -> Result[Array[Json], String] {
  match value {
    Some(Json::Array(values)) => Ok(values)
    _ => Err(label + " must be an array")
  }
}

///|
fn json_int(value : Json?, label : String) -> Result[Int, String] {
  match value {
    Some(Json::Number(number, repr=_)) => Ok(number.to_int())
    _ => Err(label + " must be a number")
  }
}

///|
fn parse_catalog(text : String) -> Result[WebsiteDocsCatalog, String] {
  let root_json = @json.parse(text) catch {
    _ => return Err("unable to parse docs catalog JSON")
  }
  let root = match root_json {
    Json::Object(fields) => fields
    _ => return Err("docs catalog must be an object")
  }
  let schema_version = match json_int(root.get("schemaVersion"), "schemaVersion") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if schema_version != 1 {
    return Err("docs catalog schemaVersion must be 1")
  }
  let site_url = match json_string(root.get("siteUrl"), "siteUrl") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if !(site_url.has_prefix("http://") || site_url.has_prefix("https://")) {
    return Err("siteUrl must be an absolute URL: " + site_url)
  }
  if !site_url.has_suffix("/") {
    return Err("siteUrl must end with '/'")
  }
  let groups_json = match json_array(root.get("groups"), "docs catalog groups") {
    Ok(values) => values
    Err(_) => return Err("docs catalog groups must be a non-empty array")
  }
  if groups_json.is_empty() {
    return Err("docs catalog groups must be a non-empty array")
  }
  let entries_json = match json_array(root.get("entries"), "docs catalog entries") {
    Ok(values) => values
    Err(_) => return Err("docs catalog entries must be a non-empty array")
  }
  if entries_json.is_empty() {
    return Err("docs catalog entries must be a non-empty array")
  }
  let excluded_json = match json_array(root.get("excluded"), "docs catalog excluded") {
    Ok(values) => values
    Err(_) => return Err("docs catalog excluded must be an array")
  }
  let groups : Array[CatalogGroup] = []
  for index, group_value in groups_json {
    let fields = match json_object(Some(group_value), "groups[" + index.to_string() + "]") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let id = match json_string(fields.get("id"), "groups[" + index.to_string() + "].id") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let title = match json_string(
      fields.get("title"),
      "groups[" + index.to_string() + "].title",
    ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    groups.push({ id, title })
  }
  let entries : Array[CatalogEntry] = []
  for index, entry_value in entries_json {
    let fields = match json_object(Some(entry_value), "entries[" + index.to_string() + "]") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let group = match json_string(
      fields.get("group"),
      "entries[" + index.to_string() + "].group",
    ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let slug = match json_string(
      fields.get("slug"),
      "entries[" + index.to_string() + "].slug",
    ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let title = match json_string(
      fields.get("title"),
      "entries[" + index.to_string() + "].title",
    ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let path = match json_string(
      fields.get("path"),
      "entries[" + index.to_string() + "].path",
    ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let summary = match json_string(
      fields.get("summary"),
      "entries[" + index.to_string() + "].summary",
    ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let keywords_json = match json_array(
      fields.get("keywords"),
      "entries[" + index.to_string() + "].keywords",
    ) {
      Ok(values) => values
      Err(_) =>
        return Err(
          "entries[" + index.to_string() + "].keywords must be a non-empty array",
        )
    }
    if keywords_json.is_empty() {
      return Err(
        "entries[" + index.to_string() + "].keywords must be a non-empty array",
      )
    }
    let keywords : Array[String] = []
    for keyword_index, keyword_value in keywords_json {
      match keyword_value {
        Json::String(text) if text.trim().to_owned() != "" => keywords.push(text)
        _ =>
          return Err(
            "entries[" +
            index.to_string() +
            "].keywords[" +
            keyword_index.to_string() +
            "] must be a non-empty string",
          )
      }
    }
    entries.push({ group, slug, title, path, summary, keywords })
  }
  let excluded : Array[CatalogExcluded] = []
  for index, excluded_value in excluded_json {
    let fields = match json_object(
      Some(excluded_value),
      "excluded[" + index.to_string() + "]",
    ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let path = match json_string(
      fields.get("path"),
      "excluded[" + index.to_string() + "].path",
    ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let reason = match json_string(
      fields.get("reason"),
      "excluded[" + index.to_string() + "].reason",
    ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    excluded.push({ path, reason })
  }
  Ok(
    {
      schema_version,
      site_url,
      groups,
      entries,
      excluded,
    },
  )
}

///|
fn array_contains(values : Array[String], needle : String) -> Bool {
  for value in values {
    if value == needle {
      return true
    }
  }
  false
}

///|
fn validate_catalog_against_repo(
  repo_root : String,
  catalog : WebsiteDocsCatalog,
) -> Result[ValidatedCatalog, String] {
  let group_ids : Array[String] = []
  for group in catalog.groups {
    if array_contains(group_ids, group.id) {
      return Err("duplicate group id: " + group.id)
    }
    group_ids.push(group.id)
  }
  let slugs : Array[String] = []
  let output_paths : Array[String] = []
  let classified_sources : Array[String] = []
  let validated_entries : Array[ValidatedEntry] = []
  for entry in catalog.entries {
    if !array_contains(group_ids, entry.group) {
      return Err(
        "unknown group '" + entry.group + "' for slug '" + entry.slug + "'",
      )
    }
    if !is_valid_slug(entry.slug) {
      return Err("invalid slug: " + entry.slug)
    }
    if array_contains(slugs, entry.slug) {
      return Err("duplicate slug: " + entry.slug)
    }
    slugs.push(entry.slug)
    match validate_repo_path(entry.path, "path for '" + entry.slug + "'") {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    if !entry.path.has_prefix("docs/") || basename(entry.path) == "catalog.json" {
      return Err(
        "published path must be a Markdown file below docs/: " + entry.path,
      )
    }
    if !entry.path.has_suffix(".md") {
      return Err("published path must end in .md: " + entry.path)
    }
    if array_contains(output_paths, entry.path) {
      return Err("duplicate published path: " + entry.path)
    }
    output_paths.push(entry.path)
    let source_path = readme_source_for(entry.path)
    match validate_repo_path(source_path, "source path for '" + entry.slug + "'") {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    classified_sources.push(source_path)
    if !@tools.file_exists(@tools.resolve_path(repo_root, source_path)) {
      return Err("published source is missing: " + source_path)
    }
    validated_entries.push(
      {
        group: entry.group,
        slug: entry.slug,
        title: entry.title,
        path: entry.path,
        summary: entry.summary,
        keywords: entry.keywords,
        source_path,
        output_name: basename(entry.path),
      },
    )
  }
  for excluded in catalog.excluded {
    match validate_repo_path(excluded.path, "excluded path") {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    if !excluded.path.has_prefix("docs/") || !excluded.path.has_suffix(".md") {
      return Err(
        "excluded path must be a root docs Markdown path: " + excluded.path,
      )
    }
    if array_contains(classified_sources, excluded.path) {
      return Err("source is both published and excluded: " + excluded.path)
    }
    classified_sources.push(excluded.path)
    if !@tools.file_exists(@tools.resolve_path(repo_root, excluded.path)) {
      return Err("excluded source is missing: " + excluded.path)
    }
  }
  let docs_dir = @tools.resolve_path(repo_root, "docs")
  let root_docs : Array[String] = []
  if @tools.directory_exists(docs_dir) {
    let names : Array[String] = @fs.read_dir(docs_dir) catch {
      _ => return Err("docs directory could not be read")
    }
    names.sort_by((left, right) => left.lexical_compare(right))
    for name in names {
      if name.has_suffix(".md") &&
        @tools.file_exists(@tools.resolve_path(repo_root, "docs/" + name)) {
        root_docs.push("docs/" + name)
      }
    }
  }
  let expected_sources = root_docs.copy()
  expected_sources.push("README.mbt.md")
  expected_sources.push("moui_skia/README.mbt.md")
  expected_sources.sort_by((left, right) => left.lexical_compare(right))
  let unclassified : Array[String] = []
  for path in expected_sources {
    if !array_contains(classified_sources, path) {
      unclassified.push(path)
    }
  }
  if !unclassified.is_empty() {
    return Err(
      "unclassified Markdown sources: " + unclassified.join(", "),
    )
  }
  let unexpected : Array[String] = []
  for path in classified_sources {
    if !array_contains(expected_sources, path) {
      unexpected.push(path)
    }
  }
  unexpected.sort_by((left, right) => left.lexical_compare(right))
  if !unexpected.is_empty() {
    return Err(
      "catalog classifies non-public source paths: " + unexpected.join(", "),
    )
  }
  let mut reason_chars = 0
  for item in catalog.excluded {
    reason_chars = reason_chars + item.reason.length()
  }
  // keep validated entry metadata available for future SEO emitters
  for item in validated_entries {
    ignore(item.group)
    ignore(item.slug)
    ignore(item.title)
    ignore(item.path)
    ignore(item.summary)
    ignore(item.keywords)
  }
  ignore(reason_chars)
  Ok({ catalog, entries: validated_entries })
}
