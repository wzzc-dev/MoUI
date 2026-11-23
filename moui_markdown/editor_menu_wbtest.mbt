///|
/// Build a target with only the fields the menu reads. `link` decides whether
/// the target is openable, which lets a test separate the two gates.
fn menu_target(
  block_kind : @richtext.MarkdownBlockKind,
  link : String?,
) -> @richtext.MarkdownEditorTarget {
  {
    kind: if link is Some(_) {
      @richtext.LinkTarget
    } else if block_kind is @richtext.Table {
      @richtext.TableTools
    } else {
      @richtext.PlainSelection
    },
    block_kind,
    block_label: "Paragraph",
    link_target: link,
    image_target: None,
    footnote_text: None,
    html_block_text: None,
  }
}

///|
fn menu_has(items : Array[MarkdownMenuItem], action : String) -> Bool {
  for item in items {
    if item.action == action {
      return true
    }
  }
  false
}

///|
fn menu_item(
  items : Array[MarkdownMenuItem],
  action : String,
) -> MarkdownMenuItem? {
  for item in items {
    if item.action == action {
      return Some(item)
    }
  }
  None
}

///|
fn menu_group(items : Array[MarkdownMenuItem], action : String) -> String {
  match menu_item(items, action) {
    Some(item) => item.group
    None => abort("missing menu item: " + action)
  }
}

///|
/// A plain caret offers block, line and insert commands only: no table rows,
/// no `open target`, no inline formatting without a selection.
test "markdown_editor_surface_menu_items starts from block commands" {
  let items = markdown_editor_surface_menu_items(
    target=menu_target(@richtext.Paragraph, None),
    has_selection=false,
    in_task_item=false,
    has_openable_target=false,
  )
  assert_eq(items[0].action, "paragraph")
  assert_eq(items[0].group, "block")
  assert_eq(items[items.length() - 1].action, "front-matter")
  assert_true(menu_has(items, "hard-break"))
  assert_false(menu_has(items, "bold"))
  assert_false(menu_has(items, "open-target"))
  assert_false(menu_has(items, "table-row"))
  assert_false(menu_has(items, "toggle-task"))
}

///|
/// All six heading levels, both list styles and the block verbs are present.
test "markdown_editor_surface_menu_items lists every block command" {
  let items = markdown_editor_surface_menu_items(
    target=menu_target(@richtext.Paragraph, None),
    has_selection=false,
    in_task_item=false,
    has_openable_target=false,
  )
  let expected : Array[String] = [
    "paragraph", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "task", "quote",
    "codeblock", "duplicate-block", "move-block-up", "move-block-down",
  ]
  for action in expected {
    assert_true(menu_has(items, action))
  }
  assert_eq(menu_group(items, "toc"), "insert")
  assert_eq(menu_group(items, "indent-lines"), "lines")
}

///|
/// Inside a table the eight table commands come first, in a `table` group.
test "markdown_editor_surface_menu_items leads with table commands in a table" {
  let items = markdown_editor_surface_menu_items(
    target=menu_target(@richtext.Table, None),
    has_selection=false,
    in_task_item=false,
    has_openable_target=false,
  )
  let table_actions : Array[String] = [
    "table-row", "table-column", "table-row-delete", "table-column-delete", "table-align-left",
    "table-align-center", "table-align-right", "table-align-auto",
  ]
  for index in 0..<8 {
    assert_eq(items[index].action, table_actions[index])
    assert_eq(items[index].group, "table")
  }
  assert_false(menu_has(items, "open-target"))
}

///|
/// A link inside a cell still offers both the table commands and `open target`:
/// the table gate reads `block_kind`, not the target kind, so cell references
/// do not hide the row verbs.
test "markdown_editor_surface_menu_items offers table and open target together" {
  let target = menu_target(@richtext.Table, Some("https://example.com"))
  let items = markdown_editor_surface_menu_items(
    target~,
    has_selection=false,
    in_task_item=false,
    has_openable_target=false,
  )
  assert_true(menu_has(items, "table-row"))
  assert_true(menu_has(items, "open-target"))
  assert_eq(menu_group(items, "open-target"), "target")
}

///|
/// `has_openable_target` is an extra gate for targets the model does not carry
/// (a caret inside a rendered link's hover hit), so the row appears even when
/// the target itself would not open it.
test "markdown_editor_surface_menu_items honours the openable override" {
  let items = markdown_editor_surface_menu_items(
    target=menu_target(@richtext.Paragraph, None),
    has_selection=false,
    in_task_item=false,
    has_openable_target=true,
  )
  assert_true(menu_has(items, "open-target"))
  let items = markdown_editor_surface_menu_items(
    target=menu_target(@richtext.Paragraph, Some("https://example.com")),
    has_selection=false,
    in_task_item=false,
    has_openable_target=false,
  )
  assert_true(menu_has(items, "open-target"))
}

///|
/// A selection adds exactly the seven inline commands, in their display order.
test "markdown_editor_surface_menu_items adds inline commands for a selection" {
  let items = markdown_editor_surface_menu_items(
    target=menu_target(@richtext.Paragraph, None),
    has_selection=true,
    in_task_item=false,
    has_openable_target=false,
  )
  let inline_actions : Array[String] = [
    "bold", "italic", "strike", "code", "highlight", "link", "image",
  ]
  let mut found = 0
  for item in items {
    if item.group == "inline" {
      assert_eq(item.action, inline_actions[found])
      found = found + 1
    }
  }
  assert_eq(found, 7)
  // The inline bucket sits between the target rows and the block commands.
  assert_eq(menu_group(items, "bold"), "inline")
  assert_true(menu_has(items, "paragraph"))
}

///|
/// The task toggle only appears inside a task item, and after the block bucket.
test "markdown_editor_surface_menu_items gates the task toggle" {
  let items = markdown_editor_surface_menu_items(
    target=menu_target(@richtext.Paragraph, None),
    has_selection=false,
    in_task_item=true,
    has_openable_target=false,
  )
  assert_true(menu_has(items, "toggle-task"))
  assert_eq(menu_group(items, "toggle-task"), "task")
  let mut toggle_index = -1
  let mut move_down_index = -1
  let mut indent_index = -1
  for index in 0..<items.length() {
    if items[index].action == "toggle-task" {
      toggle_index = index
    }
    if items[index].action == "move-block-down" {
      move_down_index = index
    }
    if items[index].action == "indent-lines" {
      indent_index = index
    }
  }
  assert_true(toggle_index > move_down_index)
  assert_true(toggle_index < indent_index)
}

///|
/// Menu rows serialize their three fields, so a host can log or snapshot the
/// catalog in tests without reading Rust-side structures.
test "MarkdownMenuItem serializes action label and group" {
  let items = markdown_editor_surface_menu_items(
    target=menu_target(@richtext.Paragraph, None),
    has_selection=false,
    in_task_item=false,
    has_openable_target=false,
  )
  let json = items[0].to_json().stringify()
  assert_true(json.contains("\"action\":\"paragraph\""))
  assert_true(json.contains("\"label\":\"Paragraph\""))
  assert_true(json.contains("\"group\":\"block\""))
}
