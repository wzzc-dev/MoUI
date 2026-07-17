///|
/// Global story catalog: one flat sidebar of categories (gpui-story style),
/// while feature packages stay isolated behind workspace routes.
pub(all) struct CatalogGroup {
  id : String
  title : String
} derive(Eq, Debug)

///|
pub(all) struct CatalogItem {
  workspace : String
  id : String
  group_id : String
  title : String
  summary : String
  badge : String
} derive(Eq, Debug)

///|
pub fn CatalogGroup::new(id~ : String, title~ : String) -> CatalogGroup {
  { id, title }
}

///|
pub fn CatalogItem::new(
  workspace~ : String,
  id~ : String,
  group_id~ : String,
  title~ : String,
  summary~ : String,
  badge? : String = "",
) -> CatalogItem {
  { workspace, id, group_id, title, summary, badge }
}

///|
pub fn CatalogItem::route(self : CatalogItem) -> String {
  self.workspace + "/" + self.id
}

///|
/// Left-rail category order (merged story index).
pub fn global_catalog_groups() -> Array[CatalogGroup] {
  [
    CatalogGroup::new(id="start", title="Start"),
    CatalogGroup::new(id="controls", title="Controls"),
    CatalogGroup::new(id="feedback", title="Feedback"),
    CatalogGroup::new(id="display", title="Display"),
    CatalogGroup::new(id="layout", title="Layout"),
    CatalogGroup::new(id="patterns", title="Patterns"),
    CatalogGroup::new(id="platform", title="Platform"),
    CatalogGroup::new(id="runtime", title="Runtime"),
  ]
}

///|
/// All stories from every feature package, remapped into global categories.
pub fn global_catalog_items() -> Array[CatalogItem] {
  let rows : Array[CatalogItem] = []
  for item in @components.catalog_items() {
    let group_id = match item.group_id {
      "getting-started" => "start"
      "runtime" => "platform"
      other => other
    }
    rows.push(
      CatalogItem::new(
        workspace="components",
        id=item.id,
        group_id~,
        title=item.title,
        summary=item.summary,
        badge=item.badge,
      ),
    )
  }
  for item in @patterns.catalog_items() {
    // Overview stays under Start; demos live under Patterns.
    let group_id = if item.id == "welcome" { "start" } else { "patterns" }
    rows.push(
      CatalogItem::new(
        workspace="patterns",
        id=item.id,
        group_id~,
        title=item.title,
        summary=item.summary,
        badge=item.badge,
      ),
    )
  }
  for item in @platform.catalog_items() {
    rows.push(
      CatalogItem::new(
        workspace="platform",
        id=item.id,
        group_id="platform",
        title=item.title,
        summary=item.summary,
        badge=item.badge,
      ),
    )
  }
  for item in @diagnostics.catalog_items() {
    rows.push(
      CatalogItem::new(
        workspace="diagnostics",
        id=item.id,
        group_id="runtime",
        title=item.title,
        summary=item.summary,
        badge=item.badge,
      ),
    )
  }
  rows
}

///|
pub fn ShowcaseModel::catalog_groups(
  _self : ShowcaseModel,
) -> Array[CatalogGroup] {
  global_catalog_groups()
}

///|
pub fn ShowcaseModel::catalog_items(
  _self : ShowcaseModel,
) -> Array[CatalogItem] {
  global_catalog_items()
}

///|
pub fn ShowcaseModel::filtered_catalog_items(
  self : ShowcaseModel,
) -> Array[CatalogItem] {
  let query = self.nav_query.trim().to_owned().to_lower()
  if query == "" {
    self.catalog_items()
  } else {
    self
    .catalog_items()
    .filter(item => {
      item.title.to_lower().contains(query) ||
      item.summary.to_lower().contains(query) ||
      item.id.to_lower().contains(query) ||
      item.group_id.to_lower().contains(query) ||
      item.workspace.to_lower().contains(query) ||
      item.badge.to_lower().contains(query)
    })
  }
}

///|
pub fn ShowcaseModel::current_catalog_item(
  self : ShowcaseModel,
) -> CatalogItem? {
  let route = self.current_route_string()
  for item in self.catalog_items() {
    if item.route() == route {
      return Some(item)
    }
  }
  // Fall back to id match within the active workspace.
  for item in self.catalog_items() {
    if item.workspace == self.workspace.slug() && item.id == self.route_id {
      return Some(item)
    }
  }
  None
}
