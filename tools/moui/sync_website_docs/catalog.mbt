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
struct CatalogLocalizedEntry {
  group : String
  slug : String
  title : String
  summary : String
  keywords : Array[String]
  localized_path : String?
}

///|
struct CatalogLocale {
  tag : String
  groups : Array[CatalogGroup]
  entries : Array[CatalogLocalizedEntry]
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
  locales : Array[CatalogLocale]
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
struct ValidatedLocaleEntry {
  group : String
  slug : String
  title : String
  summary : String
  keywords : Array[String]
  source_path : String
  output_name : String
}

///|
struct ValidatedLocale {
  tag : String
  groups : Array[CatalogGroup]
  entries : Array[ValidatedLocaleEntry]
}

///|
struct ValidatedCatalog {
  catalog : WebsiteDocsCatalog
  entries : Array[ValidatedEntry]
  locales : Array[ValidatedLocale]
}

///|
fn readme_source_for(path : String) -> String {
  if path == "docs/moui-readme.md" {
    "README.md"
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
    path[slash + 1:].to_owned()
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
    return Err(label + " must be a repository-relative POSIX path: " + path)
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
fn json_object(
  value : Json?,
  label : String,
) -> Result[Map[String, Json], String] {
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
fn parse_keywords(
  fields : Map[String, Json],
  label : String,
) -> Result[Array[String], String] {
  let keywords_json = match
    json_array(fields.get("keywords"), label + ".keywords") {
    Ok(values) => values
    Err(_) => return Err(label + ".keywords must be a non-empty array")
  }
  if keywords_json.is_empty() {
    return Err(label + ".keywords must be a non-empty array")
  }
  let keywords : Array[String] = []
  for keyword_index, keyword_value in keywords_json {
    match keyword_value {
      Json::String(text) if text.trim().to_owned() != "" => keywords.push(text)
      _ =>
        return Err(
          label +
          ".keywords[" +
          keyword_index.to_string() +
          "] must be a non-empty string",
        )
    }
  }
  Ok(keywords)
}

///|
fn parse_groups(
  values : Array[Json],
  label : String,
) -> Result[Array[CatalogGroup], String] {
  if values.is_empty() {
    return Err(label + " must be a non-empty array")
  }
  let groups : Array[CatalogGroup] = []
  for index, group_value in values {
    let item_label = label + "[" + index.to_string() + "]"
    let fields = match json_object(Some(group_value), item_label) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let id = match json_string(fields.get("id"), item_label + ".id") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let title = match json_string(fields.get("title"), item_label + ".title") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    groups.push({ id, title })
  }
  Ok(groups)
}

///|
fn parse_entries(
  values : Array[Json],
  label : String,
) -> Result[Array[CatalogEntry], String] {
  if values.is_empty() {
    return Err(label + " must be a non-empty array")
  }
  let entries : Array[CatalogEntry] = []
  for index, entry_value in values {
    let item_label = label + "[" + index.to_string() + "]"
    let fields = match json_object(Some(entry_value), item_label) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let group = match json_string(fields.get("group"), item_label + ".group") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let slug = match json_string(fields.get("slug"), item_label + ".slug") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let title = match json_string(fields.get("title"), item_label + ".title") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let path = match json_string(fields.get("path"), item_label + ".path") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let summary = match
      json_string(fields.get("summary"), item_label + ".summary") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let keywords = match parse_keywords(fields, item_label) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    entries.push({ group, slug, title, path, summary, keywords })
  }
  Ok(entries)
}

///|
fn parse_localized_entries(
  values : Array[Json],
  label : String,
) -> Result[Array[CatalogLocalizedEntry], String] {
  if values.is_empty() {
    return Err(label + " must be a non-empty array")
  }
  let entries : Array[CatalogLocalizedEntry] = []
  for index, entry_value in values {
    let item_label = label + "[" + index.to_string() + "]"
    let fields = match json_object(Some(entry_value), item_label) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let group = match json_string(fields.get("group"), item_label + ".group") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let slug = match json_string(fields.get("slug"), item_label + ".slug") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let title = match json_string(fields.get("title"), item_label + ".title") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let summary = match
      json_string(fields.get("summary"), item_label + ".summary") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let keywords = match parse_keywords(fields, item_label) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let localized_path = match fields.get("localizedPath") {
      None => None
      Some(Json::String(path)) if path.trim().to_owned() != "" => Some(path)
      _ => return Err(item_label + ".localizedPath must be a non-empty string")
    }
    entries.push({ group, slug, title, summary, keywords, localized_path })
  }
  Ok(entries)
}

///|
fn is_ascii_letter(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
}

///|
fn is_ascii_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn is_valid_locale_tag(tag : String) -> Bool {
  let mut part_length = 0
  let mut part_index = 0
  for ch in tag {
    if ch == '-' {
      if part_length == 0 ||
        part_length > 8 ||
        (part_index == 0 && part_length < 2) {
        return false
      }
      part_index = part_index + 1
      part_length = 0
    } else if is_ascii_letter(ch) || is_ascii_digit(ch) {
      part_length = part_length + 1
    } else {
      return false
    }
  }
  part_length > 0 && part_length <= 8 && !(part_index == 0 && part_length < 2)
}

///|
fn parse_locales(
  root : Map[String, Json],
) -> Result[Array[CatalogLocale], String] {
  let fields = match root.get("locales") {
    None => return Ok([])
    Some(Json::Object(value)) => value
    _ => return Err("locales must be an object")
  }
  let locales : Array[CatalogLocale] = []
  for tag, locale_value in fields {
    if !is_valid_locale_tag(tag) {
      return Err("invalid locale tag: " + tag)
    }
    let label = "locales." + tag
    let locale = match json_object(Some(locale_value), label) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let groups_json = match
      json_array(locale.get("groups"), label + ".groups") {
      Ok(value) => value
      Err(_) => return Err(label + ".groups must be a non-empty array")
    }
    let groups = match parse_groups(groups_json, label + ".groups") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let entries_json = match
      json_array(locale.get("entries"), label + ".entries") {
      Ok(value) => value
      Err(_) => return Err(label + ".entries must be a non-empty array")
    }
    let entries = match
      parse_localized_entries(entries_json, label + ".entries") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    locales.push({ tag, groups, entries })
  }
  Ok(locales)
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
  let schema_version = match
    json_int(root.get("schemaVersion"), "schemaVersion") {
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
  let groups_json = match
    json_array(root.get("groups"), "docs catalog groups") {
    Ok(values) => values
    Err(_) => return Err("docs catalog groups must be a non-empty array")
  }
  let groups = match parse_groups(groups_json, "groups") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let entries_json = match
    json_array(root.get("entries"), "docs catalog entries") {
    Ok(values) => values
    Err(_) => return Err("docs catalog entries must be a non-empty array")
  }
  let entries = match parse_entries(entries_json, "entries") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let excluded_json = match
    json_array(root.get("excluded"), "docs catalog excluded") {
    Ok(values) => values
    Err(_) => return Err("docs catalog excluded must be an array")
  }
  let excluded : Array[CatalogExcluded] = []
  for index, excluded_value in excluded_json {
    let fields = match
      json_object(Some(excluded_value), "excluded[" + index.to_string() + "]") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let path = match
      json_string(
        fields.get("path"),
        "excluded[" + index.to_string() + "].path",
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let reason = match
      json_string(
        fields.get("reason"),
        "excluded[" + index.to_string() + "].reason",
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    excluded.push({ path, reason })
  }
  let locales = match parse_locales(root) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ schema_version, site_url, groups, entries, excluded, locales })
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
fn canonical_entry_for(
  entries : Array[CatalogEntry],
  slug : String,
) -> CatalogEntry? {
  for entry in entries {
    if entry.slug == slug {
      return Some(entry)
    }
  }
  None
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
    match
      validate_repo_path(source_path, "source path for '" + entry.slug + "'") {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    classified_sources.push(source_path)
    if !@tools.file_exists(@tools.resolve_path(repo_root, source_path)) {
      return Err("published source is missing: " + source_path)
    }
    validated_entries.push({
      group: entry.group,
      slug: entry.slug,
      title: entry.title,
      path: entry.path,
      summary: entry.summary,
      keywords: entry.keywords,
      source_path,
      output_name: basename(entry.path),
    })
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
  expected_sources.push("README.md")
  expected_sources.push("moui_skia/README.mbt.md")
  expected_sources.sort_by((left, right) => left.lexical_compare(right))
  let unclassified : Array[String] = []
  for path in expected_sources {
    if !array_contains(classified_sources, path) {
      unclassified.push(path)
    }
  }
  if !unclassified.is_empty() {
    return Err("unclassified Markdown sources: " + unclassified.join(", "))
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
  let locale_tags : Array[String] = []
  let validated_locales : Array[ValidatedLocale] = []
  for locale in catalog.locales {
    if array_contains(locale_tags, locale.tag) {
      return Err("duplicate locale tag: " + locale.tag)
    }
    locale_tags.push(locale.tag)
    let localized_group_ids : Array[String] = []
    for group in locale.groups {
      if array_contains(localized_group_ids, group.id) {
        return Err(
          "duplicate localized group id for locale '" +
          locale.tag +
          "': " +
          group.id,
        )
      }
      localized_group_ids.push(group.id)
    }
    for group_id in group_ids {
      if !array_contains(localized_group_ids, group_id) {
        return Err(
          "localized groups missing stable id for locale '" +
          locale.tag +
          "': " +
          group_id,
        )
      }
    }
    for group_id in localized_group_ids {
      if !array_contains(group_ids, group_id) {
        return Err(
          "localized groups contain unknown stable id for locale '" +
          locale.tag +
          "': " +
          group_id,
        )
      }
    }
    let localized_slugs : Array[String] = []
    let localized_outputs : Array[String] = []
    let validated_locale_entries : Array[ValidatedLocaleEntry] = []
    for entry in locale.entries {
      if !array_contains(group_ids, entry.group) {
        return Err(
          "unknown localized group '" +
          entry.group +
          "' for slug '" +
          entry.slug +
          "' in locale '" +
          locale.tag +
          "'",
        )
      }
      if !array_contains(slugs, entry.slug) {
        return Err(
          "localized entries contain unknown stable slug for locale '" +
          locale.tag +
          "': " +
          entry.slug,
        )
      }
      if array_contains(localized_slugs, entry.slug) {
        return Err(
          "duplicate localized slug for locale '" +
          locale.tag +
          "': " +
          entry.slug,
        )
      }
      localized_slugs.push(entry.slug)
      let canonical = match canonical_entry_for(catalog.entries, entry.slug) {
        Some(value) => value
        None =>
          return Err("localized entry parity lookup failed: " + entry.slug)
      }
      if canonical.group != entry.group {
        return Err(
          "localized entry group differs from stable group for locale '" +
          locale.tag +
          "' slug '" +
          entry.slug +
          "'",
        )
      }
      let source_path = match entry.localized_path {
        Some(path) => path
        None => "docs/" + locale.tag + "/" + basename(canonical.path)
      }
      match
        validate_repo_path(
          source_path,
          "localizedPath for locale '" +
          locale.tag +
          "' slug '" +
          entry.slug +
          "'",
        ) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
      let locale_prefix = "docs/" + locale.tag + "/"
      if !source_path.has_prefix(locale_prefix) ||
        !source_path.has_suffix(".md") ||
        basename(source_path) == "catalog.json" {
        return Err(
          "localizedPath must be a Markdown file below " +
          locale_prefix +
          ": " +
          source_path,
        )
      }
      let output_name = basename(source_path)
      if array_contains(localized_outputs, output_name) {
        return Err(
          "duplicate localized output for locale '" +
          locale.tag +
          "': " +
          output_name,
        )
      }
      localized_outputs.push(output_name)
      if !@tools.file_exists(@tools.resolve_path(repo_root, source_path)) {
        return Err("localized source is missing: " + source_path)
      }
      validated_locale_entries.push({
        group: entry.group,
        slug: entry.slug,
        title: entry.title,
        summary: entry.summary,
        keywords: entry.keywords,
        source_path,
        output_name,
      })
    }
    for slug in slugs {
      if !array_contains(localized_slugs, slug) {
        return Err(
          "localized entries missing stable slug for locale '" +
          locale.tag +
          "': " +
          slug,
        )
      }
    }
    validated_locales.push({
      tag: locale.tag,
      groups: locale.groups,
      entries: validated_locale_entries,
    })
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
  Ok({ catalog, entries: validated_entries, locales: validated_locales })
}
