///|
/// Hosted Showcase catalog entries (body-only shell). Mobile Service Probe lives
/// only under the Platform workspace.
#derive(Eq, Debug)
pub(all) struct CatalogGroup {
  id : String
  title : String
}

///|
pub extend CatalogGroup with Debug::{to_repr}

///|
pub extend CatalogGroup with Eq::{not_equal, equal}

///|
#derive(Eq, Debug)
pub(all) struct CatalogItem {
  id : String
  group_id : String
  title : String
  summary : String
  badge : String
  tone : @views.BadgeTone
}

///|
pub extend CatalogItem with Debug::{to_repr}

///|
pub extend CatalogItem with Eq::{not_equal, equal}

///|
pub fn catalog_groups() -> Array[CatalogGroup] {
  component_gallery_groups().map(group => { id: group.id, title: group.name, })
}

///|
pub fn catalog_items() -> Array[CatalogItem] {
  let rows : Array[CatalogItem] = []
  for item in component_gallery_items() {
    if item.id != MobileServiceProbe {
      rows.push({
        id: gallery_item_id_to_string(item.id),
        group_id: item.group,
        title: item.name,
        summary: item.description,
        badge: item.badge,
        tone: item.tone,
      })
    }
  }
  rows
}
