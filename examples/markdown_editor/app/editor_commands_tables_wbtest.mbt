///|
test "markdown editor enter completes pipe table header" {
  let completed = markdown_editor_transform_input("Name | Done", 11, None, "\n").unwrap()
  inspect(completed.text, content="Name | Done\n| --- | --- |\n|  |  |")
  inspect(completed.caret, content="28")
  let placeholder = markdown_editor_transform_input(
    "| Name | |",
    10,
    None,
    "\n",
  ).unwrap()
  inspect(placeholder.text, content="| Name | |\n| --- | --- |\n|  |  |")
  inspect(placeholder.caret, content="27")
  inspect(
    markdown_editor_transform_input("Name | ", 7, None, "\n") is None,
    content="true",
  )
}

///|
test "markdown editor enter inserts table row below current cell" {
  let source = "| A | B |\n| --- | --- |\n| 1 | 2 |"
  let inserted = markdown_editor_transform_input(source, 30, None, "\n").unwrap()
  inspect(inserted.text, content="| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |")
  inspect(inserted.caret, content="39")
  let middle = markdown_editor_transform_input(source, 26, None, "\n").unwrap()
  inspect(middle.text, content="| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |")
  inspect(middle.caret, content="36")
  let header = markdown_editor_transform_input(source, 6, None, "\n").unwrap()
  inspect(header.text, content="| A | B |\n| --- | --- |\n|  |  |\n| 1 | 2 |")
  inspect(header.caret, content="29")
}

///|
test "markdown editor command inserts table row below current cell" {
  let source = "| A | B |\n| --- | --- |\n| 1 | 2 |"
  let inserted = markdown_editor_apply_command_at(
    source,
    InsertTableRow,
    Some({ caret: 30, selection: None }),
  )
  inspect(
    inserted.source,
    content="| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |",
  )
  inspect(inserted.caret, content="39")
  let header = markdown_editor_apply_command_at(
    source,
    InsertTableRow,
    Some({ caret: 6, selection: None }),
  )
  inspect(header.source, content="| A | B |\n| --- | --- |\n|  |  |\n| 1 | 2 |")
  inspect(header.caret, content="29")
}

///|
test "markdown editor command inserts table column after current cell" {
  let source = "| A | B |\n| --- | --- |\n| 1 | 2 |"
  let inserted = markdown_editor_apply_command_at(
    source,
    InsertTableColumn,
    Some({ caret: 30, selection: None }),
  )
  inspect(
    inserted.source,
    content="| A | B |  |\n| --- | --- | --- |\n| 1 | 2 |  |",
  )
  inspect(inserted.caret, content="35")
  let middle = markdown_editor_apply_command_at(
    source,
    InsertTableColumn,
    Some({ caret: 26, selection: None }),
  )
  inspect(
    middle.source,
    content="| A |  | B |\n| --- | --- | --- |\n| 1 |  | 2 |",
  )
  inspect(middle.caret, content="31")
}

///|
test "markdown editor table column edits preserve alignment markers" {
  let source = "| A | B | C |\n| :--- | :---: | ---: |\n| 1 | 2 | 3 |"
  let inserted = markdown_editor_apply_command_at(
    source,
    InsertTableColumn,
    Some({ caret: 44, selection: None }),
  )
  inspect(
    inserted.source,
    content="| A | B |  | C |\n| :--- | :---: | --- | ---: |\n| 1 | 2 |  | 3 |",
  )
  let deleted = markdown_editor_apply_command_at(
    source,
    DeleteTableColumn,
    Some({ caret: 44, selection: None }),
  )
  inspect(deleted.source, content="| A | C |\n| :--- | ---: |\n| 1 | 3 |")
}

///|
test "markdown editor command sets table column alignment" {
  let source = "| A | B | C |\n| --- | :---: | ---: |\n| 1 | 2 | 3 |"
  let centered = markdown_editor_apply_command_at(
    source,
    SetTableColumnAlignment(Some(@core.TextAlign::TextCenter)),
    Some({ caret: 48, selection: None }),
  )
  inspect(
    centered.source,
    content="| A | B | C |\n| --- | :---: | :---: |\n| 1 | 2 | 3 |",
  )
  inspect(centered.caret, content="47")
  let auto = markdown_editor_apply_command_at(
    centered.source,
    SetTableColumnAlignment(None),
    Some({ caret: 48, selection: None }),
  )
  inspect(
    auto.source,
    content="| A | B | C |\n| --- | :---: | --- |\n| 1 | 2 | 3 |",
  )
  let snapshot = MarkdownEditorSnapshot::parse(auto.source)
  guard snapshot.rich_text.blocks[0].table is Some(table) else {
    fail("expected table preview")
  }
  guard table.rows[0][1].align is Some(@core.TextAlign::TextCenter) else {
    fail("expected center alignment to remain")
  }
  guard table.rows[0][2].align is None else {
    fail("expected cleared alignment")
  }
  let plain = markdown_editor_apply_command_at(
    "Plain text",
    SetTableColumnAlignment(Some(@core.TextAlign::TextEnd)),
    Some({ caret: 5, selection: None }),
  )
  inspect(plain.source, content="Plain text")
  inspect(plain.caret, content="5")
  let selected = markdown_editor_apply_command_at(
    "Plain text",
    SetTableColumnAlignment(Some(@core.TextAlign::TextCenter)),
    Some({ caret: 5, selection: Some(@core.TextRange::new(start=0, end=5)) }),
  )
  inspect(selected.source, content="Plain text")
}

///|
test "markdown editor app action sets table column alignment" {
  let app = MarkdownEditorApp::new()
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  app.set_selection(30, None)
  app.apply_action("table-align-right")
  inspect(app.document(), content="| A | B |\n| --- | ---: |\n| 1 | 2 |")
  app.apply_action("table-align-auto")
  inspect(app.document(), content="| A | B |\n| --- | --- |\n| 1 | 2 |")
}

///|
test "markdown editor table row and column commands no-op outside tables" {
  let source = "Plain text"
  let row = markdown_editor_apply_command_at(
    source,
    InsertTableRow,
    Some({ caret: 5, selection: None }),
  )
  inspect(row.source, content=source)
  inspect(row.caret, content="5")
  let column = markdown_editor_apply_command_at(
    source,
    InsertTableColumn,
    Some({ caret: 5, selection: None }),
  )
  inspect(column.source, content=source)
  inspect(column.caret, content="5")
  let delete_row = markdown_editor_apply_command_at(
    source,
    DeleteTableRow,
    Some({ caret: 5, selection: None }),
  )
  inspect(delete_row.source, content=source)
  inspect(delete_row.caret, content="5")
  let delete_column = markdown_editor_apply_command_at(
    source,
    DeleteTableColumn,
    Some({ caret: 5, selection: None }),
  )
  inspect(delete_column.source, content=source)
  inspect(delete_column.caret, content="5")

  let selected = markdown_editor_apply_command_at(
    source,
    InsertTableRow,
    Some({ caret: 5, selection: Some(@core.TextRange::new(start=0, end=5)) }),
  )
  inspect(selected.source, content=source)
  guard selected.selection is Some(selection) else {
    fail("expected unchanged selection")
  }
  inspect(selection.start, content="0")
  inspect(selection.end, content="5")

  let without_context = markdown_editor_apply_command_at(
    source,
    InsertTableColumn,
    None,
  )
  inspect(without_context.source, content=source)
  inspect(without_context.caret, content="10")
}

///|
test "markdown editor command deletes current table row" {
  let source = "| A | B |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |"
  let cleared_header = markdown_editor_apply_command_at(
    source,
    DeleteTableRow,
    Some({ caret: 6, selection: None }),
  )
  inspect(
    cleared_header.source,
    content="|  |  |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |",
  )
  inspect(cleared_header.caret, content="2")
  let deleted = markdown_editor_apply_command_at(
    source,
    DeleteTableRow,
    Some({ caret: 30, selection: None }),
  )
  inspect(deleted.source, content="| A | B |\n| --- | --- |\n| 3 | 4 |")
  inspect(deleted.caret, content="23")
  let cleared = markdown_editor_apply_command_at(
    "| A | B |\n| --- | --- |\n| 1 | 2 |",
    DeleteTableRow,
    Some({ caret: 30, selection: None }),
  )
  inspect(cleared.source, content="| A | B |\n| --- | --- |\n|  |  |")
  inspect(cleared.caret, content="26")
}

///|
test "markdown editor command deletes current table column" {
  let source = "| A | B | C |\n| --- | --- | --- |\n| 1 | 2 | 3 |"
  let deleted = markdown_editor_apply_command_at(
    source,
    DeleteTableColumn,
    Some({ caret: 40, selection: None }),
  )
  inspect(deleted.source, content="| A | C |\n| --- | --- |\n| 1 | 3 |")
  inspect(deleted.caret, content="2")
  let cleared = markdown_editor_apply_command_at(
    "| A |\n| --- |\n| 1 |",
    DeleteTableColumn,
    Some({ caret: 16, selection: None }),
  )
  inspect(cleared.source, content="|  |\n| --- |\n|  |")
  inspect(cleared.caret, content="3")
}

///|
