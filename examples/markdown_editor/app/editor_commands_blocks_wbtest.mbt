///|
test "markdown editor block command transforms current line" {
  let result = markdown_editor_apply_command_at(
    "Intro\nTitle\nBody",
    Heading(2),
    Some({ caret: 8, selection: None }),
  )
  inspect(result.source, content="Intro\n## Title\nBody")
  inspect(result.caret, content="11")
  let h6 = markdown_editor_apply_command_at(
    "Intro\nFine print\nBody",
    Heading(6),
    Some({ caret: 8, selection: None }),
  )
  inspect(h6.source, content="Intro\n###### Fine print\nBody")
  inspect(h6.caret, content="15")
  let rule = markdown_editor_apply_command_at(
    "Intro\n---\nBody",
    HorizontalRule,
    Some({ caret: 7, selection: None }),
  )
  inspect(rule.source, content="Intro\n---\nBody")
  inspect(rule.caret, content="9")
}

///|
test "markdown editor block command replaces existing marker" {
  let result = markdown_editor_apply_command_at(
    "# Title",
    TaskList,
    Some({ caret: 4, selection: None }),
  )
  inspect(result.source, content="- [ ] Title")
  inspect(result.caret, content="8")
}

///|
test "markdown editor block command toggles same marker off" {
  let heading = markdown_editor_apply_command_at(
    "## Title",
    Heading(2),
    Some({ caret: 4, selection: None }),
  )
  inspect(heading.source, content="Title")
  inspect(heading.caret, content="1")
  let quote = markdown_editor_apply_command_at(
    "> Quote",
    Quote,
    Some({ caret: 4, selection: None }),
  )
  inspect(quote.source, content="Quote")
  inspect(quote.caret, content="2")
}

///|
test "markdown editor paragraph command strips block markers" {
  let heading = markdown_editor_apply_command_at(
    "# Title",
    Paragraph,
    Some({ caret: 4, selection: None }),
  )
  inspect(heading.source, content="Title")
  inspect(heading.caret, content="2")
  let nested = markdown_editor_apply_command_at(
    "  - child",
    Paragraph,
    Some({ caret: 6, selection: None }),
  )
  inspect(nested.source, content="child")
  inspect(nested.caret, content="2")
  let quoted_bullet = markdown_editor_apply_command_at(
    "> - First",
    Paragraph,
    Some({ caret: 9, selection: None }),
  )
  inspect(quoted_bullet.source, content="> First")
  inspect(quoted_bullet.caret, content="7")
  let quoted_ordered = markdown_editor_apply_command_at(
    "> 3. First",
    Paragraph,
    Some({ caret: 10, selection: None }),
  )
  inspect(quoted_ordered.source, content="> First")
  inspect(quoted_ordered.caret, content="7")
  let quoted_heading = markdown_editor_apply_command_at(
    "> # Title",
    Paragraph,
    Some({ caret: 9, selection: None }),
  )
  inspect(quoted_heading.source, content="> Title")
  inspect(quoted_heading.caret, content="7")
  let nested_quoted = markdown_editor_apply_command_at(
    "> > - First",
    Paragraph,
    Some({ caret: 11, selection: None }),
  )
  inspect(nested_quoted.source, content="> > First")
  inspect(nested_quoted.caret, content="9")
  let lines = markdown_editor_apply_command_at(
    "- one\n> two\n3. three",
    Paragraph,
    Some({ caret: 18, selection: Some(@core.TextRange::new(start=0, end=20)) }),
  )
  inspect(lines.source, content="one\ntwo\nthree")
  let quoted_lines_source = "Intro\n> - First\n> 9. Second\n> # Third\nTail"
  let quoted_lines_end = markdown_editor_text_length(
    "Intro\n> - First\n> 9. Second\n> # Third",
  )
  let quoted_lines = markdown_editor_apply_command_at(
    quoted_lines_source,
    Paragraph,
    Some({
      caret: quoted_lines_end,
      selection: Some(@core.TextRange::new(start=6, end=quoted_lines_end)),
    }),
  )
  inspect(
    quoted_lines.source,
    content="Intro\n> First\n> Second\n> Third\nTail",
  )
}

///|
test "markdown editor block command transforms setext heading blocks" {
  let paragraph = markdown_editor_apply_command_at(
    "Intro\nTitle\n---\nTail",
    Paragraph,
    Some({ caret: 8, selection: None }),
  )
  inspect(paragraph.source, content="Intro\nTitle\nTail")
  inspect(paragraph.caret, content="8")
  let heading = markdown_editor_apply_command_at(
    "Intro\nTitle\n---\nTail",
    Heading(3),
    Some({ caret: 8, selection: None }),
  )
  inspect(heading.source, content="### Intro Title\nTail")
  inspect(heading.caret, content="12")
  let quote = markdown_editor_apply_command_at(
    "Intro\nTitle\n=====\nTail",
    Quote,
    Some({ caret: 8, selection: None }),
  )
  inspect(quote.source, content="> Intro\n> Title\nTail")
}

///|
test "markdown editor reports active block label" {
  let source = "# Title\n- item\n> quote\n```\ncode\n```"
  inspect(
    markdown_editor_active_block_label(source, { caret: 3, selection: None }),
    content="Heading 1",
  )
  inspect(
    markdown_editor_active_block_label(source, { caret: 10, selection: None }),
    content="Bullet list",
  )
  inspect(
    markdown_editor_active_block_label(source, { caret: 18, selection: None }),
    content="Quote",
  )
  inspect(
    markdown_editor_active_block_label(source, { caret: 29, selection: None }),
    content="Code block",
  )
  inspect(
    markdown_editor_active_block_label("# Title\nBody", {
      caret: 7,
      selection: None,
    }),
    content="Heading 1",
  )
  inspect(
    markdown_editor_active_block_label("- item\nBody", {
      caret: 6,
      selection: None,
    }),
    content="Bullet list",
  )
}

///|
test "markdown editor app block command uses tracked caret" {
  let app = MarkdownEditorApp::new()
  app.set_document("Intro\nTitle")
  app.set_selection(8, None)
  app.apply_command_to_selection(Quote)
  inspect(app.document(), content="Intro\n> Title")
}

///|
test "markdown editor block command appends snippet without caret context" {
  let result = markdown_editor_apply_command_at("Base", Heading(1), None)
  inspect(result.source, content="Base\n\n# Heading")
}
