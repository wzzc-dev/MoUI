test "markdown editor snapshot tracks typora core document shape" {
  let snapshot = MarkdownEditorSnapshot::parse(
    "# Title\n\nParagraph with **bold**\n- [x] done\n```\nlet x = 1\n```",
  )
  inspect(snapshot.active_heading, content="Title")
  inspect(snapshot.line_count, content="7")
  inspect(snapshot.blocks.length(), content="5")
  guard snapshot.blocks[0]
    is {
      block: { kind: Heading(1), text: "Title", .. },
      source_range: { start: 0, end: 7 },
      content_range: { start: 2, end: 7 },
    } else {
    fail("expected heading source mapping")
  }
  guard snapshot.blocks[1]
    is {
      block: { kind: Paragraph, text: "", inlines: [], .. },
      source_range: { start: 8, end: 8 },
      content_range: { start: 8, end: 8 },
    } else {
    fail("expected visible blank line mapping")
  }
  guard snapshot.blocks[3]
    is {
      block: { kind: TaskListItem(true), text: "done", .. },
      content_range: { start, end },
      ..,
    } else {
    fail("expected task block mapping")
  }
  inspect(start, content="39")
  inspect(end, content="43")
  guard snapshot.blocks[4].block.kind is CodeBlock else {
    fail("expected fenced code block")
  }
  inspect(snapshot.rich_text.blocks.length(), content="5")
}

///|
test "markdown editor snapshot tracks tilde fenced code blocks" {
  let snapshot = MarkdownEditorSnapshot::parse("~~~moonbit\nlet x = 1\n~~~~")
  inspect(snapshot.blocks.length(), content="1")
  guard snapshot.blocks[0]
    is {
      block: {
        kind: CodeBlock,
        text: "let x = 1",
        code_language: Some("moonbit"),
        ..,
      },
      source_range: { start: 0, end: 25 },
      content_range: { start: 11, end: 21 },
    } else {
    fail("expected tilde fenced code block")
  }
}

///|
test "markdown editor snapshot tracks yaml front matter" {
  let snapshot = MarkdownEditorSnapshot::parse(
    "---\ntitle: Draft\ntags: [moui]\n---\n\n# Body",
  )
  inspect(snapshot.active_heading, content="Body")
  inspect(snapshot.blocks.length(), content="3")
  guard snapshot.blocks[0]
    is {
      block: { kind: FrontMatter, text: "title: Draft\ntags: [moui]", .. },
      source_range: { start: 0, end: 33 },
      content_range: { start: 4, end: 30 },
    } else {
    fail("expected front matter source mapping")
  }
  guard snapshot.blocks[2]
    is { block: { kind: Heading(1), text: "Body", .. }, .. } else {
    fail("expected heading after front matter")
  }
  inspect(
    snapshot.rich_text.blocks[0].runs[0].text,
    content="title: Draft\ntags: [moui]",
  )
}

///|
test "markdown editor snapshot resolves reference links and images" {
  let snapshot = MarkdownEditorSnapshot::parse(
    "See [MoUI][site] and ![Logo][logo]\n\n[site]: https://moui.dev\n[logo]: assets/logo.png",
  )
  inspect(snapshot.blocks.length(), content="2")
  guard snapshot.blocks[0].block.inlines[1]
    is {
      kind: MarkdownInlineKind::Link,
      text: "MoUI",
      target: Some("https://moui.dev"),
    } else {
    fail("expected resolved reference link")
  }
  guard snapshot.blocks[0].block.inlines[3]
    is {
      kind: MarkdownInlineKind::Image,
      text: "Logo",
      target: Some("assets/logo.png"),
    } else {
    fail("expected resolved reference image")
  }
  guard snapshot.rich_text.blocks[0].runs[1]
    is { text: "MoUI", font: Some({ weight: 500, .. }), .. } else {
    fail("expected styled rich link")
  }
  guard snapshot.rich_text.blocks[0].runs[3]
    is { image_source: Some("assets/logo.png"), .. } else {
    fail("expected rich image source")
  }
}

///|
test "markdown editor snapshot tracks footnotes" {
  let snapshot = MarkdownEditorSnapshot::parse(
    "Paragraph with note[^1].\n\n[^1]: Footnote body",
  )
  inspect(snapshot.blocks.length(), content="3")
  guard snapshot.blocks[0].block.inlines[1]
    is { kind: MarkdownInlineKind::FootnoteReference, text: "1", .. } else {
    fail("expected footnote reference inline")
  }
  guard snapshot.blocks[2]
    is {
      block: {
        kind: FootnoteDefinition("1"),
        text: "Footnote body",
        inlines: [{ text: "Footnote body", .. }],
        ..,
      },
      source_range: { start: 26, end: 45 },
      content_range: { start: 32, end: 45 },
    } else {
    fail("expected footnote definition mapping")
  }
  guard snapshot.rich_text.blocks[0].runs[1]
    is {
      text: "[^1]",
      visual_text: Some("1"),
      source_range: Some({ start: 19, end: 23 }),
      ..,
    } else {
    fail("expected rich footnote reference marker")
  }
  guard snapshot.rich_text.blocks[2]
    is {
      border_left: Some(_),
      runs: [
        {
          visual_text: Some("1"),
          source_range: Some({ start: 26, end: 32 }),
          ..,
        },
        {
          text: "Footnote body",
          source_range: Some({ start: 32, end: 45 }),
          ..,
        },
      ],
      ..,
    } else {
    fail("expected rich footnote definition")
  }
}

///|
test "markdown editor snapshot tracks long fenced code blocks" {
  let snapshot = MarkdownEditorSnapshot::parse("````moonbit\n```\n````")
  inspect(snapshot.blocks.length(), content="1")
  guard snapshot.blocks[0]
    is {
      block: {
        kind: CodeBlock,
        text: "```",
        code_language: Some("moonbit"),
        ..,
      },
      source_range: { start: 0, end: 20 },
      content_range: { start: 12, end: 16 },
    } else {
    fail("expected long fenced code block")
  }
  inspect(snapshot.rich_text.blocks.length(), content="1")
  guard snapshot.rich_text.blocks[0].runs
    is [{ text: "moonbit", .. }, { text: "\n", .. }, { text: "```", .. }] else {
    fail("expected language label before code content")
  }
}

///|
test "markdown editor snapshot preserves code block blank lines" {
  let snapshot = MarkdownEditorSnapshot::parse("```moonbit\nlet x = 1\n\n```")
  inspect(snapshot.blocks.length(), content="1")
  guard snapshot.blocks[0].block.kind is CodeBlock else {
    fail("expected code block")
  }
  inspect(snapshot.blocks[0].block.text, content="let x = 1\n")
  inspect(snapshot.blocks[0].content_range.start, content="11")
  inspect(snapshot.blocks[0].content_range.end, content="22")
  guard snapshot.rich_text.blocks[0].runs
    is [
      { text: "moonbit", .. },
      { text: "\n", .. },
      { text: "let x = 1\n", .. },
    ] else {
    fail("expected blank code line in rich text")
  }
  inspect(
    @moui_richtext.rich_text_document_height(
      snapshot.rich_text,
      @core.FontSpec::new(),
    ).to_int(),
    content="68",
  )
}

///|
test "markdown editor snapshot preserves visible empty paragraph lines" {
  inspect(MarkdownEditorSnapshot::parse("").blocks.length(), content="0")
  let snapshot = MarkdownEditorSnapshot::parse("Title\n\nBody\n")
  inspect(snapshot.line_count, content="4")
  inspect(snapshot.blocks.length(), content="4")
  guard snapshot.blocks[1]
    is {
      block: { kind: Paragraph, text: "", inlines: [], .. },
      source_range: { start: 6, end: 6 },
      content_range: { start: 6, end: 6 },
    } else {
    fail("expected middle blank line block")
  }
  guard snapshot.blocks[3]
    is {
      block: { kind: Paragraph, text: "", inlines: [], .. },
      source_range: { start: 12, end: 12 },
      content_range: { start: 12, end: 12 },
    } else {
    fail("expected trailing blank line block")
  }
  inspect(snapshot.word_count, content="2")
  inspect(snapshot.rich_text.blocks.length(), content="4")
  guard snapshot.rich_text.blocks[1]
    is {
      runs: [],
      source_range: Some({ start: 6, end: 6 }),
      content_range: Some({ start: 6, end: 6 }),
      ..,
    } else {
    fail("expected visible rich text block for middle blank line")
  }
  inspect(
    @moui_richtext.rich_text_document_height(
      snapshot.rich_text,
      @core.FontSpec::new(),
    ).to_int(),
    content="99",
  )
}

///|
test "markdown editor caret geometry lands on inserted blank line" {
  let content = @core.Rect::new(x=10.0, y=20.0, width=320.0, height=160.0)
  let font = @core.FontSpec::new(size=16.0)
  let heading = markdown_editor_format("# Title\n")
  guard @moui_richtext.rich_text_document_caret_rect_at_source(
      heading, 8, content, font,
    )
    is Some(heading_blank) else {
    fail("expected heading blank-line caret rect")
  }
  let paragraph = markdown_editor_format("Body\n")
  guard @moui_richtext.rich_text_document_caret_rect_at_source(
      paragraph, 5, content, font,
    )
    is Some(paragraph_blank) else {
    fail("expected paragraph blank-line caret rect")
  }
  inspect(heading.blocks.length(), content="2")
  inspect(paragraph.blocks.length(), content="2")
  assert_true(heading_blank.origin.y > content.origin.y + 20.0)
  inspect(paragraph_blank.origin.y.to_int(), content="48")
}

///|
test "markdown editor snapshot tracks setext headings" {
  let snapshot = MarkdownEditorSnapshot::parse("Title\n=====\nSection\n---")
  inspect(snapshot.blocks.length(), content="2")
  guard snapshot.blocks[0]
    is {
      block: { kind: Heading(1), text: "Title", .. },
      source_range: { start: 0, end: 11 },
      content_range: { start: 0, end: 5 },
    } else {
    fail("expected setext h1 mapping")
  }
  guard snapshot.blocks[1]
    is {
      block: { kind: Heading(2), text: "Section", .. },
      source_range: { start: 12, end: 23 },
      content_range: { start: 12, end: 19 },
    } else {
    fail("expected setext h2 mapping")
  }
  inspect(snapshot.active_heading, content="Title")
  inspect(snapshot.outline.length(), content="2")
  inspect(snapshot.outline[0].level, content="1")
  inspect(snapshot.outline[0].title, content="Title")
  inspect(snapshot.outline[0].source_start, content="0")
  inspect(snapshot.outline[1].level, content="2")
  inspect(snapshot.outline[1].title, content="Section")
  inspect(snapshot.outline[1].source_start, content="12")
  inspect(snapshot.rich_text.blocks.length(), content="2")
}

///|
test "markdown editor snapshot estimates reading time" {
  inspect(MarkdownEditorSnapshot::parse("").reading_minutes, content="0")
  inspect(MarkdownEditorSnapshot::parse("one two").reading_minutes, content="1")
  let words : Array[String] = []
  for index in 0..<221 {
    words.push("w" + index.to_string())
  }
  inspect(
    MarkdownEditorSnapshot::parse(words.join(" ")).reading_minutes,
    content="2",
  )
}

///|
test "markdown editor snapshot tracks markdown tables" {
  let source = "| Name | Done |\n| :--- | ---: |\n| Core | yes |"
  let snapshot = MarkdownEditorSnapshot::parse(source)
  inspect(snapshot.blocks.length(), content="1")
  guard snapshot.blocks[0].block.kind is Table else {
    fail("expected table block")
  }
  inspect(snapshot.blocks[0].block.text, content="Name  |  Done\nCore  |  yes")
  inspect(snapshot.blocks[0].source_range.start, content="0")
  inspect(snapshot.blocks[0].source_range.end, content="46")
  inspect(snapshot.blocks[0].content_range.start, content="0")
  inspect(snapshot.blocks[0].content_range.end, content="46")
  inspect(snapshot.rich_text.blocks.length(), content="1")
  guard snapshot.rich_text.blocks[0].runs
    is [{ text: "Name  |  Done\nCore  |  yes", .. }] else {
    fail("expected visual table text")
  }
  guard snapshot.rich_text.blocks[0].table is Some(table) else {
    fail("expected table preview")
  }
  inspect(table.rows.length(), content="2")
  inspect(table.rows[0].length(), content="2")
  inspect(table.rows[1].length(), content="2")
  inspect(table.rows[0][0].text, content="Name")
  inspect(table.rows[0][0].header, content="true")
  guard table.rows[0][0].align is None else {
    fail("expected default start alignment")
  }
  guard table.rows[0][1].align is Some(@core.TextAlign::TextEnd) else {
    fail("expected trailing alignment")
  }
  guard table.rows[0][0].source_range is Some(first_range) else {
    fail("expected first table cell source range")
  }
  inspect(first_range.start, content="2")
  inspect(first_range.end, content="6")
  inspect(table.rows[1][0].text, content="Core")
  inspect(table.rows[1][0].header, content="false")
  guard table.rows[1][0].source_range is Some(body_range) else {
    fail("expected body table cell source range")
  }
  inspect(body_range.start, content="34")
  inspect(body_range.end, content="38")
  inspect(
    markdown_editor_active_block_label(source, { caret: 18, selection: None }),
    content="Table",
  )
}

///|
test "markdown editor renders table grid preview" {
  let app = MarkdownEditorApp::new()
  app.set_document("| Name | Done |\n| :---: | ---: |\n| Core | yes |")
  let runtime = app.runtime(width=980.0, height=640.0)
  let commands = runtime.draw_commands()
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::DrawText(
        { text: "Name", font: { weight: 700, .. }, .. }
      )
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Core", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::DrawText(
        { text: "Name", align: @core.TextAlign::TextCenter, .. }
      )
    }),
  )
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::DrawText(
        { text: "Done", align: @core.TextAlign::TextEnd, .. }
      )
    }),
  )
  assert_true(
    commands.any(command => command is @core.DrawCommand::StrokeRect(_, _, 1.0)),
  )
}

///|
test "markdown editor click maps table preview cells to markdown source" {
  let app = MarkdownEditorApp::new()
  app.set_document("| Name | Done |\n| --- | --- |\n| Core | yes |")
  let runtime = app.runtime(width=980.0, height=640.0)
  let mut target : @core.Rect? = None
  for command in runtime.draw_commands() {
    match command {
      @core.DrawCommand::DrawText({ text: "yes", frame, .. }) =>
        target = Some(frame)
      _ => ()
    }
  }
  guard target is Some(frame) else { fail("expected rendered yes cell") }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@moui.Point::new(
          x=frame.origin.x + frame.size.width / 2.0,
          y=frame.origin.y + frame.size.height / 2.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  let caret = runtime.focused_text_input().caret
  assert_true(caret >= 38)
  assert_true(caret <= 41)
}

///|
test "markdown editor click places caret after hidden heading marker" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@moui.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  inspect(runtime.focused_text_input().caret, content="2")
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("New ")),
  )
  inspect(app.document(), content="# New Title")
}

///|
test "markdown editor click maps inline formatted text to source offset" {
  let app = MarkdownEditorApp::new()
  app.set_document("Text **bold**")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@moui.Point::new(x=126.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  assert_true(runtime.focused_text_input().caret >= 7)
}

///|
test "markdown editor selection highlight uses formatted heading range" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@moui.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="ArrowRight",
        modifiers=@core.KeyModifiers::new(shift=true),
      ),
    ),
  )
  let commands = runtime.draw_commands()
  assert_true(
    commands.any(command => markdown_editor_is_selection_highlight(command)),
  )
}

///|
test "markdown editor drag selection tracks markdown source range" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@moui.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@moui.Point::new(x=460.0, y=84.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  inspect(runtime.focused_text_input().caret, content="7")
  guard runtime.focused_text_input().selection is Some(selection) else {
    fail("expected drag selection")
  }
  inspect(selection.normalized().start, content="2")
  inspect(selection.normalized().end, content="7")
  app.apply_command_to_selection(Bold)
  inspect(app.document(), content="# **Title**")
}

///|
fn markdown_editor_is_selection_highlight(command : @core.DrawCommand) -> Bool {
  match command {
    FillRect(_, color) => color.a == 0.18
    _ => false
  }
}

///|
test "markdown editor focus mode dims inactive rich text blocks" {
  let source = "# Title\n\nBody"
  let normal = markdown_editor_format_for_writing_mode(
    source,
    { caret: 3, selection: None },
    focus_mode=false,
  )
  assert_false(normal.blocks.any(block => block.color is Some(_)))

  let focused = markdown_editor_format_for_writing_mode(
    source,
    { caret: 3, selection: None },
    focus_mode=true,
  )
  guard focused.blocks[0].color is None else {
    fail("expected active block to keep normal foreground")
  }
  assert_true(
    focused.blocks.any(block => {
      match block.color {
        Some(color) => color.a == 0.38
        None => false
      }
    }),
  )
}
