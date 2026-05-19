///|
test "markdown editor app emits wysiwyg and source commands" {
  let app = @app.MarkdownEditorApp::new()
  let commands = app.runtime(width=980.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "MoUI Markdown", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::DrawText(
        { text: "Editor notes", font: { weight: 700, .. }, .. }
      )
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "• ", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Markdown source", .. })
    }),
  )
}

///|
test "markdown parser recognizes supported block and inline subset" {
  let blocks = parse_markdown(
    "# Title\n## Section\nText with **bold** and *italic* and `code`\n- bullet\n1. one\n> quote\n---\n```\ncode\n```",
  )
  inspect(blocks.length(), content="8")
  guard blocks[0].kind is Heading(1) else { fail("expected h1") }
  guard blocks[1].kind is Heading(2) else { fail("expected h2") }
  guard blocks[2].kind is Paragraph else { fail("expected paragraph") }
  assert_true(
    blocks[2].inlines.any(span => span.kind == MarkdownInlineKind::Bold),
  )
  assert_true(
    blocks[2].inlines.any(span => span.kind == MarkdownInlineKind::Italic),
  )
  assert_true(
    blocks[2].inlines.any(span => span.kind == MarkdownInlineKind::Code),
  )
  guard blocks[3].kind is UnorderedListItem else {
    fail("expected unordered list")
  }
  guard blocks[4].kind is OrderedListItem(1) else {
    fail("expected ordered list")
  }
  guard blocks[5].kind is Blockquote else { fail("expected quote") }
  guard blocks[6].kind is HorizontalRule else { fail("expected rule") }
  guard blocks[7].kind is CodeBlock else { fail("expected code block") }
}

///|
test "markdown parser preserves unsupported and malformed inline syntax as plain text" {
  let blocks = parse_markdown(
    "### Three\nText with **open and `dangling\n+ plus list",
  )
  inspect(blocks.length(), content="3")
  guard blocks[0].kind is Paragraph else {
    fail("expected unsupported h3 as paragraph")
  }
  inspect(blocks[0].text, content="### Three")
  guard blocks[1].kind is Paragraph else {
    fail("expected malformed inline paragraph")
  }
  inspect(blocks[1].inlines.length(), content="1")
  guard blocks[1].inlines[0] is { kind: MarkdownInlineKind::Plain, text } else {
    fail("expected plain malformed inline text")
  }
  inspect(text, content="Text with **open and `dangling")
  guard blocks[2].kind is Paragraph else {
    fail("expected plus list to stay paragraph")
  }
}

///|
test "markdown parser handles blank lines and unterminated code blocks" {
  let blocks = parse_markdown("\n\n```\nlet x = 1")
  inspect(blocks.length(), content="1")
  guard blocks[0].kind is CodeBlock else {
    fail("expected trailing code block")
  }
  inspect(blocks[0].text, content="let x = 1")
}

///|
test "markdown parser recognizes star bullets and ordered list numbers" {
  let blocks = parse_markdown("* star\n42. answer")
  inspect(blocks.length(), content="2")
  guard blocks[0].kind is UnorderedListItem else {
    fail("expected star bullet")
  }
  guard blocks[1].kind is OrderedListItem(42) else {
    fail("expected ordered list number")
  }
  inspect(blocks[1].text, content="answer")
}

///|
test "markdown inline parser emits separated plain and styled spans" {
  let spans = parse_markdown_inlines("a **b** c `d` *e*")
  inspect(spans.length(), content="6")
  guard spans[0] is { kind: MarkdownInlineKind::Plain, text: "a " } else {
    fail("expected leading plain span")
  }
  guard spans[1] is { kind: MarkdownInlineKind::Bold, text: "b" } else {
    fail("expected bold span")
  }
  guard spans[3] is { kind: MarkdownInlineKind::Code, text: "d" } else {
    fail("expected code span")
  }
  guard spans[5] is { kind: MarkdownInlineKind::Italic, text: "e" } else {
    fail("expected italic span")
  }
}

///|
test "markdown formatter produces rich text blocks and styled runs" {
  let document = markdown_to_rich_text(
    "# Title\n- item\n> quote\n```\ncode\n```\n---",
  )
  inspect(document.blocks.length(), content="5")
  inspect(document.blocks[0].runs[0].text, content="Title")
  inspect(document.blocks[0].runs[0].font.unwrap().weight, content="700")
  inspect(document.blocks[1].prefix, content="• ")
  assert_true(document.blocks[2].border_left is Some(_))
  assert_true(document.blocks[3].background is Some(_))
  assert_true(document.blocks[4].rule)
}

///|
test "markdown editor toolbar actions update canonical markdown" {
  let app = @app.MarkdownEditorApp::new()
  app.clear()
  app.apply_action("h1")
  inspect(app.document(), content="# Heading")
  app.apply_action("bold")
  assert_true(app.document().contains("**bold text**"))
}

///|
test "markdown editor toolbar seeds every supported action from empty document" {
  for
    expected in [
      "**bold text**", "*italic text*", "`code`", "# Heading", "## Section", "- List item",
      "1. List item", "> Quote", "```\ncode block\n```",
    ] {
    let app = @app.MarkdownEditorApp::new()
    app.clear()
    app.apply_action(markdown_action_from_seed(expected))
    inspect(app.document(), content=expected)
  }
}

///|
test "markdown editor toolbar appends every supported action to existing document" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("Base")
  for
    action in [
      "bold", "italic", "code", "h1", "h2", "ul", "ol", "quote", "codeblock",
    ] {
    app.apply_action(action)
  }
  let document = app.document()
  assert_true(document.contains("Base\n\n**bold text**"))
  assert_true(document.contains("*italic text*"))
  assert_true(document.contains("`code`"))
  assert_true(document.contains("# Heading"))
  assert_true(document.contains("## Section"))
  assert_true(document.contains("- List item"))
  assert_true(document.contains("1. List item"))
  assert_true(document.contains("> Quote"))
  assert_true(document.contains("```\ncode block\n```"))
  app.apply_action("unknown")
  inspect(app.document(), content=document)
}

///|
fn markdown_action_from_seed(expected : String) -> String {
  if expected == "**bold text**" {
    "bold"
  } else if expected == "*italic text*" {
    "italic"
  } else if expected == "`code`" {
    "code"
  } else if expected == "# Heading" {
    "h1"
  } else if expected == "## Section" {
    "h2"
  } else if expected == "- List item" {
    "ul"
  } else if expected == "1. List item" {
    "ol"
  } else if expected == "> Quote" {
    "quote"
  } else {
    "codeblock"
  }
}

///|
test "markdown editor runtime typing updates document" {
  let app = @app.MarkdownEditorApp::new()
  app.clear()
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=32.0, y=160.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("# Hi")),
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
test "markdown editor clear redraws placeholder and empty source preview" {
  let app = @app.MarkdownEditorApp::new()
  let runtime = app.runtime(width=980.0, height=640.0)
  app.clear()
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let commands = runtime.draw_commands()
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::DrawText({ text: "Start writing Markdown", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "(empty)", .. })
    }),
  )
}
