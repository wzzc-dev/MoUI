///|
pub enum WebsitePage {
  WebsiteHome
  WebsiteDocs
}

///|
priv struct WebsiteDocEntry {
  slug : String
  title : String
  path : String
  summary : String
}

///|
pub enum WebsiteDocBlock {
  DocHeading(Int, String)
  DocParagraph(String)
  DocListItem(String, String)
  DocQuote(String)
  DocCodeBlock(String, String)
  DocTable(Array[String])
  DocRule
}

///|
pub struct WebsiteDocDocument {
  title : String
  blocks : Array[WebsiteDocBlock]
}

///|
pub enum WebsiteDocLoadState {
  DocNotLoaded
  DocLoading(@host.HostServiceRequestId, String)
  DocLoaded(String, WebsiteDocDocument)
  DocFailed(String, String)
}

///|
fn website_docs_entries() -> Array[WebsiteDocEntry] {
  [
    {
      slug: "moui-readme",
      title: "MoUI README",
      path: "docs/moui-readme.md",
      summary: "Project overview, setup, platform evidence, and quick start.",
    },
    {
      slug: "moui-skia-readme",
      title: "MoUI Skia README",
      path: "docs/moui-skia-readme.md",
      summary: "Skia binding API surface, native boundary, and smoke workflow.",
    },
    {
      slug: "architecture",
      title: "Architecture",
      path: "docs/architecture.md",
      summary: "Runtime, host, renderer, and package boundaries.",
    },
    {
      slug: "development",
      title: "Development",
      path: "docs/development.md",
      summary: "Local setup, preview loop, and validation commands.",
    },
    {
      slug: "platform-notes",
      title: "Platform Notes",
      path: "docs/platform-notes.md",
      summary: "Web and native backend setup notes.",
    },
    {
      slug: "text-system",
      title: "Text System",
      path: "docs/text-system.md",
      summary: "Text measurement, shaping, and provider boundaries.",
    },
    {
      slug: "renderer-capability-report",
      title: "Renderer Capabilities",
      path: "docs/renderer-capability-report.md",
      summary: "Renderer support matrix and tracked gaps.",
    },
    {
      slug: "view-catalog",
      title: "View Catalog",
      path: "docs/view-catalog.md",
      summary: "Current public constructor and component matrix.",
    },
    {
      slug: "views-api-guide",
      title: "Views API Guide",
      path: "docs/views-api-guide.md",
      summary: "Quick reference for public views usage.",
    },
    {
      slug: "non-render-component-cookbook",
      title: "Component Cookbook",
      path: "docs/non-render-component-cookbook.md",
      summary: "Reusable non-render app patterns.",
    },
    {
      slug: "app-templates",
      title: "App Templates",
      path: "docs/app-templates.md",
      summary: "Starter shapes for shared app packages.",
    },
    {
      slug: "examples",
      title: "Examples",
      path: "docs/examples.md",
      summary: "Runnable examples and validation notes.",
    },
    {
      slug: "markdown-editor",
      title: "Markdown Editor",
      path: "docs/markdown-editor.md",
      summary: "WYSIWYG Markdown editing model and commands.",
    },
    {
      slug: "testing",
      title: "Testing",
      path: "docs/testing.md",
      summary: "Focused tests, conformance, and evidence rules.",
    },
    {
      slug: "tutorials",
      title: "Tutorials",
      path: "docs/tutorials.md",
      summary: "Implementation skeletons for common changes.",
    },
    {
      slug: "templates",
      title: "Templates",
      path: "docs/templates.md",
      summary: "Reusable checklists and implementation prompts.",
    },
    {
      slug: "ai-collaboration",
      title: "AI Collaboration",
      path: "docs/ai-collaboration.md",
      summary: "Agent workflow and review guidance.",
    },
    {
      slug: "mo-workbench",
      title: "Mo Workbench",
      path: "docs/mo-workbench.md",
      summary: "Agent desktop dogfood app architecture.",
    },
    {
      slug: "release-readiness",
      title: "Release Readiness",
      path: "docs/release-readiness.md",
      summary: "Preview release gates and current evidence.",
    },
    {
      slug: "roadmap-2026",
      title: "2026 Roadmap",
      path: "docs/roadmap-2026.md",
      summary: "Planned implementation slices.",
    },
  ]
}

///|
fn website_default_doc_entry() -> WebsiteDocEntry {
  website_docs_entries()[0]
}

///|
fn website_doc_entry_by_slug(slug : String) -> WebsiteDocEntry {
  for entry in website_docs_entries() {
    if entry.slug == slug {
      return entry
    }
  }
  website_default_doc_entry()
}

///|
fn website_doc_entry_by_path(path : String) -> WebsiteDocEntry {
  for entry in website_docs_entries() {
    if entry.path == path {
      return entry
    }
  }
  website_default_doc_entry()
}

///|
fn Model::website_doc_selected_entry(self : Model) -> WebsiteDocEntry {
  website_doc_entry_by_slug(self.selected_doc_slug)
}

///|
fn Model::website_doc_loading_path(self : Model) -> String {
  self.website_doc_selected_entry().path
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
