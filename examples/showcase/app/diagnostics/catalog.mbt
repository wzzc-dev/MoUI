///|
/// Diagnostics is the only Showcase package that may import runtime/render.
/// Catalog is intentionally narrow — component demos live under Components/Patterns.
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
  [{ id: "runtime", title: "Runtime" }]
}

///|
pub fn catalog_items() -> Array[CatalogItem] {
  [
    {
      id: "diagnostics",
      group_id: "runtime",
      title: "Inspector",
      summary: "Input, text, and rendering diagnostics overview.",
      badge: "runtime",
    },
    {
      id: "runtime-renderer",
      group_id: "runtime",
      title: "Runtime / Renderer",
      summary: "Host and renderer capability reports.",
      badge: "runtime",
    },
    {
      id: "advanced-rendering",
      group_id: "runtime",
      title: "Advanced Rendering",
      summary: "Layer, brush, and paint stress demos.",
      badge: "render",
    },
    {
      id: "text-diagnostics",
      group_id: "runtime",
      title: "Text Diagnostics",
      summary: "Text shaping and layout diagnostic panels.",
      badge: "text",
    },
    {
      id: "interaction-lab",
      group_id: "runtime",
      title: "Interaction Lab",
      summary: "Pointer, gesture, and focus diagnostics.",
      badge: "input",
    },
  ]
}
