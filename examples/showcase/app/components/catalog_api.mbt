///|
/// Hosted Showcase catalog entries (body-only shell). Mobile Service Probe lives
/// only under the Platform workspace.
pub(all) struct CatalogGroup {
  id : String
  title : String
} derive(Eq, Debug)

///|
pub(all) struct CatalogItem {
  id : String
  group_id : String
  title : String
  summary : String
  badge : String
} derive(Eq, Debug)

///|
pub fn catalog_groups() -> Array[CatalogGroup] {
  component_gallery_groups().map(group =>
    { id: group.id, title: group.name }
  )
}

///|
pub fn catalog_items() -> Array[CatalogItem] {
  let rows : Array[CatalogItem] = []
  for item in component_gallery_items() {
    if item.id != ComponentGalleryItemId::MobileServiceProbe {
      rows.push(
        {
          id: gallery_item_id_to_string(item.id),
          group_id: item.group,
          title: item.name,
          summary: item.description,
          badge: item.badge,
        },
      )
    }
  }
  rows
}
