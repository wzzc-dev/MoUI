///|
pub enum WebsitePage {
  WebsiteHome
  WebsiteTutorial
  WebsiteDocs
  WebsiteShowcases
} derive(Eq, Debug)

///|
pub struct WebsiteDocGroup {
  id : String
  title : String
} derive(Eq, Debug, ToJson, FromJson)

///|
pub struct WebsiteDocEntry {
  group : String
  slug : String
  title : String
  path : String
  summary : String
  keywords : Array[String]
} derive(Eq, Debug, ToJson, FromJson)

///|
pub struct WebsiteDocsCatalog {
  schemaVersion : Int
  siteUrl : String
  groups : Array[WebsiteDocGroup]
  entries : Array[WebsiteDocEntry]
} derive(Eq, Debug, ToJson, FromJson)

///|
pub enum WebsiteCatalogLoadState {
  CatalogNotLoaded
  CatalogLoading(@host.HostServiceRequestId)
  CatalogLoaded(WebsiteDocsCatalog)
  CatalogFailed(String)
}

///|
pub struct WebsiteDocDocument {
  title : String
  source : String
}

///|
pub enum WebsiteDocLoadState {
  DocNotLoaded
  DocLoading(@host.HostServiceRequestId, String)
  DocLoaded(String, WebsiteDocDocument)
  DocFailed(String, String)
  DocNotFound(String)
}

///|
priv enum WebsiteRouteCommand {
  PushRoute(String)
  ScrollToKey(String, @core.ScrollAlignment)
}

///|
pub struct WebsiteRouteHost {
  route_source : @host.HostRouteSource
  push_route : (String) -> Unit
  scroll_to_key : (String, @core.ScrollAlignment) -> Unit
  update_metadata : (String, String, String) -> Unit
}

///|
pub fn WebsiteRouteHost::new(
  route_source~ : @host.HostRouteSource,
  push_route? : (String) -> Unit = _route => (),
  scroll_to_key? : (String, @core.ScrollAlignment) -> Unit = (_key, _alignment) => {
    ()
  },
  update_metadata? : (String, String, String) -> Unit = (
    _title,
    _description,
    _canonical,
  ) => (),
) -> WebsiteRouteHost {
  { route_source, push_route, scroll_to_key, update_metadata }
}

///|
fn website_parse_catalog(source : String) -> WebsiteDocsCatalog? {
  let parsed = @json.parse(source) catch { _ => return None }
  let catalog : WebsiteDocsCatalog = @json.from_json(parsed) catch {
    _ => return None
  }
  if catalog.schemaVersion != 1 ||
    catalog.groups.is_empty() ||
    catalog.entries.is_empty() {
    return None
  }
  let slugs : Array[String] = []
  for entry in catalog.entries {
    if entry.slug == "" ||
      entry.title == "" ||
      !entry.path.has_prefix("docs/") ||
      !entry.path.has_suffix(".md") ||
      entry.path.contains("..") ||
      slugs.any(slug => slug == entry.slug) {
      return None
    }
    slugs.push(entry.slug)
  }
  Some(catalog)
}

///|
fn WebsiteDocsCatalog::entry_by_slug(
  self : WebsiteDocsCatalog,
  slug : String,
) -> WebsiteDocEntry? {
  for entry in self.entries {
    if entry.slug == slug {
      return Some(entry)
    }
  }
  None
}

///|
fn WebsiteDocsCatalog::filtered_entries(
  self : WebsiteDocsCatalog,
  query : String,
) -> Array[WebsiteDocEntry] {
  let needle = query.trim().to_owned().to_lower()
  if needle == "" {
    return self.entries
  }
  self.entries.filter(entry => {
    entry.title.to_lower().contains(needle) ||
    entry.summary.to_lower().contains(needle) ||
    entry.slug.to_lower().contains(needle) ||
    entry.keywords.any(keyword => keyword.to_lower().contains(needle))
  })
}

///|
fn Model::website_catalog(self : Model) -> WebsiteDocsCatalog? {
  match self.catalog_state {
    CatalogLoaded(catalog) => Some(catalog)
    _ => None
  }
}

///|
fn Model::website_doc_selected_entry(self : Model) -> WebsiteDocEntry? {
  match self.website_catalog() {
    Some(catalog) => catalog.entry_by_slug(self.selected_doc_slug)
    None => None
  }
}

///|
fn Model::website_doc_loading_path(self : Model) -> String {
  match self.website_doc_selected_entry() {
    Some(entry) => entry.path
    None => ""
  }
}

///|
fn WebsiteCatalogLoadState::pending_id(
  self : WebsiteCatalogLoadState,
) -> @host.HostServiceRequestId? {
  match self {
    CatalogLoading(id) => Some(id)
    _ => None
  }
}

///|
fn WebsiteDocLoadState::pending_id(
  self : WebsiteDocLoadState,
) -> @host.HostServiceRequestId? {
  match self {
    DocLoading(id, _) => Some(id)
    _ => None
  }
}

///|
fn website_parse_markdown_document(
  path : String,
  source : String,
) -> WebsiteDocDocument {
  let blocks = @moui_richtext.parse_markdown(source)
  let mut title = path
  for block in blocks {
    match block.kind {
      @moui_richtext.MarkdownBlockKind::Heading(_) =>
        if block.text != "" {
          title = block.text
          break
        }
      _ => ()
    }
  }
  { title, source }
}

///|
fn website_heading_anchor(value : String) -> String {
  let output : Array[Char] = []
  let mut previous_dash = false
  for ch in value.to_lower() {
    let code = ch.to_int()
    let alpha_numeric = (code >= 'a'.to_int() && code <= 'z'.to_int()) ||
      (code >= '0'.to_int() && code <= '9'.to_int()) ||
      code > 127
    if alpha_numeric {
      output.push(ch)
      previous_dash = false
    } else if !previous_dash && output.length() > 0 {
      output.push('-')
      previous_dash = true
    }
  }
  if output.length() > 0 && output[output.length() - 1] == '-' {
    ignore(output.pop())
  }
  String::from_array(output)
}

///|
fn website_doc_wrap_lines(
  value : String,
  width : Double,
  font_size : Double,
) -> Array[String] {
  let limit = max_website_int(8, (width / (font_size * 0.56)).to_int())
  let lines : Array[String] = []
  for source_line in value.split("\n") {
    let words = source_line.to_owned().split(" ").to_array()
    let current : Array[String] = []
    let mut current_length = 0
    for word_view in words {
      let word = word_view.to_owned()
      if current_length > 0 && current_length + 1 + word.length() > limit {
        lines.push(current.join(" "))
        current.clear()
        current_length = 0
      }
      current.push(word)
      let separator_length = if current_length > 0 { 1 } else { 0 }
      current_length = current_length + separator_length + word.length()
    }
    lines.push(current.join(" "))
  }
  if lines.is_empty() {
    [""]
  } else {
    lines
  }
}
