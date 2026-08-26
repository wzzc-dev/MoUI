///|
test "markdown editor actions update canonical markdown" {
  let app = MarkdownEditorApp::new()
  app.clear()
  app.apply_action("h1")
  inspect(app.document(), content="# Heading")
  app.clear()
  app.apply_action("h6")
  inspect(app.document(), content="###### Caption")
  app.clear()
  app.apply_action("bold")
  assert_true(app.document().contains("**bold text**"))
  app.apply_action("strike")
  assert_true(app.document().contains("~~old text~~"))
  app.apply_action("link")
  assert_true(app.document().contains("[link text](https://example.com)"))
  app.apply_action("link-target")
  assert_true(app.document().contains("[link text](https://wzzc-dev.github.io/MoUI)"))
  app.apply_action("image")
  assert_true(app.document().contains("![image alt](image.png)"))
  app.apply_action("image-target")
  assert_true(app.document().contains("![image alt](assets/image.png)"))
  app.apply_action("code-language")
  assert_true(app.document().contains("```moonbit\ncode block\n```"))
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  app.set_selection(30, None)
  app.apply_action("table-row")
  inspect(
    app.document(),
    content="| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |",
  )
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  app.set_selection(30, None)
  app.apply_action("table-column")
  inspect(
    app.document(),
    content="| A | B |  |\n| --- | --- | --- |\n| 1 | 2 |  |",
  )
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |")
  app.set_selection(30, None)
  app.apply_action("table-row-delete")
  inspect(app.document(), content="| A | B |\n| --- | --- |\n| 3 | 4 |")
  app.set_document("| A | B | C |\n| --- | --- | --- |\n| 1 | 2 | 3 |")
  app.set_selection(40, None)
  app.apply_action("table-column-delete")
  inspect(app.document(), content="| A | C |\n| --- | --- |\n| 1 | 3 |")
  app.set_document("# Heading")
  app.set_selection(4, None)
  app.apply_action("paragraph")
  inspect(app.document(), content="Heading")
}

///|
test "markdown editor actions seed every supported action from empty document" {
  for
    expected in [
      "**bold text**", "*italic text*", "`code`", "~~old text~~", "[link text](https://example.com)",
      "[link text](https://wzzc-dev.github.io/MoUI)", "![image alt](image.png)", "![image alt](assets/image.png)",
      "Paragraph", "# Heading", "## Section", "### Detail", "#### Subdetail", "##### Note",
      "###### Caption", "- List item", "- [ ] Task item", "1. List item", "> Quote",
      "---", "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |", "```\ncode block\n```",
    ] {
    let app = MarkdownEditorApp::new()
    app.clear()
    app.apply_action(markdown_action_from_seed(expected))
    inspect(app.document(), content=expected)
  }
}

///|
test "markdown editor actions apply actions at current caret context" {
  let app = MarkdownEditorApp::new()
  app.set_document("Base")
  for
    action in [
      "bold", "italic", "code", "strike", "link", "image", "h1", "h2", "h3", "h4",
      "h5", "h6", "ul", "task", "ol", "quote", "codeblock",
    ] {
    app.apply_action(action)
  }
  let document = app.document()
  inspect(
    document,
    content="Base\n\n**bold text**\n\n*italic text*\n\n`code`\n\n~~old text~~\n\n[link text](https://example.com)\n\n> ```\n> ![image alt](image.png)\n> ```",
  )
  app.apply_action("unknown")
  inspect(app.document(), content=document)
}

///|
test "markdown editor document context menu includes app commands" {
  let commands = markdown_editor_program_commands()
    .map(command => command.command())
    .filter(command => command.context_menu)
  for
    label in [
      "Toggle Source Mode", "Toggle Quick Format", "Cycle Writing Look", "Insert Table of Contents",
      "Insert YAML Front Matter", "Toggle Outline", "Toggle Files", "Toggle Document Info",
      "Toggle Focus Mode", "Next Heading", "Open Target", "Bold", "Italic", "Paragraph",
      "Heading 1", "Bullet List", "Insert Table Row", "Table Align Center",
    ] {
    assert_true(commands.any(command => command.display_label() == label))
  }
}

///|
fn markdown_action_from_seed(expected : String) -> String {
  if expected == "**bold text**" {
    "bold"
  } else if expected == "*italic text*" {
    "italic"
  } else if expected == "`code`" {
    "code"
  } else if expected == "~~old text~~" {
    "strike"
  } else if expected == "[link text](https://example.com)" {
    "link"
  } else if expected == "[link text](https://wzzc-dev.github.io/MoUI)" {
    "link-target"
  } else if expected == "![image alt](image.png)" {
    "image"
  } else if expected == "![image alt](assets/image.png)" {
    "image-target"
  } else if expected == "Paragraph" {
    "paragraph"
  } else if expected == "# Heading" {
    "h1"
  } else if expected == "## Section" {
    "h2"
  } else if expected == "### Detail" {
    "h3"
  } else if expected == "#### Subdetail" {
    "h4"
  } else if expected == "##### Note" {
    "h5"
  } else if expected == "###### Caption" {
    "h6"
  } else if expected == "- List item" {
    "ul"
  } else if expected == "- [ ] Task item" {
    "task"
  } else if expected == "1. List item" {
    "ol"
  } else if expected == "> Quote" {
    "quote"
  } else if expected == "---" {
    "rule"
  } else if expected ==
    "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |" {
    "table"
  } else {
    "codeblock"
  }
}

///|
test "markdown editor runtime typing updates document" {
  let app = MarkdownEditorApp::new()
  app.clear()
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=6.0),
          y=84.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("#")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText(" ")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("Hi")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("- item")),
  )
  inspect(app.document(), content="# Hi\n- item")
}

///|
test "markdown editor runtime enter completes fenced code block" {
  let app = MarkdownEditorApp::new()
  app.clear()
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=6.0),
          y=84.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("```moonbit")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  inspect(app.document(), content="```moonbit\n\n```")
  inspect(runtime.focused_text_input().caret, content="11")
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("let x = 1")),
  )
  inspect(app.document(), content="```moonbit\nlet x = 1\n```")
}

///|
test "markdown editor clear redraws placeholder and optional empty source preview" {
  let app = MarkdownEditorApp::new()
  app.clear()
  let mut runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let commands = runtime.draw_commands()
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::DrawText({ text: "Start writing Markdown", .. })
    }),
  )
  assert_false(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "(empty)", .. })
    }),
  )
  app.set_source_preview_visible(true)
  runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let source_commands = runtime.draw_commands()
  assert_true(
    source_commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "(empty)", .. })
    }),
  )
}
