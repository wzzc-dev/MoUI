///|
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
  [
    { id: "start", title: "Start" },
    { id: "workflows", title: "Workflows" },
  ]
}

///|
pub fn catalog_items() -> Array[CatalogItem] {
  [
    {
      id: "welcome",
      group_id: "start",
      title: "Patterns Overview",
      summary: "App-shaped recipes (Counter, Todo, forms, workflows) you can copy as whole features.",
      badge: "intro",
    },
    {
      id: "counter",
      group_id: "workflows",
      title: "Counter",
      summary: "Minimal state loop with package-owned messages.",
      badge: "state",
    },
    {
      id: "todo",
      group_id: "workflows",
      title: "Todo",
      summary: "List editing with draft submit and remove.",
      badge: "state",
    },
    {
      id: "forms",
      group_id: "workflows",
      title: "Forms",
      summary: "Profile fields, validation, and save feedback.",
      badge: "form",
    },
    {
      id: "data",
      group_id: "workflows",
      title: "Data",
      summary: "Filter a small collection from model state.",
      badge: "data",
    },
    {
      id: "navigation",
      group_id: "workflows",
      title: "Navigation",
      summary: "Feature-owned routes inside a workspace.",
      badge: "nav",
    },
    {
      id: "workflow",
      group_id: "workflows",
      title: "Workflow",
      summary: "Multi-step progress with back and next.",
      badge: "flow",
    },
    {
      id: "text-media",
      group_id: "workflows",
      title: "Text & Media",
      summary: "Markdown-style content behind app-safe views.",
      badge: "media",
    },
  ]
}
