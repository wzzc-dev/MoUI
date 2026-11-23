///|
/// One row of the editor surface's context menu.
///
/// The package owns the catalog — which commands a surface offers, in which
/// separator bucket, under which label — while the app owns the presentation
/// and maps `action` to its own message. `action` is one of the canonical
/// command words already used by the format palette and the editor keymap
/// (`"bold"`, `"table-row"`, `"move-block-up"`), so the two catalogs never
/// disagree about spelling.
#derive(Eq, Debug, ToJson)
pub(all) struct MarkdownMenuItem {
  action : String
  label : String
  group : String
}

///|
pub extend MarkdownMenuItem with Debug::{to_repr}

///|
pub extend MarkdownMenuItem with Eq::{not_equal, equal}

///|
pub extend MarkdownMenuItem with ToJson::{to_json}

///|
fn markdown_menu_item(
  action : String,
  label : String,
  group : String,
) -> MarkdownMenuItem {
  { action, label, group, }
}

///|
/// The commands the document surface offers for the current target.
///
/// Membership follows what mature editors gate on rather than disabling rows:
/// table commands appear only inside a table, `open target` only when
/// something can be opened, inline formatting only with a selection, and the
/// task toggle only inside a task item. App-only rows (save, export, find,
/// panel toggles) are deliberately absent: they belong to the shell, not the
/// markdown surface.
pub fn markdown_editor_surface_menu_items(
  target~ : @richtext.MarkdownEditorTarget,
  has_selection~ : Bool,
  in_task_item~ : Bool,
  has_openable_target~ : Bool,
) -> Array[MarkdownMenuItem] {
  let mut items : Array[MarkdownMenuItem] = []
  if target.block_kind is @richtext.Table {
    items = items +
      [
        markdown_menu_item("table-row", "Insert Table Row", "table"),
        markdown_menu_item("table-column", "Insert Table Column", "table"),
        markdown_menu_item("table-row-delete", "Delete Table Row", "table"),
        markdown_menu_item(
          "table-column-delete", "Delete Table Column", "table",
        ),
        markdown_menu_item("table-align-left", "Table Align Left", "table"),
        markdown_menu_item("table-align-center", "Table Align Center", "table"),
        markdown_menu_item("table-align-right", "Table Align Right", "table"),
        markdown_menu_item("table-align-auto", "Table Align Auto", "table"),
      ]
  }
  if has_openable_target || target.has_openable_target() {
    items.push(markdown_menu_item("open-target", "Open Target", "target"))
  }
  if has_selection {
    items = items +
      [
        markdown_menu_item("bold", "Bold", "inline"),
        markdown_menu_item("italic", "Italic", "inline"),
        markdown_menu_item("strike", "Strikethrough", "inline"),
        markdown_menu_item("code", "Inline Code", "inline"),
        markdown_menu_item("highlight", "Highlight", "inline"),
        markdown_menu_item("link", "Link", "inline"),
        markdown_menu_item("image", "Image", "inline"),
      ]
  }
  // Block commands act at the caret, so they stay visible without a
  // selection.
  items = items +
    [
      markdown_menu_item("paragraph", "Paragraph", "block"),
      markdown_menu_item("h1", "Heading 1", "block"),
      markdown_menu_item("h2", "Heading 2", "block"),
      markdown_menu_item("h3", "Heading 3", "block"),
      markdown_menu_item("h4", "Heading 4", "block"),
      markdown_menu_item("h5", "Heading 5", "block"),
      markdown_menu_item("h6", "Heading 6", "block"),
      markdown_menu_item("ul", "Bullet List", "block"),
      markdown_menu_item("ol", "Ordered List", "block"),
      markdown_menu_item("task", "Task List", "block"),
      markdown_menu_item("quote", "Quote", "block"),
      markdown_menu_item("codeblock", "Code Block", "block"),
      markdown_menu_item("duplicate-block", "Duplicate Block", "block"),
      markdown_menu_item("move-block-up", "Move Block Up", "block"),
      markdown_menu_item("move-block-down", "Move Block Down", "block"),
    ]
  if in_task_item {
    items.push(markdown_menu_item("toggle-task", "Toggle Task", "task"))
  }
  items = items +
    [
      markdown_menu_item("indent-lines", "Indent Lines", "lines"),
      markdown_menu_item("outdent-lines", "Outdent Lines", "lines"),
      markdown_menu_item("hard-break", "Hard Line Break", "lines"),
      markdown_menu_item("toc", "Insert Table of Contents", "insert"),
      markdown_menu_item("front-matter", "Insert YAML Front Matter", "insert"),
    ]
  items
}
