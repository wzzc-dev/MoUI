///|
/// Format palette domain: the catalog of quick-format commands MoMark shows
/// in its "Quick Format" overlay, the query filter over that catalog, and the
/// mapping from palette action ids to `MarkdownEditorCommand`s.
///
/// Action ids that have no engine command (view toggles like "source-mode",
/// document actions like "html-export") intentionally map to `None`; the
/// consuming app handles those itself.

///|
/// One quick-format palette entry.
pub(all) struct MarkdownPaletteItem {
  action : String
  label : String
  group : String
  shortcut : String
} derive(Eq, Debug, ToJson)

///|
pub extend MarkdownPaletteItem with Eq::{equal, not_equal}

///|
pub extend MarkdownPaletteItem with Debug::{to_repr}

///|
pub extend MarkdownPaletteItem with ToJson::{to_json}

///|
/// Internal constructor for catalog rows.
fn markdown_palette_item(
  action : String,
  label : String,
  group : String,
  shortcut : String,
) -> MarkdownPaletteItem {
  { action, label, group, shortcut, }
}

///|
/// The full quick-format command catalog, in display order.
pub fn markdown_format_palette_items() -> Array[MarkdownPaletteItem] {
  [
    markdown_palette_item("paragraph", "Paragraph", "Block", "Meta+0 / Ctrl+0"),
    markdown_palette_item("h1", "Heading 1", "Block", "Meta+1 / Ctrl+1"),
    markdown_palette_item("h2", "Heading 2", "Block", "Meta+2 / Ctrl+2"),
    markdown_palette_item("h3", "Heading 3", "Block", "Meta+3 / Ctrl+3"),
    markdown_palette_item("bold", "Bold", "Inline", "Meta+B / Ctrl+B"),
    markdown_palette_item("italic", "Italic", "Inline", "Meta+I / Ctrl+I"),
    markdown_palette_item("code", "Inline Code", "Inline", "Meta+E / Ctrl+E"),
    markdown_palette_item("strike", "Strikethrough", "Inline", "Meta+Shift+X"),
    markdown_palette_item("highlight", "Highlight", "Inline", "Meta+Shift+H"),
    markdown_palette_item("link", "Link", "Inline", "Meta+L / Ctrl+K"),
    markdown_palette_item("image", "Image", "Inline", "Meta+Shift+I"),
    markdown_palette_item("ul", "Bullet List", "Block", "Meta+U"),
    markdown_palette_item("task", "Task List", "Block", "Meta+T"),
    markdown_palette_item("ol", "Ordered List", "Block", "Meta+O"),
    markdown_palette_item("quote", "Quote", "Block", "Meta+Q"),
    markdown_palette_item("codeblock", "Code Block", "Block", "Meta+K"),
    markdown_palette_item("table", "Table", "Block", ""),
    markdown_palette_item("toc", "Table of Contents", "Document", "Meta+Alt+T"),
    markdown_palette_item(
      "front-matter", "YAML Front Matter", "Document", "Meta+Alt+Y",
    ),
    markdown_palette_item("rule", "Horizontal Rule", "Block", ""),
    markdown_palette_item(
      "duplicate-block", "Duplicate Block", "Block", "Meta+Shift+D",
    ),
    markdown_palette_item("focus-mode", "Focus Mode", "View", "Meta+Shift+F"),
    markdown_palette_item(
      "typewriter-mode", "Typewriter Mode", "View", "Meta+Shift+T",
    ),
    markdown_palette_item("zen-mode", "Zen Mode", "View", "Meta+Alt+Z"),
    markdown_palette_item("source-mode", "Source Mode", "View", "Meta+Shift+/"),
    markdown_palette_item("files", "Files", "View", "Meta+Alt+P"),
    markdown_palette_item("image-center", "Center Image", "Block", ""),
    markdown_palette_item(
      "html-export", "Export HTML", "Document", "Meta+Alt+E",
    ),
    markdown_palette_item(
      "document-info", "Document Info", "View", "Meta+Alt+D",
    ),
    markdown_palette_item("look-paper", "Paper Look", "View", ""),
    markdown_palette_item("look-warm", "Warm Look", "View", "Meta+Alt+L"),
    markdown_palette_item("look-wide", "Wide Look", "View", "Meta+Alt+L"),
  ]
}

///|
/// Case-insensitive substring filter over label/group/shortcut. A blank
/// query returns the full catalog.
pub fn markdown_format_palette_filtered_items(
  query : String,
) -> Array[MarkdownPaletteItem] {
  let items = markdown_format_palette_items()
  let needle = query.trim().to_owned().to_lower()
  if needle == "" {
    items
  } else {
    items.filter(item => markdown_format_palette_matches(item, needle))
  }
}

///|
/// Whether a (already lowercased) needle matches an entry.
pub fn markdown_format_palette_matches(
  item : MarkdownPaletteItem,
  needle : String,
) -> Bool {
  item.label.to_lower().contains(needle) ||
  item.group.to_lower().contains(needle) ||
  item.shortcut.to_lower().contains(needle)
}

///|
/// Map a palette action id to its editor command. Actions with no engine
/// command (view toggles, export, files, appearance) return `None`.
pub fn markdown_command_from_palette_action(
  action : String,
) -> @richtext.MarkdownEditorCommand? {
  if action == "bold" {
    Some(@richtext.MarkdownEditorCommand::Bold)
  } else if action == "italic" {
    Some(@richtext.MarkdownEditorCommand::Italic)
  } else if action == "code" {
    Some(@richtext.MarkdownEditorCommand::Code)
  } else if action == "strike" {
    Some(@richtext.MarkdownEditorCommand::Strikethrough)
  } else if action == "highlight" {
    Some(@richtext.MarkdownEditorCommand::Highlight)
  } else if action == "link" {
    Some(@richtext.MarkdownEditorCommand::Link)
  } else if action == "link-target" {
    Some(
      @richtext.MarkdownEditorCommand::SetLinkTarget(
        "https://wzzc-dev.github.io/MoUI",
      ),
    )
  } else if action == "image" {
    Some(@richtext.MarkdownEditorCommand::Image)
  } else if action == "image-target" {
    Some(@richtext.MarkdownEditorCommand::SetImageTarget("assets/image.png"))
  } else if action == "code-language" {
    Some(@richtext.MarkdownEditorCommand::SetCodeLanguage("moonbit"))
  } else if action == "paragraph" {
    Some(@richtext.MarkdownEditorCommand::Paragraph)
  } else if action == "h1" {
    Some(@richtext.MarkdownEditorCommand::Heading(1))
  } else if action == "h2" {
    Some(@richtext.MarkdownEditorCommand::Heading(2))
  } else if action == "h3" {
    Some(@richtext.MarkdownEditorCommand::Heading(3))
  } else if action == "h4" {
    Some(@richtext.MarkdownEditorCommand::Heading(4))
  } else if action == "h5" {
    Some(@richtext.MarkdownEditorCommand::Heading(5))
  } else if action == "h6" {
    Some(@richtext.MarkdownEditorCommand::Heading(6))
  } else if action == "ul" {
    Some(@richtext.MarkdownEditorCommand::BulletList)
  } else if action == "task" {
    Some(@richtext.MarkdownEditorCommand::TaskList)
  } else if action == "ol" {
    Some(@richtext.MarkdownEditorCommand::OrderedList)
  } else if action == "quote" {
    Some(@richtext.MarkdownEditorCommand::Quote)
  } else if action == "rule" {
    Some(@richtext.MarkdownEditorCommand::HorizontalRule)
  } else if action == "table" {
    Some(@richtext.MarkdownEditorCommand::Table)
  } else if action == "toc" {
    Some(@richtext.MarkdownEditorCommand::InsertTableOfContents)
  } else if action == "front-matter" {
    Some(@richtext.MarkdownEditorCommand::InsertFrontMatter)
  } else if action == "table-row" {
    Some(@richtext.MarkdownEditorCommand::InsertTableRow)
  } else if action == "table-column" {
    Some(@richtext.MarkdownEditorCommand::InsertTableColumn)
  } else if action == "table-row-delete" {
    Some(@richtext.MarkdownEditorCommand::DeleteTableRow)
  } else if action == "table-column-delete" {
    Some(@richtext.MarkdownEditorCommand::DeleteTableColumn)
  } else if action == "table-align-left" {
    Some(
      @richtext.MarkdownEditorCommand::SetTableColumnAlignment(
        Some(@core.TextAlign::TextStart),
      ),
    )
  } else if action == "table-align-center" {
    Some(
      @richtext.MarkdownEditorCommand::SetTableColumnAlignment(
        Some(@core.TextAlign::TextCenter),
      ),
    )
  } else if action == "table-align-right" {
    Some(
      @richtext.MarkdownEditorCommand::SetTableColumnAlignment(
        Some(@core.TextAlign::TextEnd),
      ),
    )
  } else if action == "table-align-auto" {
    Some(@richtext.MarkdownEditorCommand::SetTableColumnAlignment(None))
  } else if action == "codeblock" {
    Some(@richtext.MarkdownEditorCommand::CodeBlock)
  } else if action == "duplicate-block" {
    Some(@richtext.MarkdownEditorCommand::DuplicateBlock)
  } else if action == "move-block-up" {
    Some(@richtext.MarkdownEditorCommand::MoveBlockUp)
  } else if action == "move-block-down" {
    Some(@richtext.MarkdownEditorCommand::MoveBlockDown)
  } else {
    None
  }
}
